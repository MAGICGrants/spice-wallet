import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/widgets/fiat_api_settings_sheet.dart';
import 'package:spice_wallet/widgets/tor_settings_sheet.dart';
import 'package:spice_wallet/models/language_model.dart';
import 'package:spice_wallet/models/theme_model.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/widgets/settings_group.dart';
import 'package:spice_wallet/widgets/theme_language_sheets.dart';
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
  FiatApiMode _fiatMode = FiatApiMode.torOnly;
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

    final fiatMode = await FiatRateModel.loadFiatApiMode();

    if (!mounted) return;
    setState(() {
      _newTxNotificationsEnabled = newTxNotificationsEnabled;
      _appLockEnabled = appLockEnabled;
      _verboseLoggingEnabled = verboseLoggingEnabled;
      _testnetCoinsEnabled = testnetCoinsEnabled;
      _fiatMode = fiatMode;
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
                    decoration: BoxDecoration(color: BrandColors.errorBg, shape: BoxShape.circle),
                    child: Icon(Icons.delete_outline, size: 20, color: BrandColors.error),
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

  void _showFiatApiSettings() async {
    final changed = await showFiatApiSettingsSheet(context);
    if (changed == true) {
      final mode = await FiatRateModel.loadFiatApiMode();
      if (mounted) setState(() => _fiatMode = mode);
    }
  }

  String _fiatModeLabel(AppLocalizations i18n) => switch (_fiatMode) {
    FiatApiMode.torOnly => i18n.fiatApiSettingsModeTorOnly,
    FiatApiMode.clearnet => i18n.fiatApiSettingsModeClearnet,
    FiatApiMode.disabled => i18n.fiatApiSettingsModeDisabled,
  };

  String _torModeLabel(AppLocalizations i18n) =>
      switch (TorSettingsService.sharedInstance.torMode) {
        TorMode.builtIn => i18n.torSettingsModeBuiltIn,
        TorMode.external => i18n.torSettingsModeExternal,
        TorMode.disabled => i18n.torSettingsModeDisabled,
      };

  void _showTorSettings() async {
    final changed = await showTorSettingsSheet(context);
    // Disabling Tor can auto-disable a Tor-only fiat mode, so refresh the row.
    if (changed == true) {
      final mode = await FiatRateModel.loadFiatApiMode();
      if (mounted) setState(() => _fiatMode = mode);
    }
  }

  /// Bottom-sheet single-choice picker (theme / language).
  void _revealSeed() async {
    final i18n = AppLocalizations.of(context)!;
    // Gate the seed behind a device auth even though the app is already unlocked.
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await BiometricAuth.authenticate(reason: i18n.revealSeedAuthReason);
      if (result != BiometricAuthResult.authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.settingsAppLockUnableToAuthError)));
        }
        return;
      }
    }
    if (mounted) Navigator.pushNamed(context, '/reveal_seed');
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

    final fiatCode = context.watch<FiatRateModel>().fiatCode;
    final fiatSubtitle = _fiatMode == FiatApiMode.disabled
        ? _fiatModeLabel(i18n)
        : '${_fiatModeLabel(i18n)} · $fiatCode';

    return Scaffold(
      backgroundColor: BrandColors.paper,
      bottomNavigationBar: const WalletNavigationBar(selectedIndex: 3),
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
                            onTap: () => showThemeSheet(context),
                          ),
                          SettingsNavTile(
                            title: i18n.settingsLanguageLabel,
                            value:
                                _languageNames[language.language] ??
                                language.language.toUpperCase(),
                            onTap: () => showLanguageSheet(context),
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
                            subtitle: _torModeLabel(i18n),
                            linkLabel: i18n.settingsLwsViewKeysButton,
                            onTap: _showTorSettings,
                          ),
                          SettingsLinkTile(
                            title: i18n.settingsFiatApiSettingsLabel,
                            subtitle: fiatSubtitle,
                            linkLabel: i18n.settingsLwsViewKeysButton,
                            onTap: _showFiatApiSettings,
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
                            title: i18n.settingsSeedPhraseLabel,
                            linkLabel: i18n.settingsLwsViewKeysButton,
                            onTap: _revealSeed,
                          ),
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
