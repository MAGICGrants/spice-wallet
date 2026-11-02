import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/models/language_model.dart';
import 'package:spice_wallet/models/theme_model.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Native + English display names for the supported locales.
const _languageNames = {'en': ('English', 'English'), 'pt': ('Português', 'Portuguese (Brazil)')};

/// Theme picker — Light / Dark / System, each with a mini preview swatch. The
/// shared view carries the layout; this supplies Spice's strings + warm swatch
/// colours and applies the choice immediately via [ThemeModel].
Future<void> showThemeSheet(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  final theme = context.read<ThemeModel>();
  return showThemePickerSheet(
    context,
    labels: SettingsPickerLabels(
      title: i18n.shared.settingsThemeLabel,
      subtitle: i18n.shared.settingsThemeSheetSubtitle,
      done: i18n.shared.done,
    ),
    options: [
      ThemePickerOption(
        value: 'light',
        label: i18n.shared.settingsThemeLight,
        description: i18n.settingsThemeLightDesc,
        swatch: const ThemeSwatchSpec(
          ground: Color(0xFFFFFDF6),
          barColor: Color(0xFFD8C7AC),
          accentColor: Color(0xFFC4551F),
        ),
      ),
      ThemePickerOption(
        value: 'dark',
        label: i18n.shared.settingsThemeDark,
        description: i18n.shared.settingsThemeDarkDesc,
        swatch: const ThemeSwatchSpec(
          ground: Color(0xFF241C17),
          barColor: Color(0xFF5A4A3E),
          accentColor: Color(0xFFC4551F),
        ),
      ),
      ThemePickerOption(
        value: 'system',
        label: i18n.shared.settingsThemeSystem,
        description: i18n.shared.settingsThemeSystemDesc,
        swatch: const ThemeSwatchSpec(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFDF6), Color(0xFF241C17)],
            stops: [0.5, 0.5],
          ),
          barColor: Color(0xFF9C8571),
          accentColor: Color(0xFFC4551F),
        ),
      ),
    ],
    selected: theme.theme,
    onSelect: theme.setTheme,
  );
}

/// Language picker — the app's supported locales, native + English name.
Future<void> showLanguageSheet(BuildContext context) {
  final language = context.read<LanguageModel>();
  return showLanguagePickerSheet(
    context,
    // Resolved per build from the sheet's own context rather than captured
    // here: picking a language re-localizes the app while this sheet is still
    // the thing on screen, and a snapshot would leave it in the old language --
    // looking for all the world like the setting did not take.
    labels: (context) {
      final i18n = AppLocalizations.of(context)!;
      return SettingsPickerLabels(
        title: i18n.shared.settingsLanguageLabel,
        subtitle: i18n.shared.settingsLanguageSheetSubtitle,
        done: i18n.shared.done,
      );
    },
    options: [
      for (final locale in AppLocalizations.supportedLocales)
        LanguagePickerOption(
          code: locale.languageCode,
          native: _languageNames[locale.languageCode]?.$1 ?? locale.languageCode,
          english: _languageNames[locale.languageCode]?.$2 ?? '',
        ),
    ],
    selected: language.language,
    onSelect: language.setLanguage,
  );
}
