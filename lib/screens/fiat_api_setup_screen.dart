import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart';
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/widgets/fiat_controls.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class FiatApiSetupScreen extends StatefulWidget {
  const FiatApiSetupScreen({super.key});

  @override
  State<FiatApiSetupScreen> createState() => _FiatApiSetupScreenState();
}

class _FiatApiSetupScreenState extends State<FiatApiSetupScreen> {
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
  String _fiatCurrency = 'USD';

  bool get _globalTorDisabled => TorSettingsService.sharedInstance.torMode == TorMode.disabled;

  @override
  void initState() {
    super.initState();
    // Tor-only fiat is unreachable with global Tor off; default to clearnet.
    if (_globalTorDisabled) _fiatMode = FiatApiMode.clearnet;
  }

  Future<void> _onContinue() async {
    await FiatRateModel.saveFiatApiMode(_fiatMode);
    await SharedPreferencesService.set<String>(SharedPreferencesKeys.fiatCurrency, _fiatCurrency);
    // An explicit choice here supersedes any Tor auto-disable marker.
    await SharedPreferencesService.remove(SharedPreferencesKeys.fiatAutoDisabledByTor);
    await FiatRateModel.clearPersistedRates();

    if (!mounted) return;
    // Mobile auto-generates the wallet password (the user unlocks via the
    // device), so skip the password-entry screen. Desktop prompts for one.
    if (Platform.isAndroid || Platform.isIOS) {
      context.read<WalletManager>().useGeneratedPassword();
      Navigator.pushNamed(context, '/create_wallet');
    } else {
      Navigator.pushNamed(context, '/create_wallet_password');
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
                center: const StepDots(count: 4, index: 1),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(i18n.fiatApiSetupTitle, style: BrandText.title),
              const SizedBox(height: BrandSpacing.sm),
              Text(i18n.fiatApiSetupDescription, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    if (!_globalTorDisabled) ...[
                      ModeSelectCard(
                        title: i18n.fiatApiSettingsModeTorOnly,
                        description: i18n.fiatModeTorOnlyDesc,
                        selected: _fiatMode == FiatApiMode.torOnly,
                        onTap: () => setState(() => _fiatMode = FiatApiMode.torOnly),
                      ),
                      const SizedBox(height: BrandSpacing.md),
                    ],
                    ModeSelectCard(
                      title: i18n.fiatApiSettingsModeClearnet,
                      description: i18n.fiatModeClearnetDesc,
                      selected: _fiatMode == FiatApiMode.clearnet,
                      onTap: () => setState(() => _fiatMode = FiatApiMode.clearnet),
                    ),
                    const SizedBox(height: BrandSpacing.md),
                    ModeSelectCard(
                      title: i18n.fiatApiSettingsModeDisabled,
                      description: i18n.fiatModeDisabledDesc,
                      selected: _fiatMode == FiatApiMode.disabled,
                      onTap: () => setState(() => _fiatMode = FiatApiMode.disabled),
                    ),
                    if (_fiatMode != FiatApiMode.disabled) ...[
                      const SizedBox(height: BrandSpacing.xl),
                      SectionHeader(label: i18n.fiatApiSettingsDisplayCurrencyLabel),
                      const SizedBox(height: BrandSpacing.md),
                      Wrap(
                        spacing: BrandSpacing.sm,
                        runSpacing: BrandSpacing.sm,
                        children: [
                          for (final code in supportedFiatCurrencies)
                            FiatCurrencyChip(
                              code: code,
                              symbol: currencySymbols[code] ?? '',
                              selected: _fiatCurrency == code,
                              onTap: () => setState(() => _fiatCurrency = code),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              BrandButton(label: i18n.lwsSetupContinueButton, onPressed: _onContinue),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
