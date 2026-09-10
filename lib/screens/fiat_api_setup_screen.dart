import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart';
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
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

    return FiatSetupView(
      labels: FiatSetupLabels(
        title: i18n.fiatApiSetupTitle,
        subtitle: i18n.fiatApiSetupDescription,
        torOnly: i18n.fiatApiSettingsModeTorOnly,
        torOnlyDesc: i18n.fiatModeTorOnlyDesc,
        clearnet: i18n.fiatApiSettingsModeClearnet,
        clearnetDesc: i18n.fiatModeClearnetDesc,
        disabled: i18n.fiatApiSettingsModeDisabled,
        disabledDesc: i18n.fiatModeDisabledDesc,
        currencyLabel: i18n.fiatApiSettingsDisplayCurrencyLabel,
        continueText: i18n.lwsSetupContinueButton,
      ),
      currencies: [
        for (final code in supportedFiatCurrencies)
          FiatCurrencyOption(code: code, symbol: currencySymbols[code] ?? ''),
      ],
      modeIndex: _fiatMode.index,
      currency: _fiatCurrency,
      offerTorOnly: !_globalTorDisabled,
      onModeChanged: (i) => setState(() => _fiatMode = FiatApiMode.values[i]),
      onCurrencyChanged: (code) => setState(() => _fiatCurrency = code),
      onContinue: _onContinue,
      stepCount: 4,
      stepIndex: 1,
    );
  }
}
