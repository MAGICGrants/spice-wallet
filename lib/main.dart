import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:spice_wallet/screens/wallet_home.dart';
import 'package:spice_wallet/screens/welcome.dart';
import 'package:spice_wallet/theme/brand.dart';
import 'package:spice_wallet/theme/palette.dart';
import 'package:wallet_ui/wallet_ui.dart' show OnboardingRadioCard;
import 'package:spice_wallet/screens/tor_settings.dart';
import 'package:spice_wallet/screens/address_book.dart';
import 'package:spice_wallet/screens/privacy_policy.dart';
import 'package:spice_wallet/screens/terms_of_service.dart';
import 'package:spice_wallet/screens/unlock.dart';
import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/util/dirs.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/wallet_core_glue.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager;
import 'package:wallet_backup_platform/backup_ui.dart';
import 'package:wallet_fhse/security_keys_ui.dart';
import 'package:wallet_infra/wallet_infra.dart' show HostPlatform;

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
  bool _relockPending = false;
  // "Fully lock after", with security keys on.
  final _fullLock = SecurityKeyFullLock();
  // "Lock after" a time without use, on a desktop OS.
  final _desktopLock = DesktopAutoLock();
  final _CurrentRouteObserver _routeObserver = _CurrentRouteObserver();
  // Desktop-only foreground announce: desktop has no background isolate, so the
  // foreground announces incoming txs when the wallets' history grows.
  WalletManager? _announceManager;
  int _lastAnnouncedTxCount = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
    TorSettingsService.sharedInstance.loadSettings();
    // Fire-and-forget: a failed Tor bootstrap is logged inside start() and must
    // not surface as an uncaught async error (nothing awaits this).
    unawaited(TorService.sharedInstance.start().catchError((Object _) {}));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    if (isDesktopOS) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _desktopLock.start(_lockDesktop);
    }
  }

  @override
  void dispose() {
    _fullLock.dispose();
    _desktopLock.dispose();
    if (isDesktopOS) HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    _announceManager?.removeListener(_announceNewTxsOnGrowth);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isDesktopOS) {
      _onDesktopLifecycle(state);
      return;
    }
    if (!isMobile) return;
    if (state == AppLifecycleState.paused) {
      _maybeArmRelock();
      unawaited(_fullLock.onBackground(context));
      // Mark everything on screen as seen so a background isolate won't
      // re-announce a tx the user just watched arrive. Records only; fires no
      // notification (announce: false).
      if (_walletExists) {
        unawaited(context.read<WalletManager>().notifyNewIncomingTxsAll(announce: false));
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }

  Future<void> _onResumed() async {
    // Past "Fully lock after" (or locked by its timer while away): decided at
    // once, and the lock screens replace the stack *before* the wallets close,
    // which takes a while, so the screen being left is never usable with the
    // password still in memory. App Lock comes first when it is on; the relock
    // armed on the way out says whether it is.
    if (_fullLock.takeDueOnResume()) {
      final lockRoute = _relockPending ? '/unlock' : '/security_key_unlock';
      _relockPending = false;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(lockRoute, (route) => false);
      await _fullLock.lock(context);
      return;
    }

    if (_relockPending) {
      _relockPending = false;
      // Push the lock screen ON TOP of the current stack (rather than replacing
      // it) so unlocking pops straight back to the screen the user left — unless
      // one is already showing, which would stack duplicates.
      if (_routeObserver.currentName != '/unlock') {
        _navigatorKey.currentState?.pushNamed('/unlock');
      }
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

  /// A desktop OS. With App Lock (macOS), hiding the app re-locks it, as going
  /// to the background does on mobile: macOS reports `hidden` when no window is
  /// visible (hidden, minimised, covered, or the screen locked). "Lock after" is
  /// checked as the app comes back, since its timer can stall while the
  /// computer sleeps.
  void _onDesktopLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden && usesDeviceLock) {
      unawaited(_maybeArmRelock());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_onDesktopResumed());
    }
  }

  Future<void> _onDesktopResumed() async {
    // May lock and replace the stack with the unlock screen.
    await _desktopLock.check();
    if (_relockPending) {
      _relockPending = false;
      if (_routeObserver.currentName != '/unlock') {
        _navigatorKey.currentState?.pushNamed('/unlock');
      }
    }
  }

  /// "Lock after" ran out on a desktop OS. The unlock screen replaces the stack
  /// first, then the wallets close and the password is forgotten.
  Future<void> _lockDesktop() async {
    if (!mounted || !await desktopAutoLockApplies(context)) return;
    final appLock =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.appLockEnabled) ?? false;
    if (!mounted) return;
    // The typed password (Linux, Windows) or App Lock first; keys alone (macOS
    // without App Lock) go straight to the key screen.
    final lockRoute = typesWalletPassword || appLock ? '/unlock' : '/security_key_unlock';
    _relockPending = false;
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(lockRoute, (route) => false);
    await _desktopLock.lock(context);
  }

  // Use, for "Lock after": any key or pointer input reaching the app.
  bool _onKey(KeyEvent event) {
    _desktopLock.recordUse();
    return false;
  }

  void _onPointer(PointerEvent event) => _desktopLock.recordUse();

  /// On background: if app lock is on and a wallet exists, clear the in-memory
  /// password and arm a re-lock so resume returns to the unlock screen. The
  /// decision itself lives in [WalletManager.armAppLockRelock], shared with
  /// Skylight so the two cannot drift.
  Future<void> _maybeArmRelock() async {
    _relockPending = await context.read<WalletManager>().armAppLockRelock();
  }

  Future<void> _bootstrap() async {
    try {
      final manager = context.read<WalletManager>();
      final checkKey = securityKeyCheck(context);
      final prefs = await SharedPreferences.getInstance();
      final walletExists = await manager.hasAnyExistingWallet();
      final needsSecurityKey = walletExists && usesDeviceLock && await checkKey();

      unawaited(manager.loadPreferences());

      if (walletExists) {
        unawaited(manager.loadCachedDisplayState());
      }

      final appLockEnabled = prefs.getBool(SharedPreferencesKeys.appLockEnabled) ?? false;

      // Linux and Windows ask for the typed password at every launch. With
      // security keys on, a key comes next (after App Lock when on).
      final initialRoute = walletExists
          ? appLockEnabled || typesWalletPassword
                ? '/unlock'
                : needsSecurityKey
                ? '/security_key_unlock'
                : '/wallet_home'
          : '/welcome';

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
    final builder = <String, WidgetBuilder>{
      '/loading': (context) => Scaffold(body: Center(child: CircularProgressIndicator())),
      ..._routes,
    }[settings.name];
    if (builder == null) return null;
    // Desktop: no transition anywhere. Mobile: only between the nav-bar screens;
    // every other push/pop keeps its normal animation. (Modals keep their own
    // animations — they use showDialog / showModalBottomSheet, not this.)
    const navBarRoutes = {'/wallet_home', '/history', '/address_book', '/settings'};
    if (isDesktop || navBarRoutes.contains(settings.name)) {
      return _NoTransitionPageRoute(builder: builder, settings: settings);
    }
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  Map<String, WidgetBuilder> get _routes => {
    '/welcome': (context) => WelcomeScreen(),
    '/tor_settings': (context) => TorSettingsScreen(),
    '/connection_setup': (context) => ConnectionSetupScreen(),
    '/explorer_setup': (context) => ExplorerSetupScreen(),
    '/fiat_api_setup': (context) => FiatApiSetupScreen(),
    '/create_wallet_password': (context) => CreateWalletPasswordScreen(),
    '/create_wallet': (context) => CreateWalletScreen(),
    '/generate_seed': (context) => GenerateSeedScreen(),
    '/lws_keys': (context) => LwsKeysScreen(),
    '/restore_wallet': (context) => RestoreWalletScreen(),
    '/unlock': (context) => UnlockScreen(),
    '/security_key_unlock': (context) => const SecurityKeyUnlockScreen(),
    '/advanced_security': (context) => const AdvancedSecurityScreen(),
    '/metadata_backup': (context) => const MetadataBackupScreen(),
    '/wallet_home': (context) => WalletHomeScreen(),
    '/coin_home': (context) => CoinHomeScreen(),
    '/coin_settings': (context) => const CoinSettingsScreen(),
    '/settings': (context) => SettingsScreen(),
    '/history': (context) => const HistoryScreen(),
    '/reveal_seed': (context) => const RevealSeedScreen(),
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
        final app = SkeletonizerConfig(
          data: SkeletonizerConfigData(effect: SoldColorEffect(color: BrandColors.surfaceMuted)),
          child: child ?? const SizedBox.shrink(),
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

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      current.value = route.settings.name;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      current.value = previousRoute?.settings.name;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      current.value = newRoute?.settings.name;
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
