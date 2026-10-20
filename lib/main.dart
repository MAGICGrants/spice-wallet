import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/models/contact_model.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/coin_settings.dart';
import 'package:spice_wallet/screens/scan_qr.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/models/language_model.dart';
import 'package:spice_wallet/models/theme_model.dart';
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/screens/settings.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/screens/explorer_setup.dart';
import 'package:spice_wallet/screens/fiat_api_setup_screen.dart';
import 'package:spice_wallet/screens/generate_seed.dart';
import 'package:spice_wallet/screens/lws_keys.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/screens/create_wallet.dart';
import 'package:spice_wallet/screens/create_wallet_password.dart';
import 'package:spice_wallet/screens/history.dart';
import 'package:spice_wallet/screens/restore_wallet.dart';
import 'package:spice_wallet/screens/reveal_seed.dart';
import 'package:spice_wallet/screens/verify_seed.dart';
import 'package:spice_wallet/screens/wallet_home.dart';
import 'package:spice_wallet/screens/welcome.dart';
import 'package:spice_wallet/theme/brand.dart';
import 'package:spice_wallet/theme/palette.dart';
import 'package:wallet_ui/wallet_ui.dart'
    show
        AppLockCover,
        OnboardingRadioCard,
        PaymentLinkChannel,
        PaymentLinkGate,
        ReauthGate,
        RefusedRoute,
        RouteLinkBlocker,
        showBrandToastOnOverlay;
import 'package:spice_wallet/screens/tor_settings.dart';
import 'package:spice_wallet/screens/address_book.dart';
import 'package:spice_wallet/screens/privacy_policy.dart';
import 'package:spice_wallet/screens/terms_of_service.dart';
import 'package:spice_wallet/screens/unlock.dart';
import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/util/dirs.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/route_policy.dart';
import 'package:spice_wallet/wallet_core_glue.dart';
import 'package:wallet_backup_platform/backup_ui.dart';
import 'package:wallet_domain/wallet_domain.dart' show AppSession, WalletManager, parsePaymentUri;
import 'package:wallet_fhse/security_keys_ui.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, HostPlatform;

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Before the first frame: the layout reads it synchronously.
      await HostPlatform.init();

      BrandColors.install(spicePalette);
      OnboardingRadioCard.selectedFill = () => BrandColors.card;

      installWalletCore();
      installSecurityKeysUi();
      installMetadataBackup();

      FlutterError.onError = (FlutterErrorDetails details) {
        log(LogLevel.error, 'Flutter error: ${details.exception}');
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      timeago.setLocaleMessages('pt', timeago.PtBrMessages());

      if (Platform.isLinux) {
        await createAppDir();
        NotificationService().init();
      }

      if (Platform.isWindows) {
        NotificationService().init();
      }

      if (Platform.isAndroid) {
        registerPeriodicTasks();
        startForegroundSyncIfEnabled();
        NotificationService().init();
      }

      if (Platform.isIOS) {
        await cleanTorDirectoriesOnIOS();
        // Background sync on iOS is BGTaskScheduler-driven and gated by the
        // notifications toggle; see periodic_tasks._applyIosBackgroundTasks.
        registerPeriodicTasks();
        NotificationService().init();
      }

      cleanOldLogFiles();
      runApp(MyApp());
    },
    (error, stackTrace) {
      log(LogLevel.error, 'Uncaught error: $error');
      if (kDebugMode) {
        debugPrint('Uncaught error: $error');
        debugPrint('Stack trace: $stackTrace');
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        walletManagerProvider(),
        ChangeNotifierProvider(create: (_) => LanguageModel()),
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(create: (_) => FiatRateModel()),
        ChangeNotifierProvider(create: (_) => ContactModel()),
      ],
      child: _RootApp(),
    );
  }
}

/// Loads prefs and picks the initial route, then builds a single [MaterialApp].
class _RootApp extends StatefulWidget {
  const _RootApp();

