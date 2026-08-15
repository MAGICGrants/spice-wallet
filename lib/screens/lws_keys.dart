import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/secure_clipboard.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;
import 'package:wallet_domain/wallet_domain.dart';

/// Shows the Monero wallet's LWS details (primary address, secret view key,
/// restore height) so the user can whitelist the wallet on a light-wallet
/// server. Read-only with copy buttons.
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

  Widget _copyField(String label, String value, {bool sensitive = false}) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        suffixIcon: IconButton(
          onPressed: () => sensitive
              ? SecureClipboard.copy(value)
              : Clipboard.setData(ClipboardData(text: value)),
          icon: Icon(Icons.copy),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final wallet = context.watch<WalletManager>().getWallet('XMR') as MoneroWallet?;
    final primaryAddress = wallet?.getPrimaryAddress() ?? '';
    final secretViewKey = _secretViewKey;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.lwsKeysTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Text(i18n.lwsDetailsDescription, style: Theme.of(context).textTheme.bodyLarge),
                  _copyField(i18n.lwsKeysPrimaryAddress, primaryAddress, sensitive: true),
                  _copyField(i18n.lwsKeysSecretViewKey, secretViewKey, sensitive: true),
                  _copyField(i18n.lwsKeysRestoreHeight, _restoreHeight.toString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
