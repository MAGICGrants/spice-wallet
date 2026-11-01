import 'dart:io';

import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/screens/desktop/tor_choice_view.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/socks_http.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Onboarding "Tor choice" — a three-way decision (Built-in / External / No Tor)
/// made before any connection. Built-in, the recommended mode, starts selected;
/// External needs a passing connection test before Continue. Only Continue
/// saves the choice, and only then does a chosen Built-in start.
class TorSettingsScreen extends StatelessWidget {
  const TorSettingsScreen({super.key});

  static const _modes = [TorMode.builtIn, TorMode.external, TorMode.disabled];

  Future<bool> _test(String port) async {
    final parsed = int.tryParse(port.trim());
    if (parsed == null || parsed < 1 || parsed > 65535) return false;
    try {
      final proxy = (host: InternetAddress.loopbackIPv4, port: parsed);
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

    final labels = TorChoiceLabels(
      title: i18n.shared.torChoiceTitle,
      subtitle: i18n.torChoiceSubtitle,
      builtIn: i18n.shared.torSettingsModeBuiltIn,
      builtInDesc: i18n.shared.torChoiceBuiltInDesc(appShortName),
      external: i18n.shared.torSettingsModeExternal,
      externalDesc: i18n.shared.torChoiceExternalDesc,
      noTor: i18n.shared.torSettingsModeDisabled,
      noTorDesc: i18n.shared.torChoiceNoTorDesc,
      socksPortLabel: i18n.shared.torSettingsSocksPortLabel,
      orbotLabel: Platform.isIOS ? i18n.shared.torUseOrbotLabelIos : i18n.shared.torUseOrbotLabel,
      testButton: i18n.shared.torSettingsTestConnectionButton,
      connected: i18n.shared.torChoiceConnected,
      testFailed: i18n.shared.torChoiceTestFailed,
      continueText: i18n.shared.continueText,
    );

    if (isDesktop) {
      return DesktopTorChoiceView(
        labels: labels,
        notePrivacy: i18n.shared.onboardingTorNotePrivacy,
        noteChangeable: i18n.shared.onboardingTorNoteChangeable,
        onTest: _test,
        onContinue: ({required modeIndex, required port, required useOrbot}) =>
            _continue(context, modeIndex: modeIndex, port: port, useOrbot: useOrbot),
        onBack: () => Navigator.pop(context),
      );
    }

    return TorChoiceView(
      labels: labels,
      isMobile: isMobile,
      onTest: _test,
      onContinue: ({required modeIndex, required port, required useOrbot}) =>
          _continue(context, modeIndex: modeIndex, port: port, useOrbot: useOrbot),
      stepCount: 4,
      stepIndex: 0,
    );
  }
}
