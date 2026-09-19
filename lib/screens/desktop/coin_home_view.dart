import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_settings.dart';
import 'package:spice_wallet/screens/explorer_setup.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/tx_details.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Desktop per-chain home (rendered inside [DesktopShell]): a white identity/
/// balance/actions card, an assets list for multi-asset chains, and the merged
/// activity timeline. Mirrors the mobile [CoinHomeScreen] logic.
class DesktopCoinHomeView extends StatelessWidget {
  final String coinSymbol;
  const DesktopCoinHomeView({super.key, required this.coinSymbol});

  static TextStyle get _bigFiat => const TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 40,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ).copyWith(color: BrandColors.ink);

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final manager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();

    final entered = manager.getWallet(coinSymbol);
    if (entered == null) {
      return Center(child: Text('Unknown coin: $coinSymbol', style: BrandText.body));
    }

    // Entering as a token (DAI) resolves to its chain (Ethereum).
    final wallet = manager.getWallet(chainSymbolOf(entered)) ?? entered;
    final chainSymbol = wallet.coinSymbol;
    final assets = chainAssets(manager, wallet);
    final hasTokens = assets.length > 1;
    final configured = wallet.connectionAddress.isNotEmpty;
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final totalFiat = aggregateUnlockedFiat(manager, wallet, fiatRate.rateFor);

    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 30, 44, 36),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, size: 18, color: BrandColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      i18n.navigationBarHome,
                      style: TextStyle(
                        fontFamily: 'Ubuntu',
                        fontSize: 12.5,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _headerCard(
              context,
              i18n,
              wallet,
              fiatRate,
              totalFiat,
              fiatSymbol,
              configured,
              chainSymbol,
            ),
            const SizedBox(height: 28),
            if (hasTokens) ...[
              SectionHeader(label: i18n.coinHomeAssetsTitle, padding: EdgeInsets.zero),
              const SizedBox(height: 12),
              for (final a in assets) ...[
                _AssetRow(wallet: a, fiatRate: fiatRate, fiatSymbol: fiatSymbol),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 20),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionHeader(label: i18n.coinHomeActivityTitle, padding: EdgeInsets.zero),
                if (wallet.syncBlocksRemaining != null)
                  Text(
                    i18n.coinHomeBalancesMayBeStale,
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      fontSize: 12,
                      height: 1,
                      color: BrandColors.inkFaint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._activity(
              context,
              i18n,
              wallet,
              assets,
              hasTokens,
              fiatRate,
              fiatSymbol,
              chainSymbol,
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerCard(
    BuildContext context,
    AppLocalizations i18n,
    CryptoWallet wallet,
    FiatRateModel fiatRate,
    double? totalFiat,
    String fiatSymbol,
    bool configured,
    String chainSymbol,
  ) {
    final showFiat = !fiatRate.isDisabled && totalFiat != null;
    final coinAmount = wallet.unlockedBalance is double
        ? '${formatAmount(wallet.unlockedBalance as double, wallet.decimals)} ${wallet.coinSymbol}'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoinMark(
                coinSymbol: wallet.coinSymbol,
                iconAsset: wallet.iconAsset,
                size: 32,
                statusColor: connectionDotColor(wallet),
                statusRingColor: BrandColors.card,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  wallet.blockchainName,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
              ),
              _statusPill(i18n, wallet, configured),
              const SizedBox(width: 10),
              _GearButton(onTap: () => _openSettings(context, chainSymbol)),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: balance, coin amount, then the connection pills beneath.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showFiat)
                      BalanceText.split(formatFiat(totalFiat, fiatSymbol), style: _bigFiat)
                    else
                      Text(coinAmount, style: _bigFiat),
                    if (showFiat) ...[
                      const SizedBox(height: 11),
                      Text(
                        coinAmount,
                        style: TextStyle(
                          fontFamily: 'Ubuntu Mono',
                          fontSize: 15,
                          height: 1,
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ],
                    if (configured) ...[
                      const SizedBox(height: 14),
                      ConnectionPills(wallet: wallet),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right: the three actions, bottom-aligned to the balance block.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _action(
                    Icons.south_west,
                    i18n.receiveTitle,
                    configured ? () => _openReceive(context, chainSymbol) : null,
                  ),
                  const SizedBox(width: 10),
                  _action(
                    Icons.north_east,
                    i18n.sendTitle,
                    configured ? () => _openSend(context, chainSymbol) : null,
                  ),
                  const SizedBox(width: 10),
                  _action(
                    Icons.swap_horiz,
                    i18n.coinHomeSwap,
                    () => showBrandToast(context, i18n.coinHomeSwapComingSoon),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onPressed) =>
      BrandButton.secondary(label: label, icon: icon, expand: false, onPressed: onPressed);

  Widget _statusPill(AppLocalizations i18n, CryptoWallet wallet, bool configured) {
    final (Color? dot, String text) = _status(i18n, wallet, configured);
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 12.5,
              height: 1,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  (Color?, String) _status(AppLocalizations i18n, CryptoWallet wallet, bool configured) {
    if (!configured) return (null, i18n.homeCoinNotConfigured);
    switch (connectionIndicatorStateFor(wallet)) {
      case ConnectionIndicatorState.ok:
        return (BrandColors.success, i18n.homeSynced);
      case ConnectionIndicatorState.loading:
        final blocks = wallet.syncBlocksRemaining;
        return (
          BrandColors.warning,
          blocks != null
              ? i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(blocks))
              : i18n.homeSyncing,
        );
      case ConnectionIndicatorState.error:
        return (BrandColors.error, i18n.homeNoConnection);
    }
  }

  List<Widget> _activity(
    BuildContext context,
    AppLocalizations i18n,
    CryptoWallet chain,
    List<CryptoWallet> assets,
    bool hasTokens,
    FiatRateModel fiatRate,
    String fiatSymbol,
    String chainSymbol,
  ) {
    final entries = <TxEntry>[
      for (final asset in assets)
        for (final tx in asset.txHistory) (tx: tx, asset: asset),
    ]..sort((a, b) => b.tx.timestamp.compareTo(a.tx.timestamp));

    if (entries.isEmpty) {
      final needsExplorer = chain.supportsExplorerUrl && chain.explorerAddress.isEmpty;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: needsExplorer
              ? BrandButton.outline(
                  label: i18n.coinHomeAddExplorerButton,
                  icon: Icons.search,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/explorer_setup',
                    arguments: ExplorerSetupScreenArgs(coinSymbol: chainSymbol),
                  ),
                )
              : Text(i18n.homeNoTransactions, style: BrandText.bodyMuted),
        ),
      ];
    }

    final rows = <Object>[];
    DateTime? lastDay;
    for (final e in entries) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.tx.timestamp * 1000);
      final day = DateTime(d.year, d.month, d.day);
      if (day != lastDay) {
        rows.add(DateFormat('d MMMM').format(day).toUpperCase());
        lastDay = day;
      }
      rows.add(e);
    }

    return [
      for (var i = 0; i < rows.length; i++)
        if (rows[i] is String)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 4),
            child: SectionHeader(label: rows[i] as String, padding: EdgeInsets.zero),
          )
        else
          Builder(
            builder: (context) {
              final e = rows[i] as TxEntry;
              final next = i + 1 < rows.length ? rows[i + 1] : null;
              return TxActivityRow(
                tx: e.tx,
                asset: e.asset,
                labels: TxActivityLabels(received: i18n.coinHomeReceived, sent: i18n.coinHomeSent),
                fiatRate: fiatRate,
                fiatSymbol: fiatSymbol,
                showCoinIcon: hasTokens,
                showDivider: next is TxEntry,
                onTap: () => TxDetailsDialog.show(context, e.asset, e.tx),
              );
            },
          ),
    ];
  }

  void _openReceive(BuildContext context, String coinSymbol) => Navigator.pushNamed(
    context,
    '/receive',
    arguments: ReceiveScreenArgs(coinSymbol: coinSymbol),
  );

  void _openSend(BuildContext context, String coinSymbol) => Navigator.pushNamed(
    context,
    '/send',
    arguments: SendScreenArgs(coinSymbol: coinSymbol, destinationAddress: ''),
  );

  void _openSettings(BuildContext context, String coinSymbol) =>
      showCoinSettingsSheet(context, coinSymbol: coinSymbol);
}

class _GearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandColors.surfaceSunken,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: BrandColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.tune, size: 18, color: BrandColors.inkMuted),
        ),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _AssetRow({required this.wallet, required this.fiatRate, required this.fiatSymbol});

  static TextStyle get _fiat => const TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ).copyWith(color: BrandColors.ink);

  @override
  Widget build(BuildContext context) {
    final rate = fiatRate.rateFor(wallet.coinSymbol);
    final balance = wallet.unlockedBalance;
    final fiat = rate != null && balance is double ? balance * rate : null;
    final amount = balance is double
        ? '${formatAmount(balance, wallet.decimals)} ${wallet.coinSymbol}'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 34),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.assetName,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 11.5,
                    height: 1.3,
                    color: BrandColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (fiat != null && !fiatRate.isDisabled)
            BalanceText.split(formatFiat(fiat, fiatSymbol), style: _fiat),
        ],
      ),
    );
  }
}
