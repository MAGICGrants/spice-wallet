import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// The chain cards on the desktop home: two columns where there is room, one
/// otherwise, cards in a row sharing the tallest one's height. Tokens live
/// inside their parent chain's card.
class DesktopCoinGrid extends StatelessWidget {
  final WalletManager manager;
  final FiatRateModel fiatRate;
  final List<CryptoWallet> chains;

  const DesktopCoinGrid({
    super.key,
    required this.manager,
    required this.fiatRate,
    required this.chains,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        // Two columns only when each card still gets a comfortable width.
        const twoColMinWidth = 600.0;
        final cols = constraints.maxWidth >= twoColMinWidth ? 2 : 1;
        Widget card(CryptoWallet w) => _DesktopCoinCard(
          wallet: w,
          fiatRate: fiatRate,
          tokenCount: tokensOf(manager, w.coinSymbol).length,
          fiatOverride: aggregateUnlockedFiat(manager, w, fiatRate.rateFor),
        );
        final rows = <Widget>[];
        for (var i = 0; i < chains.length; i += cols) {
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            if (c > 0) cells.add(const SizedBox(width: gap));
            final idx = i + c;
            cells.add(Expanded(child: idx < chains.length ? card(chains[idx]) : const SizedBox()));
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
}

class _DesktopCoinCard extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final int tokenCount;
  final double? fiatOverride;

  const _DesktopCoinCard({
    required this.wallet,
    required this.fiatRate,
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
      return BalanceText.split(formatFiat(balanceFiat, fiatRate.fiatCurrency), style: _amountStyle);
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
