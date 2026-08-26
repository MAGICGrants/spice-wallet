import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_settings.dart';
import 'package:spice_wallet/screens/explorer_setup.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/connection_status_indicator.dart';
import 'package:spice_wallet/widgets/tx_details.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_domain/wallet_domain.dart';

class CoinHomeScreenArgs {
  final String coinSymbol;
  final bool showTxSuccessToast;

  CoinHomeScreenArgs({required this.coinSymbol, this.showTxSuccessToast = false});
}

final _fiatFormat = NumberFormat('#,##0.00');
const _balanceStyle = TextStyle(
  fontFamily: 'Ubuntu Mono',
  fontSize: 33,
  height: 1,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.66,
  color: BrandColors.ink,
  fontFeatures: [FontFeature.tabularFigures()],
);

class CoinHomeScreen extends StatefulWidget {
  const CoinHomeScreen({super.key});

  @override
  State<CoinHomeScreen> createState() => _CoinHomeScreenState();
}

class _CoinHomeScreenState extends State<CoinHomeScreen> {
  CoinHomeScreenArgs? _args;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as CoinHomeScreenArgs?;
      _args = args;
      if (args != null && args.showTxSuccessToast) _showTxSuccessToast();
    });
  }

  String _coinSymbolFromRoute(BuildContext context) {
    final args = _args ?? ModalRoute.of(context)?.settings.arguments as CoinHomeScreenArgs?;
    return args?.coinSymbol ?? '';
  }

  void _showTxSuccessToast() {
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.sendTransactionSuccessfullySent)));
  }

  void _openReceive(String coinSymbol) => Navigator.pushNamed(
    context,
    '/receive',
    arguments: ReceiveScreenArgs(coinSymbol: coinSymbol),
  );

  void _openSend(String coinSymbol) => Navigator.pushNamed(
    context,
    '/send',
    arguments: SendScreenArgs(coinSymbol: coinSymbol, destinationAddress: ''),
  );

  void _openSettings(String coinSymbol) => Navigator.pushNamed(
    context,
    '/coin_settings',
    arguments: CoinSettingsScreenArgs(coinSymbol: coinSymbol),
  );

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final walletManager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();

    final coinSymbol = _coinSymbolFromRoute(context);
    final entered = walletManager.getWallet(coinSymbol);

    if (entered == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(child: Center(child: Text('Unknown coin: $coinSymbol', style: BrandText.body))),
      );
    }

    // Operate on the chain: entering as a token (e.g. DAI) shows its parent
    // chain (Ethereum), whose screen aggregates the balance, assets and activity
    // of every asset on it.
    final wallet = walletManager.getWallet(chainSymbolOf(entered)) ?? entered;
    final chainSymbol = wallet.coinSymbol;
    final assets = chainAssets(walletManager, wallet);
    final hasTokens = assets.length > 1;

    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final totalFiat = aggregateUnlockedFiat(walletManager, wallet, fiatRate.rateFor);

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 0),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(wallet: wallet, onSettings: () => _openSettings(chainSymbol)),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BalanceHero(
                              wallet: wallet,
                              totalFiat: totalFiat,
                              fiatSymbol: fiatSymbol,
                              fiatRate: fiatRate,
                              assetCount: assets.length,
                              hasTokens: hasTokens,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                              child: _ActionRow(
                                enabled: wallet.connectionAddress.isNotEmpty,
                                onReceive: () => _openReceive(chainSymbol),
                                onSend: () => _openSend(chainSymbol),
                                onSwap: () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(i18n.coinHomeSwapComingSoon)),
                                ),
                              ),
                            ),
                            if (hasTokens)
                              _AssetsSection(
                                assets: assets,
                                fiatRate: fiatRate,
                                fiatSymbol: fiatSymbol,
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: SectionHeader(
                                label: i18n.coinHomeActivityTitle,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ActivitySliver(
                        chain: wallet,
                        assets: assets,
                        i18n: i18n,
                        fiatRate: fiatRate,
                        fiatSymbol: fiatSymbol,
                        onTapTx: (asset, tx) => TxDetailsDialog.show(context, asset, tx),
                        onSetupExplorer: () => Navigator.pushNamed(
                          context,
                          '/explorer_setup',
                          arguments: ExplorerSetupScreenArgs(coinSymbol: chainSymbol),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double? _ownFiat(CryptoWallet wallet, FiatRateModel fiatRate) {
  final rate = fiatRate.rateFor(wallet.coinSymbol);
  final balance = wallet.unlockedBalance;
  return rate != null && balance is double ? balance * rate : null;
}

/// Compact coin amount ("412.09041"), capped so long-decimal coins stay legible.
String _amountText(CryptoWallet wallet) {
  final b = wallet.unlockedBalance;
  if (b is! double) return '—';
  return b.toStringAsFixed(wallet.decimals.clamp(0, 8));
}

class _Header extends StatelessWidget {
  final CryptoWallet wallet;
  final VoidCallback onSettings;

  const _Header({required this.wallet, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconCircleButton(icon: Icons.close, onPressed: () => Navigator.pop(context)),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 22),
                  const SizedBox(width: 8),
                  Text(wallet.coinName, style: BrandText.appBar.copyWith(fontSize: 16)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconCircleButton(icon: Icons.tune, onPressed: onSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final CryptoWallet wallet;
  final double? totalFiat;
  final String fiatSymbol;
  final FiatRateModel fiatRate;
  final int assetCount;
  final bool hasTokens;

  const _BalanceHero({
    required this.wallet,
    required this.totalFiat,
    required this.fiatSymbol,
    required this.fiatRate,
    required this.assetCount,
    required this.hasTokens,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final showFiat = !fiatRate.isDisabled && totalFiat != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFiat)
            BalanceText.split('$fiatSymbol${_fiatFormat.format(totalFiat)}', style: _balanceStyle)
          else if (wallet.unlockedBalance == null)
            Skeletonizer(child: Text('0.0000', style: _balanceStyle))
          else
            Text('${_amountText(wallet)} ${wallet.coinSymbol}', style: _balanceStyle),
          const SizedBox(height: 10),
          // Subtitle: asset count for token chains, else the coin amount.
          if (hasTokens)
            Text(
              i18n.homeAssetsCount(assetCount),
              style: const TextStyle(
                fontSize: 13.5,
                height: 1,
                color: BrandColors.inkMuted,
              ),
            )
          else if (showFiat)
            Text(
              '${_amountText(wallet)} ${wallet.coinSymbol}',
              style: const TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 13.5,
                height: 1,
                color: BrandColors.inkMuted,
              ),
            ),
          if (!hasTokens && wallet.connectionAddress.isNotEmpty) ...[
            const SizedBox(height: 9),
            _RouteLine(wallet: wallet),
          ],
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final CryptoWallet wallet;
  const _RouteLine({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final state = connectionIndicatorStateFor(wallet);
    final dotColor = switch (state) {
      ConnectionIndicatorState.ok => BrandColors.success,
      ConnectionIndicatorState.loading => BrandColors.warning,
      ConnectionIndicatorState.error => BrandColors.error,
    };

    final parts = <String>[];
    if (state == ConnectionIndicatorState.loading) parts.add(i18n.homeSyncing);
    if (wallet.connectionUseTor) {
      parts.add(i18n.coinHomeRouteTor);
    } else if (wallet.connectionProxyPort.isNotEmpty) {
      parts.add(i18n.coinHomeRouteProxy);
    } else {
      parts.add(i18n.coinHomeRouteDirect);
    }
    final type = _typeLabel(i18n, wallet.connectionType);
    if (type != null) parts.add(type);

    final blocks = wallet.syncBlocksRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              parts.join(' · '),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1,
                color: BrandColors.inkMuted,
              ),
            ),
          ],
        ),
        if (state == ConnectionIndicatorState.loading && blocks != null) ...[
          const SizedBox(height: 8),
          Text(
            i18n.homeBlocksRemaining(NumberFormat.decimalPattern().format(blocks)),
            style: const TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 11.5,
              height: 1,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }

  String? _typeLabel(AppLocalizations i18n, String type) {
    switch (type) {
      case 'lws':
        return i18n.connectionTypeLws;
      case 'node':
        return i18n.connectionTypeNode;
      default:
        return null;
    }
  }
}

class _ActionRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onSwap;

  const _ActionRow({
    required this.enabled,
    required this.onReceive,
    required this.onSend,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ActionButton(
            icon: Icons.arrow_downward,
            label: i18n.homeReceive,
            onPressed: enabled ? onReceive : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            icon: Icons.arrow_upward,
            label: i18n.homeSend,
            onPressed: enabled ? onSend : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            icon: Icons.swap_horiz,
            label: i18n.coinHomeSwap,
            onPressed: onSwap,
          ),
        ),
      ],
    );
  }
}

class _AssetsSection extends StatelessWidget {
  final List<CryptoWallet> assets;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _AssetsSection({
    required this.assets,
    required this.fiatRate,
    required this.fiatSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: SectionHeader(label: i18n.coinHomeAssetsTitle, padding: EdgeInsets.zero),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          child: Column(
            children: [
              for (var i = 0; i < assets.length; i++) ...[
                _AssetRow(wallet: assets[i], fiatRate: fiatRate, fiatSymbol: fiatSymbol),
                if (i != assets.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  final CryptoWallet wallet;
  final FiatRateModel fiatRate;
  final String fiatSymbol;

  const _AssetRow({required this.wallet, required this.fiatRate, required this.fiatSymbol});

  static const _fiatStyle = TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w700,
    color: BrandColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const _amountStyle = TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 11.5,
    height: 1.3,
    color: BrandColors.inkMuted,
  );

  @override
  Widget build(BuildContext context) {
    // Tokens (DAI) start with a null balance until their first background sync
    // fetches `balanceOf`; show a skeleton, not an em-dash, while it's loading.
    final loading = wallet.unlockedBalance == null;
    final fiat = _ownFiat(wallet, fiatRate);
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(16),
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
                  wallet.coinName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Skeletonizer(
                  enabled: loading,
                  child: Text(
                    loading ? '0.000000' : '${_amountText(wallet)} ${wallet.coinSymbol}',
                    style: _amountStyle,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            Skeletonizer(enabled: true, child: Text('\$0.00', style: _fiatStyle))
          else if (fiat != null && !fiatRate.isDisabled)
            BalanceText.split('$fiatSymbol${_fiatFormat.format(fiat)}', style: _fiatStyle),
        ],
      ),
    );
  }
}

/// A transaction paired with the chain asset it belongs to (ETH or DAI, …).
typedef _TxEntry = ({TxDetails tx, CryptoWallet asset});

class _ActivitySliver extends StatelessWidget {
  final CryptoWallet chain;
  final List<CryptoWallet> assets;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final void Function(CryptoWallet asset, TxDetails tx) onTapTx;
  final VoidCallback onSetupExplorer;

  const _ActivitySliver({
    required this.chain,
    required this.assets,
    required this.i18n,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.onTapTx,
    required this.onSetupExplorer,
  });

  @override
  Widget build(BuildContext context) {
    // Merge every chain asset's history into one timeline, newest first.
    final entries = <_TxEntry>[
      for (final asset in assets)
        for (final tx in asset.txHistory) (tx: tx, asset: asset),
    ]..sort((a, b) => b.tx.timestamp.compareTo(a.tx.timestamp));

    if (entries.isEmpty) {
      final needsExplorer = chain.supportsExplorerUrl && chain.explorerAddress.isEmpty;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: needsExplorer
              ? _AddExplorerNudge(i18n: i18n, onSetup: onSetupExplorer)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    i18n.homeNoTransactions,
                    textAlign: TextAlign.center,
                    style: BrandText.bodyMuted,
                  ),
                ),
        ),
      );
    }

    // Flatten into day-header strings interleaved with tx entries.
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is String) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 4 : 16, bottom: 4),
              child: SectionHeader(label: row, padding: EdgeInsets.zero),
            );
          }
          final e = row as _TxEntry;
          // Divider between consecutive tx rows in the same day group only.
          final next = index + 1 < rows.length ? rows[index + 1] : null;
          return _TxRow(
            tx: e.tx,
            asset: e.asset,
            i18n: i18n,
            fiatRate: fiatRate,
            fiatSymbol: fiatSymbol,
            showDivider: next is _TxEntry,
            onTap: () => onTapTx(e.asset, e.tx),
          );
        },
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TxDetails tx;
  final CryptoWallet asset;
  final AppLocalizations i18n;
  final FiatRateModel fiatRate;
  final String fiatSymbol;
  final bool showDivider;
  final VoidCallback onTap;

  const _TxRow({
    required this.tx,
    required this.asset,
    required this.i18n,
    required this.fiatRate,
    required this.fiatSymbol,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final incoming = tx.direction == consts.txDirectionIncoming;
    final coinRate = fiatRate.rateFor(asset.coinSymbol);
    final amount = displayAmount(tx.amountBaseUnits, asset.baseUnitDecimals);
    final amountFiat = coinRate != null ? amount * coinRate : null;
    final confirmed = asset.isTxConfirmed(tx);
    final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000);
    final amountColor = incoming ? BrandColors.success : BrandColors.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.surfaceTinted)),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            _TxAssetIcon(asset: asset, incoming: incoming),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incoming ? i18n.coinHomeReceived : i18n.coinHomeSent,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (!confirmed) ...[
                        Icon(Icons.hourglass_top_rounded, size: 12, color: BrandColors.warning),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        // Default (en) symbols: initializeDateFormatting isn't wired, so a
                        // locale arg would throw for pt.
                        '${DateFormat('HH:mm').format(date)} · ${asset.coinName}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${incoming ? '+' : '−'}${amount.toStringAsFixed(asset.decimals.clamp(0, 8))} ${asset.coinSymbol}',
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (amountFiat != null && !fiatRate.isDisabled) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$fiatSymbol${_fiatFormat.format(amountFiat)}',
                    style: const TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 11,
                      height: 1.3,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The asset's chain tile with a small direction badge (receive / send).
class _TxAssetIcon extends StatelessWidget {
  final CryptoWallet asset;
  final bool incoming;

  const _TxAssetIcon({required this.asset, required this.incoming});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CoinMark(coinSymbol: asset.coinSymbol, iconAsset: asset.iconAsset, size: 36),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.paper,
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.hairline, width: 1.5),
              ),
              child: Icon(
                incoming ? Icons.south : Icons.north,
                size: 10,
                color: incoming ? BrandColors.success : BrandColors.cinnamon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tan nudge card shown under Activity when the coin needs a block explorer to
/// surface transaction history.
class _AddExplorerNudge extends StatelessWidget {
  final AppLocalizations i18n;
  final VoidCallback onSetup;

  const _AddExplorerNudge({required this.i18n, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6E8D2),
        border: Border.all(color: BrandColors.borderStrong),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.search, size: 19, color: BrandColors.cinnamon),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  i18n.coinHomeAddExplorerTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSetup,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.cinnamonDeep,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                i18n.coinHomeAddExplorerButton,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: BrandColors.onCinnamon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

