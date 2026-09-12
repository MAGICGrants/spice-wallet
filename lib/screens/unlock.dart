import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  static bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;
  String? _biometricLabel; // resolved per device on iOS (Face ID vs Touch ID)
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _isDesktop) return;
    _started = true;
    _resolveBiometricLabel();
    _promptUnlock();
  }

  /// iOS labels the affordance by the device's biometric (Face ID / Touch ID);
  /// Android and desktop keep the generic "Unlock".
  Future<void> _resolveBiometricLabel() async {
    if (!Platform.isIOS) return;
    final i18n = AppLocalizations.of(context)!;
    try {
      final types = await LocalAuthentication().getAvailableBiometrics();
      final label = types.contains(BiometricType.face)
          ? i18n.unlockWithFaceId
          : i18n.unlockWithTouchId;
      if (mounted) setState(() => _biometricLabel = label);
    } catch (_) {
      // Leave the generic label.
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _unlockDone(WalletManager manager) {
    // A relock pushes this screen over the existing stack, so pop back to the
    // screen the user left. A cold start has this as the base route (nothing to
    // pop) — go to home instead.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil('/wallet_home', (route) => false);
    }
    manager.openWalletFilesAndSync();
  }

  Future<void> _promptUnlock() async {
    final i18n = AppLocalizations.of(context)!;
    final result = await BiometricAuth.authenticate(reason: i18n.unlockReason);

    // Auto-prompted, so stay silent on a decline; report only a real error.
    if (result == BiometricAuthResult.failed) return;
    if (result == BiometricAuthResult.error) {
      _showError(i18n.unlockUnableToAuthError);
      return;
    }

    if (!mounted) return;
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (!await manager.loadMobileWalletPassword()) {
      log(LogLevel.error, 'Biometric auth succeeded but no stored wallet password');
      _showError(i18n.unlockUnableToAuthError);
      return;
    }
    if (mounted) _unlockDone(manager);
  }

  Future<void> _unlockWithPassword() async {
    final i18n = AppLocalizations.of(context)!;
    if (_passwordController.text.isEmpty) {
      setState(() => _error = i18n.fieldEmptyError);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final manager = Provider.of<WalletManager>(context, listen: false);
      manager.setWalletPassword(_passwordController.text);
      if (mounted) _unlockDone(manager);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = i18n.unlockIncorrectPasswordError;
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      showBrandToast(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    // The view blocks the system back button: this screen sits over the previous
    // stack on a relock, and backing out would reveal it unauthenticated.
    // Unlocking still pops programmatically from _unlockDone.
    return UnlockView(
      logo: SvgPicture.asset('assets/spice-mark.svg', width: 84, height: 84),
      labels: UnlockLabels(
        title: i18n.unlockLockedTitle,
        passwordHint: i18n.unlockPasswordHint,
        unlockButton: i18n.unlockButton,
      ),
      isDesktop: _isDesktop,
      passwordController: _passwordController,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      error: _error,
      loading: _isLoading,
      biometricLabel: _biometricLabel,
      onUnlockPassword: _unlockWithPassword,
      onUnlockBiometric: _promptUnlock,
    );
  }
}
