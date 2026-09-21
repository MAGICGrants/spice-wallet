import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/tx_details.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Desktop main home body (rendered inside [DesktopShell]): total balance and
/// Receive/Send, the chain cards, and a recent-activity list. Mirrors the mobile
/// [WalletHomeScreen] logic; only the layout is desktop-specific.
class DesktopHomeView extends StatelessWidget {
  const DesktopHomeView({super.key});

  // Getters, not const: BrandColors.ink is a runtime (palette/brightness) value.
  static TextStyle get _bigBalance => const TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 44,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ).copyWith(color: BrandColors.ink);

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final manager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';

    final ratesBySymbol = <String, double?>{
      for (final w in manager.allWallets) w.coinSymbol: fiatRate.rateFor(w.coinSymbol),
    };
    final totalFiat = manager.totalUnlockedFiat(ratesBySymbol);

    // Configured chains sort first; tokens live inside their parent chain.
    final wallets = manager.allWallets.where((w) => !isTokenWallet(w)).toList()
      ..sort((a, b) {
        final aOn = a.connectionAddress.isNotEmpty;
        final bOn = b.connectionAddress.isNotEmpty;
        if (aOn != bOn) return aOn ? -1 : 1;
        return 0;
      });
    final configured = wallets.where((w) => w.connectionAddress.isNotEmpty).toList();

    // Newest-first timeline across every asset, capped for the home preview.
    final recent = <TxEntry>[
      for (final asset in manager.allWallets)
        for (final tx in asset.txHistory) (tx: tx, asset: asset),
    ]..sort((a, b) => b.tx.timestamp.compareTo(a.tx.timestamp));
    final top = recent.take(6).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _totalBalance(i18n, fiatRate, totalFiat, fiatSymbol)),
                const SizedBox(width: 24),
                _actions(context, i18n, configured),
              ],
            ),
            const SizedBox(height: 30),
            _coinGrid(context, manager, wallets, fiatRate, fiatSymbol),
            const SizedBox(height: 20),
            SectionHeader(label: i18n.coinHomeActivityTitle, padding: EdgeInsets.zero),
            const SizedBox(height: 12),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(i18n.homeNoTransactions, style: BrandText.bodyMuted),
              )
            else
              for (final e in top) ...[
                _ActivityCard(entry: e, fiatRate: fiatRate, fiatSymbol: fiatSymbol),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ],
    );
  }

  // Two columns, collapsing to one when the pane gets narrow. Cards in a row
  // share the tallest one's height (IntrinsicHeight + stretch).
  Widget _coinGrid(
    BuildContext context,
    WalletManager manager,
    List<CryptoWallet> wallets,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final cols = constraints.maxWidth >= 520 ? 2 : 1;
        Widget card(CryptoWallet w) => _DesktopCoinCard(
          wallet: w,
          fiatRate: fiatRate,
          fiatSymbol: fiatSymbol,
          tokenCount: tokensOf(manager, w.coinSymbol).length,
          fiatOverride: aggregateUnlockedFiat(manager, w, fiatRate.rateFor),
        );
        final rows = <Widget>[];
        for (var i = 0; i < wallets.length; i += cols) {
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            if (c > 0) cells.add(const SizedBox(width: gap));
            final idx = i + c;
            cells.add(
              Expanded(child: idx < wallets.length ? card(wallets[idx]) : const SizedBox()),
            );
          }
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _totalBalance(
    AppLocalizations i18n,
    FiatRateModel fiatRate,
    double totalFiat,
    String fiatSymbol,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: i18n.homeTotalBalanceLabel, padding: EdgeInsets.zero),
        const SizedBox(height: 12),
        if (!fiatRate.isDisabled)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: BalanceText.split(formatFiat(totalFiat, fiatSymbol), style: _bigBalance),
          )
        else
          Text('--', style: _bigBalance),
      ],
    );
  }

  /// Receive/Send are multicoin here (no precedent on mobile home). Rather than
  /// pick the asset first, they open the screen with the asset dropdown enabled
  /// (defaulting to a configured chain), so selection happens there.
  Widget _actions(BuildContext context, AppLocalizations i18n, List<CryptoWallet> configured) {
    final defaultCoin = configured.isNotEmpty ? configured.first.coinSymbol : 'XMR';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandButton.secondary(
          label: i18n.receiveTitle,
          icon: Icons.south_west,
          expand: false,
          onPressed: () => Navigator.pushNamed(
            context,
            '/receive',
            arguments: ReceiveScreenArgs(coinSymbol: defaultCoin, allAssets: true),
          ),
        ),
        const SizedBox(width: 10),
        BrandButton.secondary(
          label: i18n.sendTitle,
          icon: Icons.north_east,
          expand: false,
          onPressed: () => Navigator.pushNamed(
            context,
            '/send',
            arguments: SendScreenArgs(
              coinSymbol: defaultCoin,
              destinationAddress: '',
              allAssets: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Swap has no screen yet; mirrors the coin home's "coming soon".
        BrandButton.secondary(
          label: i18n.coinHomeSwap,
          icon: Icons.swap_horiz,
          expand: false,
          onPressed: () => showBrandToast(context, i18n.coinHomeSwapComingSoon),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final TxEntry entry;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _ActivityCard({required this.entry, required this.fiatRate, required this.fiatSymbol});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TxActivityRow(
        tx: entry.tx,
        asset: entry.asset,
        labels: TxActivityLabels(received: i18n.coinHomeReceived, sent: i18n.coinHomeSent),
        fiatRate: fiatRate,
        fiatSymbol: fiatSymbol,
        showDivider: false,
        onTap: () => TxDetailsDialog.show(context, entry.asset, entry.tx),
      ),
    );
  }
}

class _DesktopCoinCard extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final int tokenCount;
  final double? fiatOverride;

  const _DesktopCoinCard({
    required this.wallet,
    required this.fiatRate,
    required this.fiatSymbol,
    this.tokenCount = 0,
    this.fiatOverride,
  });

  static TextStyle get _amountStyle => const TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ).copyWith(color: BrandColors.ink);

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

  // (dot colour, status text) — mirrors WalletHomeScreen._CoinCard._status.
  (Color?, String) _status(AppLocalizations i18n) {
    final assets = tokenCount > 0 ? '${i18n.homeAssetsCount(tokenCount + 1)} · ' : '';
    if (wallet.connectionAddress.isEmpty) {
      return (null, '$assets${i18n.homeCoinNotConfigured}');
    }
    switch (connectionIndicatorStateFor(wallet)) {
      case ConnectionIndicatorState.ok:
        return (BrandColors.success, '$assets${i18n.homeSynced}');
      case ConnectionIndicatorState.loading:
        final blocks = wallet.syncBlocksRemaining;
        final text = blocks != null
            ? i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(blocks))
            : i18n.homeSyncing;
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 44),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.blockchainName,
                      style: TextStyle(
                        fontFamily: 'Ubuntu',
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (dotColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontFamily: 'Ubuntu',
                              fontSize: 12.5,
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
              const SizedBox(width: 12),
              if (configured) _trailingBalance(balance, balanceFiat),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: BrandColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailingBalance(Object? balance, double? balanceFiat) {
    if (balanceFiat != null && !fiatRate.isDisabled) {
      return BalanceText.split(formatFiat(balanceFiat, fiatSymbol), style: _amountStyle);
    }
    if (balance == null) return const SizedBox.shrink();
    return Text(
      (balance is double ? balance : 0.0).toStringAsFixed(
        wallet.decimals > 6 ? 6 : wallet.decimals,
      ),
      style: _amountStyle,
    );
  }
}
