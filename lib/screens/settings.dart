import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/platform.dart';
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
import 'package:spice_wallet/widgets/theme_language_sheets.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:spice_wallet/screens/reveal_seed.dart';
import 'package:spice_wallet/widgets/wallet_navigation_bar.dart';
import 'package:wallet_infra/wallet_infra.dart' show BiometricAuth, BiometricAuthResult;

/// Desktop: settings as a wide centered modal (opened from the sidebar); mobile
/// keeps the full-screen tab.
Future<void> showSettingsSheet(BuildContext context) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    maxWidth: 720,
    builder: (ctx) => ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 640),
      child: const SettingsScreen(asModal: true),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  /// Content-only render for the desktop settings modal (2-column, no shell).
  final bool asModal;

  const SettingsScreen({super.key, this.asModal = false});

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
          showBrandToast(context, i18n.settingsAppLockUnableToAuthError);
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
          showBrandToast(context, i18n.settingsExportLogsError);
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
            exportError: i18n.settingsExportLogsFailed,
          ),
        );
      }
    } catch (e) {
      // Not "no logs found": the listing itself failed, which is a different
      // thing to tell the user than an empty list.
      if (mounted) {
        showBrandToast(context, i18n.settingsExportLogsFailed);
      }
    }
  }

  void _showDeleteWalletDialog() {
    final i18n = AppLocalizations.of(context)!;
    showConfirmSheet(
      context: context,
      icon: Icons.delete_outline,
      iconBg: BrandColors.errorBg,
      iconColor: BrandColors.error,
      title: i18n.settingsDeleteWalletButton,
      body: i18n.settingsDeleteWalletDialogText,
      confirmLabel: i18n.settingsDeleteWalletDialogDeleteButton,
      cancelLabel: i18n.cancel,
      onConfirm: _deleteWallet,
    );
  }

  Future<void> _deleteWallet() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    // Tears down background sync *before* the files go, so the foreground
    // service's isolate can't keep syncing (and rewriting) a deleted wallet.
    // The order lives in wallet-core so both apps cannot drift on it.
    await stopSyncAndDeleteWallets(manager);
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

  /// Opens the seed screen, behind a device auth on mobile.
  ///
  /// Only when app lock is on: the prompt re-checks who is holding an already
  /// unlocked phone, and with app lock off the user has said this app does not
  /// do that.
  void _revealSeed() async {
    final i18n = AppLocalizations.of(context)!;
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await BiometricAuth.authenticateIfAppLockEnabled(
        reason: i18n.revealSeedAuthReason,
      );
      if (result != BiometricAuthResult.authenticated) {
        if (mounted) {
          showBrandToast(context, i18n.settingsAppLockUnableToAuthError);
        }
        return;
      }
    }
    if (!mounted) return;
    if (isDesktop) {
      await showRevealSeedSheet(context);
    } else {
      Navigator.pushNamed(context, '/reveal_seed');
    }
  }

  static const _languageNames = {'en': 'English', 'pt': 'Português'};

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final language = context.watch<LanguageModel>();
    final theme = context.watch<ThemeModel>();

    final themeLabel = {
      'system': i18n.settingsThemeSystem,
      'light': i18n.settingsThemeLight,
      'dark': i18n.settingsThemeDark,
    }[theme.theme];

    final fiatCode = context.watch<FiatRateModel>().fiatCode;
    final fiatSubtitle = _fiatMode == FiatApiMode.disabled
        ? _fiatModeLabel(i18n)
        : '${_fiatModeLabel(i18n)} · $fiatCode';

    final groups = <Widget>[
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
            value: _languageNames[language.language] ?? language.language.toUpperCase(),
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
      SettingsGroup(
        label: i18n.settingsSectionAbout,
        tiles: [
          SettingsNavTile(
            title: i18n.welcomeTermsLink,
            onTap: () => Navigator.pushNamed(context, '/terms_of_service', arguments: true),
          ),
          SettingsNavTile(
            title: i18n.welcomePrivacyLink,
            onTap: () => Navigator.pushNamed(context, '/privacy_policy', arguments: true),
          ),
        ],
      ),
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
    ];

    final versionFooter = Center(
      child: Text(
        'Spice Wallet v$_appVersion (build $_buildNumber)',
        style: BrandText.caption.copyWith(color: BrandColors.inkFaint),
      ),
    );

    if (widget.asModal) return _modalBody(i18n, groups, versionFooter);

    final tiles = <Widget>[
      for (var i = 0; i < groups.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        groups[i],
      ],
      const SizedBox(height: 20),
      versionFooter,
    ];

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
                    children: tiles,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The desktop settings modal: a header + a two-column body of the groups that
  /// wraps to one column when the modal is narrow (design: 720px, 2 columns).
  Widget _modalBody(AppLocalizations i18n, List<Widget> groups, Widget versionFooter) {
    final hpad = isDesktopModal ? 0.0 : 20.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hpad, 2, isDesktopModal ? 34 : hpad, 18),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BrandColors.orangeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, size: 19, color: BrandColors.primary),
              ),
              const SizedBox(width: 13),
              Text(
                i18n.settingsTitle,
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hpad, 0, hpad, 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 20.0;
                Widget stack(List<Widget> gs, {Widget? tail}) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < gs.length; i++) ...[
                      if (i > 0) const SizedBox(height: gap),
                      gs[i],
                    ],
                    if (tail != null) ...[const SizedBox(height: gap), tail],
                  ],
                );
                // Two columns when there's room; split the groups down the middle.
                if (constraints.maxWidth >= 520) {
                  final half = (groups.length / 2).ceil();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: stack(groups.sublist(0, half))),
                      const SizedBox(width: 22),
                      Expanded(child: stack(groups.sublist(half), tail: versionFooter)),
                    ],
                  );
                }
                return stack(groups, tail: versionFooter);
              },
            ),
          ),
        ),
      ],
    );
  }
}