  @override
  State<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<_RootApp> with WidgetsBindingObserver {
  bool _startedServices = false;
  bool _walletExists = false;
  // App Lock (always on): its "Lock after" time in the background, on mobile.
  final _appLock = AppLockTimer();
  // Set when the app reaches `paused`, so the way back is noticed at its first
  // step (`hidden`), before a link that resumed it could land.
  bool _wasPaused = false;
  // "Fully lock after", with security keys on.
  final _fullLock = SecurityKeyFullLock();
  // "Lock after" a time without use, on a desktop OS: the full close.
  final _desktopLock = DesktopAutoLock();
  // App Lock's shorter time without use, on a desktop OS: covers the app.
  final _desktopAppLock = DesktopAutoLock.appLock();
  final _CurrentRouteObserver _routeObserver = _CurrentRouteObserver();
  // App Lock over the screens the user left (a relock): drawn above the
  // navigator ([AppLockCover]), so a screen finishing something under it
  // cannot pop it the way it could pop a route.
  final _cover = ValueNotifier<bool>(false);
  // Desktop-only foreground announce: desktop has no background isolate, so the
  // foreground announces incoming txs when the wallets' history grows.
  WalletManager? _announceManager;
  int _lastAnnouncedTxCount = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Every route the platform pushes is dropped; payment links
  // (monero:/bitcoin:/ethereum:) come over PaymentLinkChannel instead and wait in
  // the gate until the user is past every lock (AppSession) and on a screen
  // behind them.
  final _routeLinkBlocker = RouteLinkBlocker();
  late final PaymentLinkGate _paymentLinks;
  static const _paymentUriSchemes = {'monero', 'bitcoin', 'ethereum'};

  /// Last resolved theme brightness, to detect a light↔dark flip.
  Brightness? _lastBrightness;

  /// Recursively marks an element and its descendants for rebuild — used to
  /// refresh brand-coloured screens after a theme change (they don't depend on
  /// Flutter's Theme, so nothing else marks them dirty).
  static void _markSubtreeDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markSubtreeDirty);
  }

  void _startServicesOnce() {
    if (_startedServices) return;
    _startedServices = true;
    // Only the built-in Tor is ours to start; external/disabled must not spin up
    // an embedded Tor, whose status would then misreport the external proxy.
    // Fire-and-forget: a failed bootstrap is logged inside start().
    unawaited(
      () async {
        await TorSettingsService.sharedInstance.loadSettings();
        if (TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
          await TorService.sharedInstance.start();
        }
      }().catchError((Object _) {}),
    );
  }

  @override
  void initState() {
    super.initState();
    assert(() {
      final c = routePolicy.check(_routes.keys);
      return c.unlisted.isEmpty && c.stale.isEmpty;
    }(), 'route_policy.dart does not match the routes');
    // Android: the Continuous Sync service and this app take turns holding the
    // wallets, never both at once; installed before anything opens.
    ForegroundSyncLink.install(Provider.of<WalletManager>(context, listen: false));
    // First, so it is asked before WidgetsApp's own observer and drops every
    // pushed route before WidgetsApp could turn it into a screen.
    WidgetsBinding.instance.addObserver(_routeLinkBlocker);
    WidgetsBinding.instance.addObserver(this);
    _paymentLinks = PaymentLinkGate(
      schemes: _paymentUriSchemes,
      unlocked: AppSession.unlocked,
      landing: _routeObserver.current,
      canLand: () => routePolicy.requiresUnlock(_routeObserver.currentName),
      open: _openPaymentUri,
    );
    unawaited(PaymentLinkChannel.listen(_paymentLinks.offer));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    if (isDesktopOS) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _desktopLock.start(_lockDesktop);
      _desktopAppLock.start(_coverDesktop);
    }
  }

  @override
  void dispose() {
    _cover.dispose();
    _appLock.dispose();
    _fullLock.dispose();
    _desktopLock.dispose();
    _desktopAppLock.dispose();
    if (isDesktopOS) HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeObserver(_routeLinkBlocker);
    _paymentLinks.dispose();
    _announceManager?.removeListener(_announceNewTxsOnGrowth);
    super.dispose();
  }

  /// Opens the Send form for a payment link the gate let through: the user is
  /// past every lock and on a screen behind them. It only pre-fills the form,
  /// which reviews and confirms the payment as always.
  void _openPaymentUri(String raw) {
    if (!mounted || !AppSession.isUnlocked) return;
    final manager = context.read<WalletManager>();
    final request = parsePaymentUri(raw, manager.allWallets);
    if (request == null) return;
    final wallet = manager.getWallet(request.coinSymbol);
    // A coin with no connection set up can't send; warn instead of opening a form
    // that can't complete. The toast + l10n need a context below the MaterialApp,
    // so they go through the navigator's overlay rather than this (root) context.
    if (wallet == null || wallet.connectionAddress.isEmpty) {
      final overlay = _navigatorKey.currentState?.overlay;
      if (overlay == null) return;
      final name = wallet?.blockchainName ?? request.coinSymbol;
      showBrandToastOnOverlay(
        overlay,
        AppLocalizations.of(overlay.context)!.deepLinkCoinNotConfigured(name),
      );
      return;
    }
    _navigatorKey.currentState?.pushNamed(
      '/send',
      arguments: SendScreenArgs(
        coinSymbol: request.coinSymbol,
        destinationAddress: request.address,
        amount: request.amount,
      ),
    );
  }

  /// The system back button, while App Lock covers the app: swallowed. It
  /// would otherwise pop a screen out of sight under the cover. Asked before
  /// the MaterialApp's own handler, which registers after this one.
  @override
  Future<bool> didPopRoute() async => _cover.value;

  /// App Lock over the screens the user left.
  void _showCover() => _cover.value = true;

  void _hideCover() => _cover.value = false;

  /// From the cover: the wallet closed meanwhile and a key comes next.
  void _coverNeedsKey() => _replaceStack('/security_key_unlock');

  /// A lock screen replaces the stack. A cover that is up stays until that
  /// screen is fully in, so nothing it covered shows on the way.
  void _replaceStack(String lockRoute) {
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(lockRoute, (route) => false);
    if (!_cover.value) return;
    final top = _routeObserver.top;
    final animation = top is ModalRoute ? top.animation : null;
    if (animation == null || animation.isCompleted) return _hideCover();
    void settled(AnimationStatus status) {
      if (status.isAnimating) return;
      animation.removeStatusListener(settled);
      _hideCover();
    }

    animation.addStatusListener(settled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isDesktopOS) {
      _onDesktopLifecycle(state);
      return;
    }
    if (!isMobile) return;
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      // App Lock has to cover backgrounding, not just a cold start: once its
      // time is up the password goes and the way back shows the lock. Not
      // while it is showing: the device's own prompt can background the app.
      if (_routeObserver.currentName != '/unlock' && !_cover.value) {
        unawaited(_appLock.onBackground(context));
      }
      unawaited(_fullLock.onBackground(context));
      // Mark everything on screen as seen so a background isolate won't
      // re-announce a tx the user just watched arrive. Records only; fires no
      // notification (announce: false).
      if (_walletExists) {
        unawaited(context.read<WalletManager>().notifyNewIncomingTxsAll(announce: false));
      }
    } else if (_wasPaused) {
      // The first step back (`hidden`, then `inactive`, then `resumed`):
      // before a payment link that brought the app back gets a frame to land.
      _wasPaused = false;
      _onReturn();
    }
  }

  void _onReturn() {
    // Both decided at once, before anything is awaited; App Lock's locks the
    // session ([AppSession]) as it decides.
    final appLockDue = _appLock.takeDueOnReturn();
    // Past "Fully lock after" (or locked by its timer while away): the lock
    // screens replace the stack *before* the wallets close, which takes a
    // while, so the screen being left is never usable with the password still
    // in memory. App Lock comes first when its time is up too.
    if (_fullLock.takeDueOnResume()) {
      // App Lock first when it was showing too (its cover, or its screen):
      // the way in still starts with the device's own check.
      final appLockShowing = _cover.value || _routeObserver.currentName == '/unlock';
      _replaceStack(appLockDue || appLockShowing ? '/unlock' : '/security_key_unlock');
      unawaited(_fullLock.lock(context));
      return;
    }

    if (appLockDue) {
      // Over the current stack rather than replacing it, so unlocking returns
      // straight to the screen the user left; not again over a lock screen.
      if (_routeObserver.currentName != '/unlock') _showCover();
      unawaited(_appLock.lock(context));
    }
  }

  // Desktop has no background isolate to announce incoming txs, so the
  // foreground announces when the wallets' combined history grows. The count is
  // a cheap gate so unrelated notifications (balance, connectivity) don't hit
  // the keystore; notifyNewIncomingTxsAll is the decider (hash-based, respects
  // the notifications toggle).
  void _announceNewTxsOnGrowth() {
    final manager = _announceManager;
    if (manager == null) return;
    final count = manager.allWallets.fold<int>(0, (sum, w) => sum + w.txHistory.length);
    if (count <= _lastAnnouncedTxCount) return;
    _lastAnnouncedTxCount = count;
    unawaited(manager.notifyNewIncomingTxsAll());
  }

  /// A desktop OS. App Lock covers the app after its time without use, or as
  /// the window is hidden for "Immediately" (macOS reports `hidden` when no
  /// window is visible: hidden, minimised, covered, or the screen locked).
  /// Both "without use" clocks are checked as the app comes back, since their
  /// timers can stall while the computer sleeps.
  void _onDesktopLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) {
      unawaited(_coverDesktopIfImmediate());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_onDesktopResumed());
    }
  }

  Future<void> _coverDesktopIfImmediate() async {
    if (await AppLockPreferences.minutes() == 0) await _coverDesktop();
  }

  Future<void> _onDesktopResumed() async {
    // The full close first: it may replace the stack with the unlock screen,
    // and then there is nothing left to cover.
    await _desktopLock.check();
    await _desktopAppLock.check();
  }

  /// App Lock on a desktop OS: the unlock screen goes over whatever is open,
  /// and the wallets stay open and syncing behind it. Linux and Windows ask
  /// for the password again; macOS asks for Touch ID or the Mac's password,
  /// and drops the keychain password meanwhile ([lockAppLock]).
  Future<void> _coverDesktop() async {
    // Already at a lock screen, or onboarding with no wallet yet.
    if (!mounted || !AppSession.isUnlocked) return;
    // A Mac with no way to confirm its owner has nothing to ask.
    if (usesDeviceLock && !await BiometricAuth.isAvailable()) return;
    if (!mounted || !AppSession.isUnlocked) return;
    AppSession.lock();
    if (_routeObserver.currentName != '/unlock') _showCover();
    await lockAppLock(context);
  }

  /// "Lock after" ran out on a desktop OS. The unlock screen replaces the stack
  /// first, then the wallets close and the password is forgotten.
  Future<void> _lockDesktop() async {
    if (!mounted || !await desktopAutoLockApplies(context)) return;
    if (!mounted) return;
    // App Lock first (the typed password on Linux and Windows); a key follows
    // when keys are on.
    _replaceStack('/unlock');
    await _desktopLock.lock(context);
  }

  // Use, for both "without use" clocks: any key or pointer input reaching the
  // app.
  bool _onKey(KeyEvent event) {
    _recordUse();
    return false;
  }

  void _onPointer(PointerEvent event) => _recordUse();

  void _recordUse() {
    _desktopLock.recordUse();
    _desktopAppLock.recordUse();
  }

  Future<void> _bootstrap() async {
    try {
      final manager = context.read<WalletManager>();
      final walletExists = await manager.hasAnyExistingWallet();

      unawaited(manager.loadPreferences());

      if (walletExists) {
        unawaited(manager.loadCachedDisplayState());
      }

      // App Lock at every launch (always on; the typed password on Linux and
      // Windows). With security keys on, a key comes next.
      final initialRoute = walletExists ? '/unlock' : '/welcome';

      if (!mounted) return;
      _walletExists = walletExists;
      _startServicesOnce();
      _navigatorKey.currentState?.pushReplacementNamed(initialRoute);

      if (walletExists) {
        context.read<FiatRateModel>().startService(walletManager: context.read<WalletManager>());

        // Desktop announces incoming txs from the foreground (no bg isolate).
        if (isDesktopOS) {
          _announceManager = manager..addListener(_announceNewTxsOnGrowth);
        }
      }
    } catch (e) {
      log(LogLevel.error, 'App bootstrap failed: $e');
      if (!mounted) return;
      _startServicesOnce();
      _navigatorKey.currentState?.pushReplacementNamed('/welcome');
    }
  }

  // Theme built from the brand tokens in theme/brand.dart.
  ThemeData get _themeData => brandLightTheme();
  ThemeData get _darkThemeData => brandDarkTheme();

  // The bottom-nav destinations. Tapping a nav tab must not animate (on either
  // platform), so these get a zero-duration route in _onGenerateRoute.
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    // Deny by default (route_policy.dart): an unlisted route, or one behind the
    // locks while the app is locked, shows nothing and removes itself.
    final builder = _routes[settings.name];
    if (builder == null || !routePolicy.allows(settings.name, unlocked: AppSession.isUnlocked)) {
      return RefusedRoute(settings, listed: routePolicy.access.containsKey(settings.name));
    }
    // Desktop: no transition anywhere. Mobile: only between the nav-bar screens;
    // every other push/pop keeps its normal animation. (Modals keep their own
    // animations — they use showDialog / showModalBottomSheet, not this.)
    const navBarRoutes = {'/wallet_home', '/history', '/address_book', '/settings'};
    if (isDesktop || navBarRoutes.contains(settings.name)) {
      return _NoTransitionPageRoute(builder: builder, settings: settings);
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  static final Map<String, WidgetBuilder> _routes = {
    '/loading': (context) => Scaffold(body: Center(child: CircularProgressIndicator())),
    '/welcome': (context) => WelcomeScreen(),
    '/tor_settings': (context) => TorSettingsScreen(),
    '/connection_setup': (context) => ConnectionSetupScreen(),
    '/explorer_setup': (context) => ExplorerSetupScreen(),
    '/fiat_api_setup': (context) => FiatApiSetupScreen(),
    '/create_wallet_password': (context) => CreateWalletPasswordScreen(),
    '/create_wallet': (context) => CreateWalletScreen(),
    '/generate_seed': (context) => GenerateSeedScreen(),
    '/lws_keys': (context) => ReauthGate(
      reason: AppLocalizations.of(context)!.settingsAppLockUnlockReason,
      child: LwsKeysScreen(),
    ),
    '/restore_wallet': (context) => RestoreWalletScreen(),
    '/unlock': (context) => UnlockScreen(),
    '/security_key_unlock': (context) => const SecurityKeyUnlockScreen(),
    // Re-authenticates every time it opens: it can turn security keys off.
    '/advanced_security': (context) => const GuardedAdvancedSecurityScreen(),
    '/metadata_backup': (context) => const MetadataBackupScreen(),
    '/verify_seed': (context) => const VerifySeedScreen(),
    '/wallet_home': (context) => WalletHomeScreen(),
    '/coin_home': (context) => CoinHomeScreen(),
    '/coin_settings': (context) => const CoinSettingsScreen(),
    '/settings': (context) => SettingsScreen(),
    '/history': (context) => const HistoryScreen(),
    '/reveal_seed': (context) => ReauthGate(
      reason: AppLocalizations.of(context)!.revealSeedAuthReason,
      child: const RevealSeedScreen(),
    ),
    '/send': (context) => SendScreen(),
    '/scan_qr': (context) => ScanQrScreen(),
    '/receive': (context) => ReceiveScreen(),
    '/address_book': (context) => AddressBookScreen(),
    '/terms_of_service': (context) => TermsOfService(),
    '/privacy_policy': (context) => PrivacyPolicy(),
  };

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageModel>();
    // ThemeModel is Material-free (wallet_infra); map its string to ThemeMode here.
    final themeMode = switch (context.watch<ThemeModel>().theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      title: 'Spice Wallet',
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FhseLocalizations.delegate,
        BackupLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _themeData,
      darkTheme: _darkThemeData,
      themeMode: themeMode,
      // Pin the brand tokens to the resolved theme brightness before any screen
      // builds, so BrandColors.* return the light/dark palette for this frame.
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        BrandColors.setBrightness(brightness);
        // Screens read BrandColors globally, not via Theme.of, so a theme flip
        // doesn't mark them dirty on its own — cached routes keep their old
        // colours. On an actual change, force an in-place rebuild of the whole
        // navigator subtree (state is preserved; only build() re-runs).
        if (_lastBrightness != null && _lastBrightness != brightness) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navContext = _navigatorKey.currentContext;
            if (navContext is Element) navContext.visitChildElements(_markSubtreeDirty);
          });
        }
        _lastBrightness = brightness;
        // Brand-tone skeletons (the default grey clashes with the scheme); the
        // token resolves to the current theme.
        final app = AppLockCover(
          shown: _cover,
          cover: (_) => UnlockScreen(onUnlocked: _hideCover, onKeyNeeded: _coverNeedsKey),
          child: SkeletonizerConfig(
            data: SkeletonizerConfigData(effect: SoldColorEffect(color: BrandColors.surfaceMuted)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
        if (!isDesktopOS) return app;
        // Pointer input anywhere counts as use for "Lock after".
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointer,
          onPointerHover: _onPointer,
          onPointerMove: _onPointer,
          onPointerSignal: _onPointer,
          child: app,
        );
      },
      initialRoute: '/loading',
      // Always boot through /loading (which runs init then routes to unlock/home).
      // Whatever the platform offers as a deep link is ignored: payment links
      // arrive over PaymentLinkChannel, and nothing else is taken.
      onGenerateInitialRoutes: (_) => [_onGenerateRoute(const RouteSettings(name: '/loading'))!],
      locale: Locale.fromSubtags(languageCode: languageProvider.language),
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

/// Tracks the name of the current top route, so the app-lock relock can avoid
/// stacking a second unlock screen over one that's already showing.
class _CurrentRouteObserver extends NavigatorObserver {
  // A notifier so the desktop shell (in MaterialApp.builder) can rebuild the
  // persistent sidebar's visibility + active tab when the top route changes.
  final ValueNotifier<String?> current = ValueNotifier<String?>(null);

  String? get currentName => current.value;

  /// The top route itself.
  Route<dynamic>? top;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route;
    current.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = previousRoute;
    current.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    top = newRoute;
    current.value = newRoute?.settings.name;
  }

  /// A route taken out from under the top (a refused one removes itself).
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!identical(route, top)) return;
    top = previousRoute;
    current.value = previousRoute?.settings.name;
  }
}

/// A [MaterialPageRoute] whose push/pop is instant — used for every named route
/// so screen transitions don't animate (modals keep their own animations).
/// Subclassing (rather than a bare PageRouteBuilder) keeps Material's transition
/// machinery, so a covered screen's secondary transition still resolves (also
/// instantly, since the covering route's duration is zero).
class _NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  _NoTransitionPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

/// Every route name the app defines, for test/route_policy_test.dart.
@visibleForTesting
Iterable<String> get appRouteNames => _RootAppState._routes.keys;
