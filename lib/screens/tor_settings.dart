import 'dart:io';

import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/socks_http.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Onboarding "Tor choice" — a three-way decision (Built-in / External / No Tor)
/// made before any connection. All start unselected; Continue unlocks once a
/// mode is picked (External also requires a passing connection test).
class TorSettingsScreen extends StatelessWidget {
  const TorSettingsScreen({super.key});

  static const _modes = [TorMode.builtIn, TorMode.external, TorMode.disabled];

  Future<bool> _test(String port) async {
    try {
      final proxy = (host: InternetAddress.loopbackIPv4, port: int.tryParse(port) ?? 9050);
      final response = await makeSocksHttpRequest(
        'GET',
        'https://check.torproject.org/api/ip',
        proxy,
      ).timeout(const Duration(seconds: 15));
      final isTor = response.jsonBody != null && response.jsonBody['IsTor'] == true;
      return response.statusCode == HttpStatus.ok && isTor;
    } catch (_) {
      return false;
    }
  }

  Future<void> _continue(
    BuildContext context, {
    required int modeIndex,
    required String port,
    required bool useOrbot,
  }) async {
    await TorSettingsService.sharedInstance.save(
      torMode: _modes[modeIndex],
      socksPort: port,
      useOrbot: useOrbot,
    );
    if (!context.mounted) return;
    Navigator.pushNamed(context, '/fiat_api_setup');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return TorChoiceView(
      labels: TorChoiceLabels(
        title: i18n.torChoiceTitle,
        subtitle: i18n.torChoiceSubtitle,
        builtIn: i18n.torSettingsModeBuiltIn,
        builtInDesc: i18n.torChoiceBuiltInDesc,
        external: i18n.torSettingsModeExternal,
        externalDesc: i18n.torChoiceExternalDesc,
        noTor: i18n.torSettingsModeDisabled,
        noTorDesc: i18n.torChoiceNoTorDesc,
        socksPortLabel: i18n.torSettingsSocksPortLabel,
        orbotLabel: i18n.torChoiceOrbot,
        testButton: i18n.torSettingsTestConnectionButton,
        connected: i18n.torChoiceConnected,
        testFailed: i18n.torChoiceTestFailed,
        continueText: i18n.continueText,
      ),
      isMobile: isMobile,
      onTest: _test,
      onContinue: ({required modeIndex, required port, required useOrbot}) =>
          _continue(context, modeIndex: modeIndex, port: port, useOrbot: useOrbot),
      stepCount: 4,
      stepIndex: 0,
    );
  }
}
