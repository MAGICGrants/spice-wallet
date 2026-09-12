import 'package:flutter/material.dart';
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

  void _copy(String value) {
    if (value.isEmpty) return;
    SecureClipboard.copy(value);
    final i18n = AppLocalizations.of(context)!;
    showCopyToast(context, i18n.copiedToClipboard);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletManager>().getWallet('XMR') as MoneroWallet?;

    return LwsKeysView(
      labels: LwsKeysLabels(
        title: i18n.lwsKeysTitle,
        description: i18n.lwsDetailsDescription,
        primaryAddressLabel: i18n.lwsKeysPrimaryAddress,
        viewKeyLabel: i18n.lwsKeysSecretViewKey,
        restoreHeightLabel: i18n.lwsKeysRestoreHeight,
        reveal: i18n.generateSeedReveal,
        warning: i18n.lwsKeysWarning,
      ),
      headerIcon: CoinMark(coinSymbol: 'XMR', iconAsset: wallet?.iconAsset ?? '', size: 22),
      primaryAddress: wallet?.getPrimaryAddress() ?? '',
      secretViewKey: _secretViewKey,
      restoreHeight: _restoreHeight.toString(),
      onCopy: _copy,
      onBack: () => Navigator.pop(context),
    );
  }
}
