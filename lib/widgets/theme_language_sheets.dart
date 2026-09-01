import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/language_model.dart';
import 'package:spice_wallet/models/theme_model.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Theme picker — Light / Dark / System, each with a mini preview swatch.
/// Applies immediately (the app rebuilds); Done just closes.
Future<void> showThemeSheet(BuildContext context) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ThemeSheet(),
  );
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeModel>();

    final options = [
      ('light', i18n.settingsThemeLight, i18n.settingsThemeLightDesc, _ThemeSwatch.light),
      ('dark', i18n.settingsThemeDark, i18n.settingsThemeDarkDesc, _ThemeSwatch.dark),
      ('system', i18n.settingsThemeSystem, i18n.settingsThemeSystemDesc, _ThemeSwatch.system),
    ];

    return _PickerSheet(
      icon: Icons.wb_sunny_outlined,
      title: i18n.settingsThemeLabel,
      subtitle: i18n.settingsThemeSheetSubtitle,
      children: [
        for (final (value, label, desc, swatch) in options) ...[
          ModeSelectCard(
            title: label,
            description: desc,
            selected: theme.theme == value,
            leading: swatch,
            onTap: () => theme.setTheme(value),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// The 38×38 rounded preview tile — ground colour + two bars hinting at text.
class _ThemeSwatch extends StatelessWidget {
  final Gradient? gradient;
  final Color? ground;
  final Color barColor;

  const _ThemeSwatch({this.gradient, this.ground, required this.barColor});

  static const light = _ThemeSwatch(ground: Color(0xFFFFFDF6), barColor: Color(0xFFD8C7AC));
  static const dark = _ThemeSwatch(ground: Color(0xFF241C17), barColor: Color(0xFF5A4A3E));
  static const system = _ThemeSwatch(
    gradient: LinearGradient(colors: [Color(0xFFFFFDF6), Color(0xFF241C17)], stops: [0.5, 0.5]),
    barColor: Color(0xFF9C8571),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ground,
        gradient: gradient,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: BrandColors.borderStrong),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(color: barColor, borderRadius: _r),
          ),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: 0.6,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(color: Color(0xFFC4551F), borderRadius: _r),
            ),
          ),
        ],
      ),
    );
  }

  static const _r = BorderRadius.all(Radius.circular(2));
}

/// Language picker — the app's supported locales, native name + English name.
/// No search (only a handful of languages). Applies immediately.
Future<void> showLanguageSheet(BuildContext context) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LanguageSheet(),
  );
}

/// Native + English display names for the supported locales.
const _languageNames = {'en': ('English', 'English'), 'pt': ('Português', 'Portuguese (Brazil)')};

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();

    return _PickerSheet(
      icon: Icons.language,
      title: i18n.settingsLanguageLabel,
      subtitle: i18n.settingsLanguageSheetSubtitle,
      children: [
        for (final locale in AppLocalizations.supportedLocales)
          _LanguageRow(
            native: _languageNames[locale.languageCode]?.$1 ?? locale.languageCode,
            english: _languageNames[locale.languageCode]?.$2 ?? '',
            selected: language.language == locale.languageCode,
            onTap: () => language.setLanguage(locale.languageCode),
          ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String native;
  final String english;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageRow({
    required this.native,
    required this.english,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandColors.surfaceTinted)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    native,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(english, style: BrandText.caption.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 13),
            RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// Shared chrome for the theme/language sheets: handle, warm icon tile + title +
/// subtitle, a scrollable body, and a Done button.
class _PickerSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _PickerSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SheetIcon(
                          icon: icon,
                          bg: BrandColors.surfaceAccent,
                          color: BrandColors.cinnamon,
                        ),
                        const SizedBox(width: 11),
                        Expanded(child: Text(title, style: BrandText.sheetTitle)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(subtitle, style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: BrandButton(label: i18n.done, onPressed: () => Navigator.of(context).pop()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
