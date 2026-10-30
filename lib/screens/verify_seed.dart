import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager;
import 'package:wallet_fhse/security_keys_ui.dart' show lockWalletAction;

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Desktop: the seed check as a centered modal over the home.
Future<void> showVerifySeedSheet(BuildContext context) => showBrandSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const VerifySeedScreen(embedded: true),
);

/// The seed check from the home's security checklist: three words of the seed
/// phrase at random positions, never showing any.
class VerifySeedScreen extends StatefulWidget {
  /// Content only, for [showVerifySeedSheet].
  final bool embedded;

  const VerifySeedScreen({super.key, this.embedded = false});

  @override
  State<VerifySeedScreen> createState() => _VerifySeedScreenState();
}

class _VerifySeedScreenState extends State<VerifySeedScreen> with SecureScreenMixin {
  late final SeedVerifier _verifier;

  // Bound up front: the lock must still run if this page is closed during a
  // check.
  late final Future<void> Function() _lock;

  @override
  void initState() {
    super.initState();
    _lock = lockWalletAction(context);
    final manager = context.read<WalletManager>();
    _verifier = SeedVerifier(
      loadWords: () async {
        final stored = await manager.loadStoredSeed();
        if (stored == null) return null;
        return stored.seed.mnemonic.trim().split(RegExp(r'\s+'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return SeedVerifyView(
      labels: SeedVerifyLabels(
        title: i18n.verifySeedTitle,
        subtitle: (p) => i18n.verifySeedSubtitle(p[0], p[1], p[2]),
        verifyButton: i18n.verifySeedButton,
        wrongTitle: i18n.verifySeedWrongTitle,
        wrongBody: i18n.verifySeedWrongBody,
        tryAgain: i18n.verifySeedTryAgain,
        unavailable: i18n.verifySeedUnavailable,
      ),
      verifier: _verifier,
      embedded: widget.embedded,
      onVerified: () {
        showBrandToast(context, i18n.verifySeedDone);
        Navigator.pop(context);
      },
      onLocked: _lock,
    );
  }
}
