import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/seed_grid.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Shows the current wallet's seed phrase (the original mnemonic it was created
/// with) behind a tap-to-reveal cover. Reached from Settings after a biometric
/// gate. Screenshots are blocked while it's open.
class RevealSeedScreen extends StatefulWidget {
  const RevealSeedScreen({super.key});

  @override
  State<RevealSeedScreen> createState() => _RevealSeedScreenState();
}

class _RevealSeedScreenState extends State<RevealSeedScreen> with SecureScreenMixin {
  List<String> _words = [];
  DateTime? _restoreDate;
  bool _loaded = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await Provider.of<WalletManager>(context, listen: false).loadStoredSeed();
    if (!mounted) return;
    setState(() {
      if (stored != null) {
        _words = stored.seed.mnemonic.split(' ');
        final from = stored.from;
        _restoreDate = from is RestoreFromDate ? from.date : null;
      }
      _loaded = true;
    });
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
                onBack: () => Navigator.pop(context),
                center: Text(
                  i18n.settingsSeedPhraseLabel,
                  style: BrandText.appBar.copyWith(fontSize: 16),
                ),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(i18n.generateSeedTitleCovered, style: BrandText.title),
              const SizedBox(height: BrandSpacing.sm),
              Text(
                _revealed ? i18n.revealSeedSubtitleRevealed : i18n.revealSeedSubtitleCovered,
                style: BrandText.bodyMuted,
              ),
              const SizedBox(height: BrandSpacing.xl),
              Expanded(
                child: !_loaded
                    ? const SizedBox.shrink()
                    : ListView(
                        children: [
                          SeedGrid(
                            words: _words,
                            revealed: _revealed,
                            revealLabel: i18n.generateSeedReveal,
                            screenshotNote: i18n.generateSeedScreenshotNote,
                            onReveal: () => setState(() => _revealed = true),
                          ),
                          if (_revealed && _restoreDate != null) ...[
                            const SizedBox(height: BrandSpacing.lg),
                            SeedBirthdayCard(
                              label: i18n.generateSeedBirthdayLabel,
                              reason: i18n.generateSeedBirthdayReason,
                              value: DateFormat.yMMM(
                                Localizations.localeOf(context).toString(),
                              ).format(_restoreDate!),
                            ),
                          ],
                        ],
                      ),
              ),
              BrandButton.secondary(
                label: _revealed ? i18n.revealSeedHideButton : i18n.revealSeedBackButton,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
