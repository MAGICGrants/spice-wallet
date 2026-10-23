import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/periodic_tasks.dart' show applyBackgroundTaskRegistration;
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/screens/desktop/home_shell.dart';
import 'package:spice_wallet/screens/desktop/home_view.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/screens/verify_seed.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/home_labels.dart';
import 'package:spice_wallet/widgets/open_alias_sheet.dart';
import 'package:spice_wallet/widgets/tor_settings_sheet.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_backup_platform/wallet_backup_platform.dart' show MetadataBackupSetup;
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_fhse/security_keys_ui.dart' show securityKeysOn;
import 'package:wallet_infra/wallet_infra.dart' show StoreReview;

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> with WidgetsBindingObserver {
  late final SecurityChecklist _checklist = SecurityChecklist(
    autoBackupOn: MetadataBackupSetup.automaticBackupOn,
    securityKeysOn: securityKeysOn,
    // A wallet from before the seed was kept has no words to ask for.
    canVerifySeed: SeedStore.exists,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checklist.addListener(_onChecklistChanged);
    _checklist.refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapIfNeeded();
      // Here a wallet exists and its connections are applied: the first time
      // after onboarding, and after every unlock. Updates the tasks in place.
      unawaited(applyBackgroundTaskRegistration());
      // Opening the app after a send is when a store review is asked for;
      // StoreReview decides whether one is due, once per launch.
      unawaited(StoreReview.requestIfDue(stillAppropriate: _stillOnHome));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checklist.removeListener(_onChecklistChanged);
    _checklist.dispose();
    super.dispose();
  }

  // A setting may have changed in the system settings (iCloud) meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checklist.refresh();
  }

  void _onChecklistChanged() {
    if (mounted) setState(() {});
  }

  // Still the screen in front, with the app in the foreground: the review
  // dialog must not land on a send or receive the user has already opened.
  bool _stillOnHome() =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> _bootstrapIfNeeded() async {
    final manager = context.read<WalletManager>();
    if (manager.loadedWallets.isNotEmpty) {
      manager.syncInBackground();
      return;
    }
    if (manager.hasPassword) {
      manager.openWalletFilesAndSync();
      return;
    }
    unawaited(manager.bootstrap());
  }

  Future<void> _openStep(SecurityStep step) => switch (step) {
    SecurityStep.verifySeed =>
      isDesktop ? showVerifySeedSheet(context) : Navigator.pushNamed(context, '/verify_seed'),
    SecurityStep.autoBackup => Navigator.pushNamed(context, '/metadata_backup'),
    SecurityStep.tor => showTorSettingsSheet(context),
    SecurityStep.privateLookups => showPrivateLookupSheets(context),
    SecurityStep.securityKeys => Navigator.pushNamed(context, '/advanced_security'),
  };

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final walletManager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();

    final ratesBySymbol = <String, double?>{
      for (final w in walletManager.allWallets) w.coinSymbol: fiatRate.rateFor(w.coinSymbol),
    };
    final totalFiat = walletManager.totalUnlockedFiat(ratesBySymbol);

    // Tokens (DAI/SDAI) don't get their own row — they live inside their parent
    // chain's assets list. The parent row shows the aggregate value instead.
    final chains = receivableChains(walletManager);
    final configured = chains.where((w) => w.connectionAddress.isNotEmpty);
    // The total shows once a price has come in (or with nothing to price);
    // the shares only once every configured chain has one.
    final anyPrice =
        configured.isEmpty || configured.any((w) => fiatRate.rateFor(w.coinSymbol) != null);
    final pricesKnown = configured.every((w) => fiatRate.rateFor(w.coinSymbol) != null);
    final chainCoins = <HomeCoin>[
      for (final c in chains) (wallet: c, tokens: tokensOf(walletManager, c.coinSymbol)),
    ];
    final coins = <HomeCoin>[
      for (final c in chainCoins) ...[
        c,
        for (final t in c.tokens) (wallet: t, tokens: const <CryptoWallet>[]),
      ],
    ];
    final sections = HomeSections(activity: HomeActivity.shared, labels: homeLabels(i18n));

    // Send and Receive open on the asset last sent or received (Receive on its
    // chain: a token arrives at its chain's address), and offer every other.
    final assets = sendableAssets(walletManager);
    final recent = HomeActivity.mostRecent(assets.where((w) => w.connectionAddress.isNotEmpty));
    final sendSymbol = (recent ?? assets.firstOrNull)?.coinSymbol ?? 'XMR';
    final receiveSymbol = recent != null
        ? chainSymbolOf(recent)
        : (chains.firstOrNull?.coinSymbol ?? 'XMR');

    // Without prices there is no total across different coins; each chain
    // card still shows its own amount.
    final hero = fiatRate.isDisabled
        ? null
        : HomeBalanceHero(
            label: i18n.homeTotalBalanceLabel,
            fiatRate: fiatRate,
            fiatTotal: anyPrice ? totalFiat : null,
            fiatErrorTooltip: i18n.homeFiatApiError,
            footer: pricesKnown && totalFiat > 0
                ? AllocationBar(slices: HomeSections.allocation(chainCoins, fiatRate.rateFor))
                : null,
          );
    void receive() => Navigator.pushNamed(
      context,
      '/receive',
      arguments: ReceiveScreenArgs(
        coinSymbol: receiveSymbol,
        allAssets: true,
        backLabel: i18n.navigationBarHome,
      ),
    );
    void send() => Navigator.pushNamed(
      context,
      '/send',
      arguments: SendScreenArgs(
        coinSymbol: sendSymbol,
        destinationAddress: '',
        allAssets: true,
        backLabel: i18n.navigationBarHome,
      ),
    );
    void swap() => showBrandToast(context, i18n.coinHomeSwapComingSoon);
    final incoming = sections.incoming(coins);
    final chart = sections.chart(coins);
    final checklist = securityChecklistCard(
      checklist: _checklist,
      labels: securityChecklistLabels(i18n),
      onStep: _openStep,
    );

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: DesktopHomeLayout(
          balance: hero ?? const SizedBox.shrink(),
          actions: DesktopHomeActions(
            receiveLabel: i18n.homeReceive,
            sendLabel: i18n.homeSend,
            swapLabel: i18n.coinHomeSwap,
            onReceive: receive,
            onSend: send,
            onSwap: swap,
          ),
          wide: [
            ?incoming,
            DesktopCoinGrid(manager: walletManager, fiatRate: fiatRate, chains: chains),
          ],
          side: checklist,
          full: [chart],
        ),
      );
    }

    return WalletHomeView(
      header: HomeHeader(
        logo: SvgPicture.asset('assets/spice-icon.svg', width: 32, height: 32),
        title: 'Spice Wallet',
        titleColor: BrandColors.primaryDeep,
      ),
      balance: hero,
      actions: HomeActionRow(
        receiveLabel: i18n.homeReceive,
        sendLabel: i18n.homeSend,
        swapLabel: i18n.coinHomeSwap,
        onReceive: receive,
        onSend: send,
        onSwap: swap,
      ),
      incoming: incoming,
      accounts: Column(
        spacing: 10,
        children: [
          for (final c in chainCoins)
            _CoinCard(
              wallet: c.wallet,
              fiatRate: fiatRate,
              tokenCount: c.tokens.length,
              fiatOverride: aggregateUnlockedFiat(walletManager, c.wallet, fiatRate.rateFor),
            ),
        ],
      ),
      chart: chart,
      checklist: checklist,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 0),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;

  /// Number of tokens on this chain (>0 → the row shows "N assets" + aggregate).
  final int tokenCount;

  /// Aggregate fiat across the chain + its tokens; falls back to own fiat.
  final double? fiatOverride;

  const _CoinCard({
    required this.wallet,
    required this.fiatRate,
    this.tokenCount = 0,
    this.fiatOverride,
  });

  static TextStyle get _cardBalanceStyle => TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    height: 1,
    color: BrandColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  void _open(BuildContext context) {
    if (wallet.connectionAddress.isEmpty) {
      Navigator.pushNamed(
        context,
        '/connection_setup',
        arguments: ConnectionSetupScreenArgs(coinSymbol: wallet.coinSymbol),
      );
    } else {
      Navigator.pushNamed(
        context,
        '/coin_home',
        arguments: CoinHomeScreenArgs(coinSymbol: wallet.coinSymbol),
      );
    }
  }

  Widget _leading() =>
      CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 40);

  /// (dot colour, status text). Dot is null for unconfigured coins; a chain with
  /// tokens prefixes the status with "N assets · ".
  (Color?, String) _status(AppLocalizations i18n) {
    final assets = tokenCount > 0 ? '${i18n.homeAssetsCount(tokenCount + 1)} · ' : '';
    if (wallet.connectionAddress.isEmpty) {
      return (null, '$assets${i18n.homeCoinNotConfigured}');
    }
    switch (connectionIndicatorStateFor(wallet)) {
      case ConnectionIndicatorState.ok:
        return (BrandColors.success, '$assets${i18n.homeSynced}');
      case ConnectionIndicatorState.loading:
        // Monero node syncing exposes a block count; show "x blocks left".
        final blocks = wallet.syncBlocksRemaining;
        final text = blocks != null ? i18n.homeBlocksRemaining(blocks) : i18n.homeSyncing;
        return (BrandColors.warning, '$assets$text');
      case ConnectionIndicatorState.error:
        return (BrandColors.error, '$assets${i18n.homeNoConnection}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final configured = wallet.connectionAddress.isNotEmpty;
    final balance = wallet.unlockedBalance;
    final coinRate = fiatRate.rateFor(wallet.coinSymbol);
    final ownFiat = coinRate != null && balance is double ? balance * coinRate : null;
    final balanceFiat = fiatOverride ?? ownFiat;
    final (dotColor, statusText) = _status(i18n);

    return Material(
      color: BrandColors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: BrandColors.border),
        borderRadius: BorderRadius.circular(BrandRadii.field),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(BrandRadii.field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              _leading(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.blockchainName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: BrandColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (dotColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              color: BrandColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (configured) _trailingBalance(balance, balanceFiat),
              Icon(Icons.chevron_right, size: 20, color: BrandColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailingBalance(Object? balance, double? balanceFiat) {
    // Prefer the fiat value (design); fall back to the coin amount when fiat is
    // unavailable (disabled, no rate, or balance not yet loaded).
    if (balanceFiat != null && !fiatRate.isDisabled) {
      return Padding(
        padding: const EdgeInsets.only(right: 7),
        child: BalanceText.split(
          formatFiat(balanceFiat, fiatRate.fiatCurrency),
          style: _cardBalanceStyle,
        ),
      );
    }
    if (balance == null) {
      return Padding(
        padding: EdgeInsets.only(right: 7),
        child: Skeletonizer(child: Text('0.000000', style: _cardBalanceStyle)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Text(
        (balance is double ? balance : 0.0).toStringAsFixed(
          wallet.decimals > 6 ? 6 : wallet.decimals,
        ),
        style: _cardBalanceStyle,
      ),
    );
  }
}
