import 'package:flutter/material.dart';
import 'package:wallet_domain/wallet_domain.dart' show OpenAliasMode;

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/widgets/fiat_api_settings_sheet.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// OpenAlias lookups: Tor-only, clearnet or off. True when the user saved.
Future<bool?> showOpenAliasSheet(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  return showOpenAliasSettingsSheet(
    context,
    labels: OpenAliasSettingsLabels(
      title: i18n.settingsOpenAliasSettingsLabel,
      subtitle: i18n.openAliasSettingsSheetSubtitle,
      modeLabel: i18n.fiatApiSettingsModeLabel,
      torOnly: i18n.fiatApiSettingsModeTorOnly,
      torOnlyDesc: i18n.openAliasModeTorOnlyDesc,
      clearnet: i18n.fiatApiSettingsModeClearnet,
      clearnetDesc: i18n.openAliasModeClearnetDesc,
      disabled: i18n.fiatApiSettingsModeDisabled,
      disabledDesc: i18n.openAliasModeDisabledDesc,
      save: i18n.save,
      cancel: i18n.cancel,
    ),
  );
}

/// Opens whichever of the price source and OpenAlias still goes over
/// clearnet, one after the other: the home checklist step that covers both.
Future<void> showPrivateLookupSheets(BuildContext context) async {
  if (await FiatRateModel.loadFiatApiMode() == FiatApiMode.clearnet) {
    if (!context.mounted) return;
    await showFiatApiSettingsSheet(context);
  }
  if (await OpenAliasMode.load() == OpenAliasMode.clearnet) {
    if (!context.mounted) return;
    await showOpenAliasSheet(context);
  }
}
