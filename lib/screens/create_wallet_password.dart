import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/create_wallet.dart';
import 'package:spice_wallet/screens/desktop/create_password_view.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Desktop passes the generated/entered seed here so the wallet is created and
/// encrypted at this final step (the design's password-last flow). Absent on
/// the mobile fallback path, where the password is set before wallet creation.
class CreateWalletPasswordArgs {
  final SeedSource seed;
  final RestorePoint from;
  const CreateWalletPasswordArgs({required this.seed, required this.from});
}

class CreateWalletPasswordScreen extends StatefulWidget {
  const CreateWalletPasswordScreen({super.key});

  @override
  State<CreateWalletPasswordScreen> createState() => _CreateWalletPasswordScreenState();
}

class _CreateWalletPasswordScreenState extends State<CreateWalletPasswordScreen> {
  bool _isLoading = false;

  /// Mobile fallback: store the password, then go on to the create/restore step.
  Future<void> _savePassword(String password) async {
    setState(() => _isLoading = true);
    try {
      if (mounted) {
        Provider.of<WalletManager>(context, listen: false).setWalletPassword(password);
        Navigator.pushNamed(context, '/create_wallet');
      }
    } catch (e) {
      if (mounted) showBrandToast(context, 'Failed to save password: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Desktop (password-last): encrypt with this password and create the wallet
  /// from the seed carried in [args].
  Future<void> _createWallet(String password, CreateWalletPasswordArgs args) async {
    setState(() => _isLoading = true);
    final manager = Provider.of<WalletManager>(context, listen: false);
    manager.setWalletPassword(password);
    try {
      await manager.restoreAll(seed: args.seed, from: args.from);
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamed(
          context,
          '/create_wallet',
          arguments: CreateWalletScreenArgs(toastMessage: 'Sorry, something went wrong.'),
        );
      }
      return;
    }
    manager.syncInBackground();
    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final args = ModalRoute.of(context)?.settings.arguments as CreateWalletPasswordArgs?;

    final labels = CreatePasswordLabels(
      title: i18n.createWalletPasswordTitle,
      description: i18n.createWalletPasswordDescription,
      passwordHint: i18n.createWalletPasswordHint,
      confirmPasswordHint: i18n.createWalletConfirmPasswordHint,
      submit: i18n.continueText,
      fieldEmptyError: i18n.fieldEmptyError,
      tooShortError: i18n.passwordTooShortError,
      doNotMatchError: i18n.passwordsDoNotMatchError,
    );

    if (isDesktop) {
      return DesktopCreatePasswordView(
        labels: labels,
        continueText: i18n.continueText,
        loading: _isLoading,
        onSubmit: (password) =>
            args != null ? _createWallet(password, args) : _savePassword(password),
        onBack: () => Navigator.pop(context),
      );
    }

    return CreatePasswordView(loading: _isLoading, onSubmit: _savePassword, labels: labels);
  }
}
