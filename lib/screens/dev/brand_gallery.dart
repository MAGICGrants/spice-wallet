import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:spice_wallet/widgets/ui/ui.dart';

/// Dev-only preview of the brand widget set (`lib/widgets/ui/`). Not linked in
/// the shipping nav — reach it via the `/brand_gallery` route.
class BrandGalleryScreen extends StatelessWidget {
  const BrandGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.paper,
      // Constrained to a phone width — the design is mobile (390px); on a wide
      // window the widgets would stretch and read oversized.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(BrandSpacing.lg),
              children: [
                Row(
                  children: [
                    IconCircleButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: BrandSpacing.md),
                    Text('Brand kit', style: BrandText.title),
                  ],
                ),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Balance'),
                BalanceText.split(r'$99,412.65'),
                const SizedBox(height: BrandSpacing.xs),
                const StatusPill(label: 'Internal Tor · LWS'),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Action buttons'),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        icon: Icons.arrow_downward,
                        label: 'Receive',
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: BrandSpacing.md),
                    Expanded(
                      child: ActionButton(
                        icon: Icons.arrow_upward,
                        label: 'Send',
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: BrandSpacing.md),
                    Expanded(
                      child: ActionButton(icon: Icons.swap_horiz, label: 'Swap', onPressed: () {}),
                    ),
                  ],
                ),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Buttons'),
                BrandButton(label: 'Get started', onPressed: () {}),
                const SizedBox(height: BrandSpacing.md),
                BrandButton.outline(label: 'Restore from a seed', onPressed: () {}),
                const SizedBox(height: BrandSpacing.md),
                const BrandButton(label: 'Disabled', onPressed: null),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Icon buttons'),
                Row(
                  children: [
                    IconCircleButton(icon: Icons.close, onPressed: () {}),
                    const SizedBox(width: BrandSpacing.md),
                    IconCircleButton(icon: Icons.tune, onPressed: () {}),
                    const SizedBox(width: BrandSpacing.md),
                    IconCircleButton(icon: Icons.qr_code_scanner, onPressed: () {}),
                  ],
                ),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Assets'),
                AssetRow(
                  card: true,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
                  leading: const _Glyph(color: BrandColors.monero, asset: 'monero-glyph.svg'),
                  title: 'Monero',
                  subtitle: '412.090412 XMR',
                  subtitleStyle: BrandText.mono.copyWith(fontSize: 11.5, height: 1.3),
                  trailing: BalanceText.split(r'$99,412.65', style: BrandText.amount),
                  onTap: () {},
                ),
                const SizedBox(height: BrandSpacing.sm),
                AssetRow(
                  card: true,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
                  leading: const _Glyph(color: BrandColors.bitcoin, asset: 'bitcoin-glyph.svg'),
                  title: 'Bitcoin',
                  subtitle: '0.00000000 BTC',
                  subtitleStyle: BrandText.mono.copyWith(fontSize: 11.5, height: 1.3),
                  trailing: BalanceText.split(r'$0.00', style: BrandText.amount),
                  onTap: () {},
                ),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Activity'),
                AssetRow(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  leading: IconBadge(icon: Icons.arrow_downward, color: BrandColors.success),
                  title: 'Received',
                  subtitle: '18 Aug · 14:22',
                  onTap: () {},
                ),
                Divider(height: 1, color: BrandColors.surfaceTinted),
                AssetRow(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  leading: IconBadge(icon: Icons.swap_horiz, color: BrandColors.cinnamonDeep),
                  title: 'Bridged to Serai',
                  subtitle: '16 Aug · 09:07',
                  onTap: () {},
                ),
                Divider(height: 1, color: BrandColors.surfaceTinted),
                AssetRow(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  leading: IconBadge(icon: Icons.arrow_upward, color: BrandColors.error),
                  title: 'Sent',
                  subtitle: '11 Aug · 20:41',
                  onTap: () {},
                ),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Text field'),
                BrandTextField(
                  hint: 'Enter an address',
                  suffix: Icon(Icons.paste, color: BrandColors.cinnamon),
                ),
                const SizedBox(height: BrandSpacing.xl),

                _Label('Step dots'),
                const StepDots(count: 4, index: 1),
                const SizedBox(height: BrandSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BrandSpacing.md),
    child: SectionHeader(label: text),
  );
}

class _Glyph extends StatelessWidget {
  final Color color;
  final String asset;
  const _Glyph({required this.color, required this.asset});
  @override
  Widget build(BuildContext context) =>
      CoinTile(color: color, glyph: SvgPicture.asset('assets/icons/$asset', width: 22, height: 22));
}
