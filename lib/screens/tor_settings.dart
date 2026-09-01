import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/widgets/tor_mode_selector.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Onboarding "Tor choice" — a three-way decision (Built-in / External / No Tor)
/// made before any connection. All start unselected; Continue unlocks once a
/// mode is picked (External also requires a passing connection test).
class TorSettingsScreen extends StatefulWidget {
  const TorSettingsScreen({super.key});

  @override
  State<TorSettingsScreen> createState() => _TorSettingsScreenState();
}

class _TorSettingsScreenState extends State<TorSettingsScreen> {
  TorSelection _sel = const TorSelection(
    mode: null,
    port: '9050',
    useOrbot: false,
    canCommit: false,
  );

  Future<void> _continue() async {
    await TorSettingsService.sharedInstance.save(
      torMode: _sel.mode!,
      socksPort: _sel.port,
      useOrbot: _sel.useOrbot,
    );
    if (!mounted) return;
    Navigator.pushNamed(context, '/fiat_api_setup');
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
                center: const StepDots(count: 4, index: 0),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(i18n.torChoiceTitle, style: BrandText.title),
              const SizedBox(height: BrandSpacing.sm),
              Text(i18n.torChoiceSubtitle, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.xl),
              Expanded(
                child: ListView(
                  children: [TorModeSelector(onChanged: (s) => setState(() => _sel = s))],
                ),
              ),
              BrandButton(label: i18n.continueText, onPressed: _sel.canCommit ? _continue : null),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
