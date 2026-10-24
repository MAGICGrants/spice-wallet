import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
        OnboardingRadioCard,
        PaymentLinkChannel,
        PaymentLinkGate,
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

      if (Platform.isLinux) {
        await createAppDir();
        NotificationService().init();
      }

      if (Platform.isWindows) {
        NotificationService().init();
      }

      // Before anything reads Sync Frequency: the tasks, the service, a wallet open.
      await migrateSyncSettings();

      if (Platform.isAndroid) {
        registerPeriodicTasks();
        startForegroundSyncIfEnabled();
        NotificationService().init();
      }

      if (Platform.isIOS) {
        await cleanTorDirectoriesOnIOS();
        // BGTaskScheduler windows under Sync Frequency; see wallet_background's
        // README.
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

class _RootAppState extends State<_RootApp>
    with WidgetsBindingObserver, AppLockLifecycle<_RootApp> {
  bool _startedServices = false;
  bool _walletExists = false;
  final _CurrentRouteObserver _routeObserver = _CurrentRouteObserver();
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
  }

  @override
  void dispose() {
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
    // Over whatever screen the user was on, so its back link says just "Back".
    final overlayContext = _navigatorKey.currentState?.overlay?.context;
    _navigatorKey.currentState?.pushNamed(
      '/send',
      arguments: SendScreenArgs(
        coinSymbol: request.coinSymbol,
        destinationAddress: request.address,
        amount: request.amount,
        backLabel: overlayContext == null ? null : AppLocalizations.of(overlayContext)?.back,
      ),
    );
  }

  // App Lock and the full locks (AppLockLifecycle) run on this navigator.
  @override
  NavigatorState? get appLockNavigator => _navigatorKey.currentState;

  @override
  String? get appLockTopRouteName => _routeObserver.currentName;

  @override
  Route<dynamic>? get appLockTopRoute => _routeObserver.top;

  /// Mark everything on screen as seen so a background isolate won't
  /// re-announce a tx the user just watched arrive. Records only; fires no
  /// notification (announce: false).
  @override
  void onMobilePaused() {
    if (_walletExists) {
      unawaited(context.read<WalletManager>().notifyNewIncomingTxsAll(announce: false));
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
    '/lws_keys': (context) => AppLockGate(
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
    '/reveal_seed': (context) => AppLockGate(
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
        // App Lock's cover above the navigator; on a desktop OS, input
        // anywhere counts as use for "Lock after".
        return buildAppLock(
          cover: (_) =>
              UnlockScreen(onUnlocked: hideAppLockCover, onKeyNeeded: appLockCoverNeedsKey),
          // Brand-tone skeletons (the default grey clashes with the scheme); the
          // token resolves to the current theme.
          child: SkeletonizerConfig(
            data: SkeletonizerConfigData(effect: SoldColorEffect(color: BrandColors.surfaceMuted)),
            child: child ?? const SizedBox.shrink(),
          ),
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
