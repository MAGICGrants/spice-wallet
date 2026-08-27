import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/widgets/tor_settings_form.dart';
import 'package:spice_wallet/models/language_model.dart';
import 'package:spice_wallet/models/theme_model.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/widgets/settings_group.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;
import 'package:wallet_ui/wallet_ui.dart' show ExportLogsDialog, ExportLogsLabels;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _newTxNotificationsEnabled = false;
  var _appLockEnabled = false;
  var _verboseLoggingEnabled = false;
  var _testnetCoinsEnabled = false;
  // Toggles animate only after the stored values have loaded, so they don't
  // slide from off→on when the screen first appears.
  var _animateToggles = false;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadPackageInfo();
  }

  void _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  void _loadPreferences() async {
    final newTxNotificationsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ??
        false;

    final appLockEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.appLockEnabled) ?? false;

    final verboseLoggingEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
        false;

    final testnetCoinsEnabled =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.testnetCoinsEnabled) ??
        false;

    if (!mounted) return;
    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _appLockEnabled = appLockEnabled;
      _verboseLoggingEnabled = verboseLoggingEnabled;
      _testnetCoinsEnabled = testnetCoinsEnabled;
    });
    // Enable animation a frame after the loaded values are painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateToggles = true);
    });
  }

  void _setTestnetCoinsEnabled(bool value) async {
    setState(() {
      _testnetCoinsEnabled = value;
    });

    final manager = Provider.of<WalletManager>(context, listen: false);
    await manager.setTestnetCoinsEnabled(value);

    if (mounted) {
      final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
      fiatRate.startService(walletManager: manager);
    }
  }

  void _setTxNotificationsEnabled(bool value) async {
    if (value) {
      final isAllowed = await NotificationService().promptPermission();
      if (!isAllowed) {
        setState(() => _newTxNotificationsEnabled = false);
        return;
      }
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, true);
    } else {
      await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
    }
    setState(() => _newTxNotificationsEnabled = value);
    await applyBackgroundTaskRegistration();
  }

  void _setAppLockEnabled(bool value) async {
    final i18n = AppLocalizations.of(context)!;

    if (value) {
      final result = await BiometricAuth.authenticate(reason: i18n.settingsAppLockUnlockReason);
      // Enabling app-lock is an explicit opt-in, so decline and error both report.
      if (result != BiometricAuthResult.authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.settingsAppLockUnableToAuthError)));
        }
        return;
      }
    }

    setState(() {
      _appLockEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.appLockEnabled, value);
  }

  void _setVerboseLoggingEnabled(bool value) async {
    setState(() {
      _verboseLoggingEnabled = value;
    });

    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.verboseLoggingEnabled, value);
  }

  void _exportLogs() async {
    final i18n = AppLocalizations.of(context)!;

    try {
      final logFiles = await getLogFiles();

      if (logFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.settingsExportLogsError)));
        }
        return;
      }

      if (mounted) {
        ExportLogsDialog.show(
          context,
          logFiles,
          ExportLogsLabels(
            title: i18n.settingsExportLogsLabel,
            cancel: i18n.cancel,
            exportError: i18n.settingsExportLogsError,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.settingsExportLogsError)));
      }
    }
  }

  void _showDeleteWalletDialog() {
    final i18n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: BrandColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BrandColors.errorBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, size: 20, color: BrandColors.error),
                  ),
                  const SizedBox(width: 12),
                  Text(i18n.settingsDeleteWalletButton, style: BrandText.sheetTitle),
                ],
              ),
              const SizedBox(height: 16),
              Text(i18n.settingsDeleteWalletDialogText, style: BrandText.bodyMuted),
              const SizedBox(height: 22),
              BrandButton(label: i18n.cancel, onPressed: () => Navigator.pop(dialogContext)),
              const SizedBox(height: 4),
              BrandButton.ghost(
                label: i18n.settingsDeleteWalletDialogDeleteButton,
                color: BrandColors.error,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteWallet();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteWallet() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    // Tear down background sync first so its isolate can't re-create wallet
    // files right after we delete them, and clear the settings so it doesn't
    // re-register on next launch.
    await stopForegroundSync();
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, false);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, false);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.notificationsEnabled, false);
    await applyBackgroundTaskRegistration();

    await manager.deleteAll();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (Route<dynamic> route) => false);
    }
  }

  void _showTorSettingsDialog() {
    final i18n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    Future<void> onSaved() async {
      final manager = Provider.of<WalletManager>(context, listen: false);
      manager.syncInBackground();

      final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
      fiatRate.startService(walletManager: manager);

      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        constraints: BoxConstraints.tightFor(width: dialogWidth),
        insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Text(i18n.torSettingsTitle),
        content: TorSettingsForm(saveButtonLabel: i18n.torSettingsSaveButton, onSaved: onSaved),
      ),
    );
  }

  /// Bottom-sheet single-choice picker (theme / language).
  void _showPicker(
    String title,
    List<(String value, String label)> options,
    String current,
    ValueChanged<String> onSelect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BrandColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BrandRadii.sheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Text(title, style: BrandText.sheetTitle),
            ),
            for (final (value, label) in options)
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (value != current) onSelect(value);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: BrandText.listTitle)),
                      if (value == current)
                        const Icon(Icons.check, size: 20, color: BrandColors.cinnamon),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const _languageNames = {'en': 'English', 'pt': 'Português'};

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();
    final theme = context.watch<ThemeModel>();
    final isMobile = Platform.isAndroid || Platform.isIOS;

    final themeLabel = {
      'system': i18n.settingsThemeSystem,
      'light': i18n.settingsThemeLight,
      'dark': i18n.settingsThemeDark,
    }[theme.theme];

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 2),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    onBack: () => Navigator.pop(context),
                    center: Text(
                      i18n.settingsTitle,
                      style: BrandText.appBar.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      SettingsGroup(
                        label: i18n.settingsSectionGeneral,
                        tiles: [
                          SettingsNavTile(
                            title: i18n.settingsThemeLabel,
                            value: themeLabel,
                            onTap: () => _showPicker(
                              i18n.settingsThemeLabel,
                              [
                                ('system', i18n.settingsThemeSystem),
                                ('light', i18n.settingsThemeLight),
                                ('dark', i18n.settingsThemeDark),
                              ],
                              theme.theme,
                              (v) => theme.setTheme(v),
                            ),
                          ),
                          SettingsNavTile(
                            title: i18n.settingsLanguageLabel,
                            value:
                                _languageNames[language.language] ??
                                language.language.toUpperCase(),
                            onTap: () => _showPicker(
                              i18n.settingsLanguageLabel,
                              [
                                for (final l in AppLocalizations.supportedLocales)
                                  (
                                    l.languageCode,
                                    _languageNames[l.languageCode] ?? l.languageCode.toUpperCase(),
                                  ),
                              ],
                              language.language,
                              (v) => language.setLanguage(v),
                            ),
                          ),
                          if (isMobile)
                            SettingsToggleTile(
                              title: i18n.settingsAppLockLabel,
                              value: _appLockEnabled,
                              onChanged: _setAppLockEnabled,
                              animate: _animateToggles,
                            ),
                          SettingsLinkTile(
                            title: i18n.settingsTorSettingsLabel,
                            linkLabel: i18n.settingsLwsViewKeysButton,
                            onTap: _showTorSettingsDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SettingsGroup(
                        label: i18n.settingsSectionBehaviour,
                        tiles: [
                          if (isMobile)
                            SettingsToggleTile(
                              title: i18n.settingsNotifyNewTxsLabel,
                              description: Platform.isIOS
                                  ? i18n.settingsNotifyNewTxsDescriptionIos
                                  : i18n.settingsNotifyNewTxsDescription,
                              value: _newTxNotificationsEnabled,
                              onChanged: _setTxNotificationsEnabled,
                              animate: _animateToggles,
                            ),
                          SettingsToggleTile(
                            title: i18n.settingsTestnetCoinsLabel,
                            description: i18n.settingsTestnetCoinsDescription,
                            value: _testnetCoinsEnabled,
                            onChanged: _setTestnetCoinsEnabled,
                            animate: _animateToggles,
                          ),
                          SettingsToggleTile(
                            title: i18n.settingsVerboseLoggingLabel,
                            description: Platform.isIOS
                                ? i18n.settingsVerboseLoggingDescriptionIos
                                : i18n.settingsVerboseLoggingDescription,
                            value: _verboseLoggingEnabled,
                            onChanged: _setVerboseLoggingEnabled,
                            animate: _animateToggles,
                          ),
                          // Only meaningful with logs to export.
                          if (Platform.isIOS && _verboseLoggingEnabled)
                            SettingsLinkTile(
                              title: i18n.settingsExportLogsLabel,
                              linkLabel: i18n.settingsExportLogsButton,
                              onTap: _exportLogs,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SettingsGroup(
                        label: i18n.settingsSectionAbout,
                        tiles: [
                          SettingsNavTile(
                            title: i18n.welcomeTermsLink,
                            onTap: () => Navigator.pushNamed(context, '/terms_of_service'),
                          ),
                          SettingsNavTile(
                            title: i18n.welcomePrivacyLink,
                            onTap: () => Navigator.pushNamed(context, '/privacy_policy'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SettingsGroup(
                        label: i18n.settingsSectionWallet,
                        tiles: [
                          SettingsLinkTile(
                            title: i18n.settingsDeleteWalletButton,
                            titleColor: BrandColors.error,
                            onTap: _showDeleteWalletDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Spice Wallet v$_appVersion (build $_buildNumber)',
                          style: BrandText.caption.copyWith(color: BrandColors.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
