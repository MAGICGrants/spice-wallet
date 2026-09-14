import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class CreateWalletPasswordScreen extends StatefulWidget {
  const CreateWalletPasswordScreen({super.key});

  @override
  State<CreateWalletPasswordScreen> createState() => _CreateWalletPasswordScreenState();
}

class _CreateWalletPasswordScreenState extends State<CreateWalletPasswordScreen> {
  bool _isLoading = false;

  Future<void> _savePassword(String password) async {
    setState(() => _isLoading = true);

    try {
      if (mounted) {
        final manager = Provider.of<WalletManager>(context, listen: false);
        manager.setWalletPassword(password);
        Navigator.pushNamed(context, '/create_wallet');
      }
    } catch (e) {
      if (mounted) {
        showBrandToast(context, 'Failed to save password: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return CreatePasswordView(
      loading: _isLoading,
      onSubmit: _savePassword,
      labels: CreatePasswordLabels(
        title: i18n.createWalletPasswordTitle,
        description: i18n.createWalletPasswordDescription,
        passwordHint: i18n.createWalletPasswordHint,
        confirmPasswordHint: i18n.createWalletConfirmPasswordHint,
        submit: i18n.continueText,
        fieldEmptyError: i18n.fieldEmptyError,
        tooShortError: i18n.passwordTooShortError,
        doNotMatchError: i18n.passwordsDoNotMatchError,
      ),
    );
  }
}
