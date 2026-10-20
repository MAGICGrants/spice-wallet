import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/spinning_logo.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_fhse/security_keys_ui.dart'
    show FhseLocalizations, showAppLockRecoveryPhrase, waitForFullLock, walletNeedsSecurityKey;
import 'package:wallet_infra/wallet_infra.dart'
    show BiometricAuth, BiometricAuthResult, BoundToAnotherPcException;

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, this.onUnlocked, this.onKeyNeeded});

  /// Set when this is App Lock's cover over the screens the user left
  /// (`AppLockCover`), which has no route to pop: the app hides the cover.
  final VoidCallback? onUnlocked;

  /// The cover's way on when the wallet closed meanwhile and a security key
  /// comes next: the app replaces its stack with the key screen.
  final VoidCallback? onKeyNeeded;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;
  String? _biometricLabel; // resolved per device on iOS (Face ID vs Touch ID)
  bool _started = false;
  // The device could not confirm its owner (a lockout, say): the recovery
  // phrase is offered as the way in instead.
  bool _offerRecoveryPhrase = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    if (isDesktopOS) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) {
          setState(() => _version = 'Spice Wallet v${info.version} · build ${info.buildNumber}');
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The typed password at every launch (Linux, Windows); App Lock's device
    // prompt elsewhere, macOS included (Touch ID or the Mac's password).
    if (_started || typesWalletPassword) return;
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
      // A passcode alone keeps the generic "Unlock".
      if (types.isEmpty) return;
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

  /// [reopen] false: App Lock only checked the password again, over wallets
  /// that stayed open (Linux and Windows after a time without use).
  void _unlockDone(WalletManager manager, {bool reopen = true}) {
    // No key to follow: this was the last lock ([AppSession]).
    AppSession.markUnlocked();
    // A relock covers the screen the user left, and the app uncovers it. At a
    // launch or after a full lock this is the base route: home comes next.
    final onUnlocked = widget.onUnlocked;
    if (onUnlocked != null) {
      onUnlocked();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/wallet_home', (route) => false);
    }
    if (reopen) manager.openWalletFilesAndSync();
  }

  /// A security key comes next: the key screen replaces the stack.
  void _toSecurityKey() {
    final onKeyNeeded = widget.onKeyNeeded;
    if (onKeyNeeded != null) return onKeyNeeded();
    Navigator.of(context).pushNamedAndRemoveUntil('/security_key_unlock', (route) => false);
  }

  Future<void> _promptUnlock() async {
    final i18n = AppLocalizations.of(context)!;
    // Always asks (App Lock is always on); a device with no lock at all has
    // nothing to ask and passes, and Settings warns about it.
    final result = await BiometricAuth.confirmOwner(reason: i18n.unlockReason);

    // Auto-prompted, so stay silent on a decline; report only a real error,
    // and offer the recovery phrase for it.
    if (result == BiometricAuthResult.failed) return;
    if (result == BiometricAuthResult.error) {
      if (mounted) setState(() => _offerRecoveryPhrase = true);
      _showError(i18n.unlockUnableToAuthError);
      return;
    }

    if (!mounted) return;
    final manager = Provider.of<WalletManager>(context, listen: false);
    // A full lock still closing the wallets decides what comes next.
    await waitForFullLock();
    if (!mounted) return;
    // With security keys on and the wallet closed, a key comes next.
    if (await walletNeedsSecurityKey(context)) {
      if (mounted) _toSecurityKey();
      return;
    }
    // A full lock still closing the wallets finishes before they reopen.
    await waitForFullLock();
    // Behind security keys a relock keeps the password in memory (the keystore
    // has none to load); otherwise it comes back from the keystore.
    if (!manager.hasPassword && !await manager.loadStoredPassword()) {
      log(LogLevel.error, 'Biometric auth succeeded but no stored wallet password');
      _showError(i18n.unlockUnableToAuthError);
      return;
    }
    if (mounted) _unlockDone(manager);
  }

  /// The device could not confirm its owner: the recovery phrase opens the
  /// wallets instead (and stands in for a security key, when keys are on).
  Future<void> _useRecoveryPhrase() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (await showAppLockRecoveryPhrase(context) && mounted) _unlockDone(manager);
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
    final manager = Provider.of<WalletManager>(context, listen: false);
    // App Lock after a time without use: the wallets stayed open, so the
    // password is only checked again, not used to reopen them.
    final opened = manager.hasPassword;
    final bool right;
    try {
      right = opened
          ? await manager.checkTypedPassword(_passwordController.text)
          : await manager.unlockWithTypedPassword(_passwordController.text);
    } on BoundToAnotherPcException {
      // The files are bound to a PC whose TPM this one cannot use.
      if (mounted) {
        _passwordController.clear();
        setState(() {
          _error = FhseLocalizations.of(context).unlockBoundToAnotherPc;
          _isLoading = false;
        });
      }
      return;
    }
    if (!right) {
      if (mounted) {
        _passwordController.clear();
        setState(() {
          _error = i18n.unlockIncorrectPasswordError;
          _isLoading = false;
        });
      }
      return;
    }
    if (opened) {
      _passwordController.clear();
      if (mounted) _unlockDone(manager, reopen: false);
      return;
    }
    // With security keys on, the password was right and a key comes next.
    if (!manager.hasPassword) {
      if (mounted) _toSecurityKey();
      return;
    }
    if (mounted) _unlockDone(manager);
  }

  void _showError(String message) {
    if (mounted) {
      showBrandToast(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    // The view blocks the system back button, which must never leave a lock
    // screen; as the relock's cover the app swallows it too.
    return UnlockView(
      // Same spin-in as the welcome screen (pivots on the mark's off-centre spiral).
      logo: SpinningLogo(
        alignment: const Alignment(-0.133, -0.283),
        child: SvgPicture.asset('assets/spice-mark.svg', width: 84, height: 84),
      ),
      labels: UnlockLabels(
        title: i18n.unlockLockedTitle,
        passwordHint: i18n.unlockPasswordHint,
        unlockButton: i18n.unlockButton,
        passwordLabel: i18n.unlockPasswordLabel,
      ),
      // Password entry on a desktop OS. Everywhere else, the iOS build on a Mac
      // included, the password is in the keystore behind the device auth.
      isDesktop: typesWalletPassword,
      version: _version.isEmpty ? null : _version,
      passwordController: _passwordController,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      error: _error,
      loading: _isLoading,
      biometricLabel: _biometricLabel,
      onUnlockPassword: _unlockWithPassword,
      onUnlockBiometric: _promptUnlock,
      recoveryLabel: _offerRecoveryPhrase
          ? FhseLocalizations.of(context).securityKeyUseRecoveryPhrase
          : null,
      onUseRecoveryPhrase: _useRecoveryPhrase,
    );
  }
}
