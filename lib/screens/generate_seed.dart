import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/seed_grid.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/create_wallet.dart';
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
  bool _revealed = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    final result = Provider.of<WalletManager>(context, listen: false).generateSeed();
    _seedSource = result.seed;
    _mnemonic = result.seed.mnemonic;
    _seed = result.seed.mnemonic.split(' ');
    _restoreDate = result.restoreDate;
  }

  bool get _canContinue => _revealed && _confirmed && !_isCreating;

  Future<void> _continue() async {
    if (!_canContinue || _mnemonic == null || _restoreDate == null) return;
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: BrandSpacing.sm),
              BrandScreenHeader(
                onBack: () => Navigator.maybePop(context),
                center: const StepDots(count: 4, index: 3),
                action: _revealed
                    ? IconCircleButton(
                        icon: Icons.visibility_off_outlined,
                        onPressed: () => setState(() => _revealed = false),
                      )
                    : null,
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(
                _revealed ? i18n.generateSeedTitle : i18n.generateSeedTitleCovered,
                style: BrandText.title,
              ),
              const SizedBox(height: BrandSpacing.sm),
              Text(
                _revealed ? i18n.generateSeedSubtitleRevealed : i18n.generateSeedSubtitleCovered,
                style: BrandText.bodyMuted,
              ),
              const SizedBox(height: BrandSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    SeedGrid(
                      words: _seed,
                      revealed: _revealed,
                      revealLabel: i18n.generateSeedReveal,
                      screenshotNote: i18n.generateSeedScreenshotNote,
                      onReveal: () => setState(() => _revealed = true),
                    ),
                    if (_revealed) ...[
                      const SizedBox(height: BrandSpacing.lg),
                      if (_restoreDate != null)
                        SeedBirthdayCard(
                          label: i18n.generateSeedBirthdayLabel,
                          reason: i18n.generateSeedBirthdayReason,
                          value: DateFormat.yMMM(
                            Localizations.localeOf(context).toString(),
                          ).format(_restoreDate!),
                        ),
                      const SizedBox(height: BrandSpacing.lg),
                      _ConfirmCheck(
                        value: _confirmed,
                        label: i18n.generateSeedConfirm,
                        onChanged: (v) => setState(() => _confirmed = v),
                      ),
                    ],
                  ],
                ),
              ),
              BrandButton(
                label: i18n.generateSeedContinueButton,
                loading: _isCreating,
                onPressed: _canContinue ? _continue : null,
              ),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmCheck extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _ConfirmCheck({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BrandRadii.rTile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BrandSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: value ? BrandColors.cinnamon : BrandColors.inkFaint,
              size: 22,
            ),
            const SizedBox(width: BrandSpacing.md),
            Expanded(child: Text(label, style: BrandText.body)),
          ],
        ),
      ),
    );
  }
}
