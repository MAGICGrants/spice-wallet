import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/secure_clipboard.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;
import 'package:wallet_domain/wallet_domain.dart';

/// Shows the Monero wallet's LWS details (primary address, secret view key,
/// restore height) so the user can whitelist the wallet on a light-wallet
/// server. Read-only with copy buttons; the view key is hidden until tapped.
class LwsKeysScreen extends StatefulWidget {
  const LwsKeysScreen({super.key});

  @override
  State<LwsKeysScreen> createState() => _LwsKeysScreenState();
}

class _LwsKeysScreenState extends State<LwsKeysScreen> with SecureScreenMixin {
  var _restoreHeight = 0;
  var _secretViewKey = '';
  var _viewKeyRevealed = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final wallet = Provider.of<WalletManager>(context, listen: false).getWallet('XMR');
    if (wallet is! MoneroWallet) return;
    final restoreHeight = await wallet.getRestoreHeight();
    final secretViewKey = await wallet.readSecretViewKey();
    if (!mounted) return;
    setState(() {
      _restoreHeight = restoreHeight;
      _secretViewKey = secretViewKey;
    });
  }

  void _copy(String value, {required bool sensitive}) {
    if (value.isEmpty) return;
    if (sensitive) {
      SecureClipboard.copy(value);
    } else {
      Clipboard.setData(ClipboardData(text: value));
    }
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletManager>().getWallet('XMR') as MoneroWallet?;
    final primaryAddress = wallet?.getPrimaryAddress() ?? '';

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    onBack: () => Navigator.pop(context),
                    center: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoinMark(coinSymbol: 'XMR', iconAsset: wallet?.iconAsset ?? '', size: 22),
                        const SizedBox(width: 8),
                        Text(i18n.lwsKeysTitle, style: BrandText.appBar.copyWith(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          child: Text(
                            i18n.lwsDetailsDescription,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.6,
                              color: BrandColors.inkMuted,
                            ),
                          ),
                        ),
                        _KeyField(
                          label: i18n.lwsKeysPrimaryAddress,
                          value: primaryAddress,
                          onCopy: () => _copy(primaryAddress, sensitive: true),
                        ),
                        _KeyField(
                          label: i18n.lwsKeysSecretViewKey,
                          value: _secretViewKey,
                          onCopy: () => _copy(_secretViewKey, sensitive: true),
                          hidden: !_viewKeyRevealed,
                          onReveal: () => setState(() => _viewKeyRevealed = true),
                        ),
                        _KeyField(
                          label: i18n.lwsKeysRestoreHeight,
                          value: _restoreHeight.toString(),
                          onCopy: () => _copy(_restoreHeight.toString(), sensitive: false),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                margin: const EdgeInsets.only(top: 1),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: BrandColors.inverseSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.visibility_off_outlined,
                                  size: 14,
                                  color: BrandColors.onCinnamon,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  i18n.lwsKeysWarning,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.5,
                                    color: BrandColors.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

/// A labelled read-only value card with a copy chip. [hidden] blurs the value
/// behind a "tap to reveal" overlay (used for the secret view key).
class _KeyField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool hidden;
  final VoidCallback? onReveal;

  const _KeyField({
    required this.label,
    required this.value,
    required this.onCopy,
    this.hidden = false,
    this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: TextStyle(
        fontFamily: 'Ubuntu Mono',
        fontSize: 12.5,
        height: 1.6,
        color: BrandColors.ink,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(label: label, padding: const EdgeInsets.only(left: 4, bottom: 9)),
          BrandCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: hidden
                          ? ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: valueText,
                            )
                          : valueText,
                    ),
                    const SizedBox(width: 11),
                    _CopyChip(onTap: onCopy),
                  ],
                ),
                if (hidden && onReveal != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReveal,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            color: BrandColors.inverseSurface,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.generateSeedReveal,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: BrandColors.onCinnamon,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 34×34 tan copy button used inside a key card.
class _CopyChip extends StatelessWidget {
  final VoidCallback onTap;

  const _CopyChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: BrandColors.border),
        ),
        child: Icon(Icons.copy_outlined, size: 15, color: BrandColors.cinnamonDeep),
      ),
    );
  }
}
