// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeDescription =>
      'A simple, open-source, and modern self-custody wallet for Serai and the blockchain networks that Serai supports: Bitcoin, Ethereum, and Monero. You are in total control. Maintained by MAGIC Grants, a public charity.';

  @override
  String get welcomeGetStarted => 'Get Started';

  @override
  String get welcomeAgreePrefix => 'By continuing you agree to the ';

  @override
  String get welcomeTermsLink => 'Terms of Service';

  @override
  String get welcomeAgreeMiddle => ' and ';

  @override
  String get welcomePrivacyLink => 'Privacy Policy';

  @override
  String get torChoiceSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. You can enable or disable Tor for each connection individually. In general, how do you want Spice Wallet to handle Tor connections?';

  @override
  String connectionSetupDescription(String type) {
    return 'Enter the address of your $type. Only select a server you trust. Even if you use Tor, this server can learn information about you.';
  }

  @override
  String connectionSetupDescriptionLws(String type) {
    return 'Enter the address of your $type. Only select a server you trust. Even if you use Tor, this server can learn information about you. Your private view key and primary address will be shared with this server.';
  }

  @override
  String get connectionProxyPortLabel => 'HTTP Proxy Port';

  @override
  String get connectionProxyPortHint => 'Optional';

  @override
  String get fiatApiSetupDescription =>
      'Spice Wallet can automatically fetch the latest asset prices. Your balances are not sent to the server. How do you want to fetch this price data?';

  @override
  String get createWalletDescription =>
      'A single recovery phrase secures access to your wallet across all blockchain networks. Would you like to create a new wallet or restore an existing wallet?';

  @override
  String get createWalletRestoreExistingDesc => 'Any BIP39 phrase';

  @override
  String get createWalletCreateNewDesc => 'Spice Wallet generates a 15-word BIP39 recovery phrase';

  @override
  String get generateSeedSubtitleCovered =>
      'These fifteen words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.';

  @override
  String get onboardingPasswordAcknowledge =>
      'I understand that no one, including the Spice Wallet team, can recover this password.';

  @override
  String get restoreWalletSubtitle => 'Any BIP39 phrase, from Spice Wallet or another wallet.';

  @override
  String get restoreScanDescription =>
      'For some assets, Spice Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.';

  @override
  String get navigationBarHome => 'Home';

  @override
  String get historyFilterBlockchain => 'Blockchain';

  @override
  String get historyFilterAsset => 'Asset';

  @override
  String get historyFilterRecipient => 'Recipient';

  @override
  String get historyFilterRecipientAny => 'Any Blockchain';

  @override
  String get historyFilterRecipientInvalid => 'Invalid address for supported blockchains';

  @override
  String get historyTypeBridge => 'Bridge';

  @override
  String get historyTypeSwap => 'Swap';

  @override
  String get historyTypeAdd => 'Add';

  @override
  String get historyTypeRemove => 'Remove';

  @override
  String get unlockLockedTitle => 'Spice Wallet Is Locked';

  @override
  String get unlockPasswordLabel => 'Wallet Password';

  @override
  String get homeNoConnection => 'No connection';

  @override
  String get homeCoinNotConfigured => 'Not configured';

  @override
  String homeUnknownCoin(String symbol) {
    return 'Unknown coin: $symbol';
  }

  @override
  String homeAssetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assets',
      one: '1 asset',
    );
    return '$_temp0';
  }

  @override
  String get coinHomeAssetsTitle => 'Assets';

  @override
  String get coinHomeBalancesMayBeStale => 'Balances may be out of date while syncing';

  @override
  String get coinHomeAddExplorerTitle => 'Add an explorer to see history';

  @override
  String get coinHomeAddExplorerButton => 'Add Explorer';

  @override
  String get homeTotalBalanceLabel => 'Total Balance';

  @override
  String receiveQrHint(String coin) {
    return 'Scan this from the sending wallet, or send your $coin address.';
  }

  @override
  String receiveBlockchainSubtitle(String coin) {
    return '$coin blockchain';
  }

  @override
  String get sendInsufficientGasError => 'Insufficient ETH to cover the network fee.';

  @override
  String get settingsCoinConnectionSection => 'Connection';

  @override
  String get settingsCoinKeysSection => 'Keys';

  @override
  String get settingsCoinConnectionSetup => 'Connection Setup';

  @override
  String get settingsCoinExplorer => 'Explorer';

  @override
  String get settingsCoinNotConfigured => 'Not configured';

  @override
  String get syncFrequencySheetSubtitle => 'How often your wallets sync while the app is closed.';

  @override
  String get syncFrequencyContinuousDesc =>
      'Continuously sync your wallets in the background so they\'re always up to date when you open the app. Uses more battery and requires a persistent notification.';

  @override
  String get syncFrequencyPeriodicDesc =>
      'Periodically sync your wallets in the background so they\'re usually up to date when you open the app. A Monero node only syncs while charging and on WiFi.';

  @override
  String get syncFrequencyPeriodicDescIos =>
      'Periodically sync your wallets in the background so they\'re usually up to date when you open the app. A Monero node only syncs while charging.';

  @override
  String get settingsTestnetCoinsLabel => 'Testnet Coins';

  @override
  String get settingsTestnetCoinsDescription =>
      'Show testnet coins (e.g. Bitcoin Testnet) in your coin list.';

  @override
  String get settingsThemeLightDesc => 'Warm paper, the default';

  @override
  String get settingsSeedPhraseLabel => 'Recovery Phrase';

  @override
  String get revealSeedSubtitleRevealed =>
      'Securely save these. Do not share them. If you lose these words or if you share them with anyone else, you will lose your money permanently.';

  @override
  String get revealSeedBackButton => 'Back to Settings';

  @override
  String get revealSeedHideButton => 'Hide and Go Back';

  @override
  String get addressBookAddDescription => 'A name and at least one address to pay them.';

  @override
  String get addressBookEditDescription => 'A name and at least one address to pay them.';

  @override
  String get addressBookAddressesLabel => 'Addresses';

  @override
  String get addressBookAddressesNoneYet => 'none yet';

  @override
  String get addressBookAtLeastOneAddressError => 'Enter at least one address';

  @override
  String addressBookNoContactsForCoin(String coinSymbol) {
    return 'No contacts with a $coinSymbol address';
  }

  @override
  String invalidAddressForChain(String chain) {
    return 'Invalid $chain address';
  }

  @override
  String get sendFromLabel => 'From';

  @override
  String get sendIrreversibleNote =>
      'Transactions are irreversible. You can check these details again in the next step.';

  @override
  String sendAddressHint(String coin) {
    return '$coin address';
  }

  @override
  String sendPickContactSubtitle(String coin) {
    return 'Pick a contact with a $coin address.';
  }

  @override
  String sendContactNoAddress(String coin) {
    return 'No $coin address';
  }

  @override
  String get torSettingsSheetSubtitle =>
      'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. Changing this reconnects every chain.';

  @override
  String get connectionTorUnavailable =>
      'Tor isn\'t available right now. Make sure it\'s running, then try again.';

  @override
  String get explorerSetupTitle => 'Block Explorer Setup';

  @override
  String get explorerSetupDescription =>
      'Optionally set a Blockscout explorer instance to load full transaction history. Only select a server you trust. Even if you use Tor, this server can learn information about you.';

  @override
  String get explorerAddressLabel => 'Explorer Address';

  @override
  String get explorerRemovedMessage => 'Explorer removed.';
}
