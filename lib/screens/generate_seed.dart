import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/create_wallet.dart';
import 'package:spice_wallet/screens/create_wallet_password.dart';
import 'package:spice_wallet/screens/desktop/onboarding_steps.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class GenerateSeedScreen extends StatefulWidget {
  const GenerateSeedScreen({super.key});

  @override
  State<GenerateSeedScreen> createState() => _GenerateSeedScreenState();
}

class _GenerateSeedScreenState extends State<GenerateSeedScreen> with SecureScreenMixin {
  List<String> _seed = [];
  DateTime? _restoreDate;
  String? _mnemonic;
  SeedSource? _seedSource;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final result = Provider.of<WalletManager>(context, listen: false).generateSeed();
    _seedSource = result.seed;
    _mnemonic = result.seed.mnemonic;
    _seed = result.seed.mnemonic.split(' ');
    _restoreDate = result.restoreDate;
  }

  Future<void> _continue() async {
    if (_mnemonic == null || _restoreDate == null) return;
    setState(() => _isCreating = true);

    final manager = Provider.of<WalletManager>(context, listen: false);
    try {
      await manager.restoreAll(seed: _seedSource!, from: RestorePoint.date(_restoreDate!));
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        setState(() => _isCreating = false);
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

  /// A desktop OS (password-last flow): carry the seed to the password step,
  /// which encrypts and creates the wallet.
  void _continueDesktop() {
    if (_seedSource == null || _restoreDate == null) return;
    Navigator.pushNamed(
      context,
      '/create_wallet_password',
      arguments: CreateWalletPasswordArgs(
        seed: _seedSource!,
        from: RestorePoint.date(_restoreDate!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    if (isDesktop) {
      return DesktopGenerateSeedView(
        logo: SvgPicture.asset('assets/spice-mark.svg', height: 52),
        step: 4,
        totalSteps: desktopOnboardingSteps,
        title: i18n.generateSeedTitle,
        description: i18n.generateSeedSubtitleRevealed,
        seedWords: _seed,
        birthdayLabel: i18n.generateSeedBirthdayLabel,
        birthdayReason: i18n.generateSeedBirthdayReason,
        birthdayValue: _restoreDate != null
            ? DateFormat.yMMM(Localizations.localeOf(context).toString()).format(_restoreDate!)
            : null,
        confirmLabel: i18n.generateSeedConfirm,
        passwordNote: isDesktopOS ? i18n.generateSeedPasswordNote : null,
        revealLabel: i18n.generateSeedReveal,
        continueText: i18n.generateSeedContinueButton,
        loading: _isCreating,
        // The iOS build on a Mac shows this layout but keeps the mobile wallet
        // password, so it creates the wallet here with no password step.
        onContinue: isDesktopOS ? _continueDesktop : _continue,
        onBack: () => Navigator.pop(context),
      );
    }

    return GenerateSeedView(
      stepCount: 4,
      stepIndex: 3,
      continueLoading: _isCreating,
      seedWords: _seed,
      birthdayCard: _restoreDate != null
          ? SeedBirthdayCard(
              label: i18n.generateSeedBirthdayLabel,
              reason: i18n.generateSeedBirthdayReason,
              value: DateFormat.yMMM(
                Localizations.localeOf(context).toString(),
              ).format(_restoreDate!),
            )
          : null,
      onContinue: _continue,
      labels: GenerateSeedLabels(
        titleCovered: i18n.generateSeedTitleCovered,
        titleRevealed: i18n.generateSeedTitle,
        subtitleCovered: i18n.generateSeedSubtitleCovered,
        subtitleRevealed: i18n.generateSeedSubtitleRevealed,
        reveal: i18n.generateSeedReveal,
        screenshotNote: i18n.generateSeedScreenshotNote,
        confirm: i18n.generateSeedConfirm,
        continueText: i18n.generateSeedContinueButton,
      ),
    );
  }
}
