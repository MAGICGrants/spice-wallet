import 'package:wallet_infra/wallet_infra.dart' show SettingsKeys;

// The prefs service itself lives in wallet-core (injectable, test-seamed). Kept
// under the same import path so call sites are unchanged.
export 'package:wallet_infra/wallet_infra.dart' show SharedPreferencesService;

/// Spice's preference keys. The common ones are the shared [SettingsKeys] so the
/// key strings can't drift from skylight; only spice-specific keys are new here.
class SharedPreferencesKeys {
  static const String language = SettingsKeys.language;
  static const String fiatCurrency = SettingsKeys.fiatCurrency;
  static const String fiatApiMode = SettingsKeys.fiatApiMode;
  static const String fiatRate = SettingsKeys.fiatRate;
  static const String fiatAutoDisabledByTor = SettingsKeys.fiatAutoDisabledByTor;
  static const String theme = SettingsKeys.theme;
  static const String notificationsEnabled = SettingsKeys.notificationsEnabled;
  static const String appLockEnabled = SettingsKeys.appLockEnabled;
  static const String verboseLoggingEnabled = SettingsKeys.verboseLoggingEnabled;
  static const String contacts = SettingsKeys.contacts;
  static const String torMode = SettingsKeys.torMode;
  static const String torSocksPort = SettingsKeys.torSocksPort;
  static const String torUseOrbot = SettingsKeys.torUseOrbot;
  static const String backgroundSyncEnabled = SettingsKeys.backgroundSyncEnabled;
  static const String backgroundSyncIntervalMinutes = SettingsKeys.backgroundSyncIntervalMinutes;
  static const String foregroundSyncEnabled = SettingsKeys.foregroundSyncEnabled;

  // Spice-specific (multicoin):
  static const String pendingOutgoingTxs = 'pendingOutgoingTxs';
  static const String testnetCoinsEnabled = 'testnetCoinsEnabled';
}
