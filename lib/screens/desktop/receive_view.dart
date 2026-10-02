import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/screens/desktop/home_shell.dart';

/// Desktop receive (inside [DesktopShell]): a QR panel on the left, and the coin
/// card, subaddress/primary toggle, address and Copy on the right. Presentational
/// — the screen computes the address/heading/warning and supplies callbacks.
class DesktopReceiveView extends StatelessWidget {
  final String title;
  final String copyLabel;
  final String qrHint;
  final String coinSymbol;
  final String iconAsset;
  final String coinName;
  final String? blockchainSubtitle;
  final bool ready;
  final String address;
  final String qrHeading;
  final List<String>? tabLabels;
  final int selectedTab;
  final ValueChanged<int>? onSelectTab;
  final String? warning;
  final VoidCallback onCopy;
  final VoidCallback onBack;
  final List<ReceiveAssetOption> assetOptions;
  final ValueChanged<String>? onSelectAsset;

  const DesktopReceiveView({
    super.key,
    required this.title,
    required this.copyLabel,
    required this.qrHint,
    required this.coinSymbol,
    required this.iconAsset,
    required this.coinName,
    required this.blockchainSubtitle,
    required this.ready,
    required this.address,
    required this.qrHeading,
    required this.onCopy,
    required this.onBack,
    this.tabLabels,
    this.selectedTab = 0,
    this.onSelectTab,
    this.warning,
    this.assetOptions = const [],
    this.onSelectAsset,
  });

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return Center(child: CircularProgressIndicator(color: BrandColors.primary));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 30, 44, 36),
      children: [
        DesktopBackLink(label: coinName, onTap: onBack),
        const SizedBox(height: 16),
        Text(title, style: desktopTitleStyle),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            // Two columns (QR beside details) only when there's room; below that,
            // stack the QR above the details.
            const twoColMinWidth = 640.0;
            final qr = SizedBox(width: 300, child: _qrCard());
            if (constraints.maxWidth < twoColMinWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: qr),
                  const SizedBox(height: 24),
                  _details(context),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                qr,
                const SizedBox(width: 28),
                Expanded(child: _details(context)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _qrCard() {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(
              data: address,
              size: 232,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            qrHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 12,
              height: 1.5,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (assetOptions.length > 1 && onSelectAsset != null)
          ReceiveAssetSelectorCard(
            coinSymbol: coinSymbol,
            iconAsset: iconAsset,
            coinName: coinName,
            blockchainSubtitle: blockchainSubtitle,
            options: assetOptions,
            onSelect: onSelectAsset!,
          )
        else
          _CoinCard(
            coinSymbol: coinSymbol,
            iconAsset: iconAsset,
            coinName: coinName,
            blockchainSubtitle: blockchainSubtitle,
          ),
        if (tabLabels != null) ...[
          const SizedBox(height: 14),
          BrandSegmented(
            dense: true,
            labels: tabLabels!,
            selectedIndex: selectedTab,
            onSelect: onSelectTab ?? (_) {},
          ),
        ],
        const SizedBox(height: 18),
        SectionHeader(label: qrHeading, padding: EdgeInsets.zero),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: BrandColors.card,
            border: Border.all(color: BrandColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: SelectableText(
            address,
            style: TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 13.5,
              height: 1.7,
              color: BrandColors.ink,
            ),
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: 12),
          Text(
            warning!,
            style: BrandText.caption.copyWith(color: BrandColors.warning, height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: BrandButton(
            label: copyLabel,
            icon: Icons.copy_outlined,
            expand: false,
            dense: true,
            onPressed: onCopy,
          ),
        ),
      ],
    );
  }
}

class _CoinCard extends StatelessWidget {
  final String coinSymbol;
  final String iconAsset;
  final String coinName;
  final String? blockchainSubtitle;

  const _CoinCard({
    required this.coinSymbol,
    required this.iconAsset,
    required this.coinName,
    required this.blockchainSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          CoinMark(coinSymbol: coinSymbol, iconAsset: iconAsset, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coinName,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.ink,
                  ),
                ),
                if (blockchainSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    blockchainSubtitle!,
                    style: BrandText.caption.copyWith(fontSize: 11.5, color: BrandColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
