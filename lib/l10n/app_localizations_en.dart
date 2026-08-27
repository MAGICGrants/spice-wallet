// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get continueText => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get unknownError => 'Unknown error.';

  @override
  String get warning => 'Warning';

  @override
  String get amount => 'Amount';

  @override
  String get networkFee => 'Network Fee';

  @override
  String get address => 'Address';

  @override
  String get pending => 'Pending';

  @override
  String get copy => 'Copy';

  @override
  String get addressCopied => 'Address copied to clipboard';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get fieldEmptyError => 'This field cannot be empty.';

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get welcomeDescription =>
      'A self-custody wallet for Monero, Bitcoin, Ethereum and DAI. Your keys never leave this device.';

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
  String get torChoiceTitle => 'How should Spice Wallet reach the network?';

  @override
  String get torChoiceSubtitle =>
      'Nothing connects until you choose. Tor hides your IP address from the servers Spice Wallet talks to.';

  @override
  String get torChoiceBuiltInDesc => 'Bundled with Spice Wallet · recommended';

  @override
  String get torChoiceExternalDesc => 'Orbot, or a daemon you run yourself';

  @override
  String get torChoiceNoTorDesc => 'Servers you connect to can see your IP address';

  @override
  String get torChoiceOrbot => 'Use Orbot — port is fixed at 9050';

  @override
  String get torChoiceTestFailed => 'Test failed';

  @override
  String get torChoiceConnected => 'Connected to Tor';

  @override
  String get torChoiceRecommended => 'Recommended';

  @override
  String get lwsSetupTitle => 'LWS Setup';

  @override
  String get lwsSetupDescription => 'Enter the address of your Monero light-wallet server (LWS).';

  @override
  String get connectionSetupTitle => 'Connection Setup';

  @override
  String connectionSetupDescription(String type) {
    return 'Enter the address of your $type.';
  }

  @override
  String get connectionTypeLws => 'Light Wallet Server';

  @override
  String get connectionTypeNode => 'Monero Node';

  @override
  String get lwsSetupAddressHint => 'e.g. 192.168.1.1:18090 or example.com:18090';

  @override
  String get lwsSetupProxyPortLabel => 'HTTP Proxy Port (optional)';

  @override
  String get lwsSetupProxyPortHint => 'e.g. 4444 for I2P';

  @override
  String get lwsSetupUseTorLabel => 'Use Tor';

  @override
  String get lwsSetupUseSslLabel => 'Use SSL';

  @override
  String get lwsSetupTestConnectionButton => 'Test Connection';

  @override
  String get connectionProxyPortLabel => 'HTTP Proxy Port';

  @override
  String get connectionProxyPortHint => 'Optional';

  @override
  String get connectionTestingTitle => 'Testing connection';

  @override
  String get connectionTestingDetail => 'Checking whether the server answers.';

  @override
  String get connectionTestStop => 'Stop';

  @override
  String get connectionResultWorksTitle => 'Connection works';

  @override
  String get connectionResultWorksDetail => 'The server responded successfully.';

  @override
  String get connectionReachedOverTor => 'Reached over Tor';

  @override
  String get connectionReachedViaProxy => 'Reached through your proxy';

  @override
  String get connectionReachedDirect => 'Reached directly';

  @override
  String get connectionResultFailedTitle => 'Could not reach this server';

  @override
  String get connectionResultFailedDetail =>
      'Nothing answered. Check the address and port, and whether the server accepts your connection.';

  @override
  String get connectionTestAgain => 'Test again';

  @override
  String get lwsSetupStartingTor => 'Starting Tor...';

  @override
  String get lwsSetupContinueButton => 'Continue';

  @override
  String get fiatApiSetupTitle => 'Fiat Display Setup';

  @override
  String get fiatApiSetupDescription =>
      'An optional reference price beside your balances. Fetching it means talking to a rate server, so how that happens is up to you.';

  @override
  String get fiatApiSettingsModeLabel => 'Mode';

  @override
  String get fiatApiSettingsModeTorOnly => 'Tor-Only';

  @override
  String get fiatApiSettingsModeClearnet => 'Clearnet-Only';

  @override
  String get fiatApiSettingsModeDisabled => 'Disabled';

  @override
  String get fiatModeTorOnlyDesc => 'Rates fetched over Tor · recommended';

  @override
  String get fiatModeClearnetDesc => 'Not private — the rate server sees your IP address';

  @override
  String get fiatModeDisabledDesc => 'No rates fetched, balances shown in crypto only';

  @override
  String get fiatApiSettingsDisplayCurrencyLabel => 'Display Currency';

  @override
  String get createWalletTitle => 'Start fresh, or restore?';

  @override
  String get createWalletDescription =>
      'One seed phrase covers all four chains. If you already have one, you can restore it now.';

  @override
  String get createWalletRestoreExistingButton => 'Restore from a seed';

  @override
  String get createWalletRestoreExistingDesc => 'Any BIP39 phrase';

  @override
  String get createWalletCreateNewButton => 'Create a new wallet';

  @override
  String get createWalletCreateNewDesc => 'Spice Wallet generates a 15-word BIP39 seed';

  @override
  String get generateSeedTitle => 'Write these down, in order';

  @override
  String get generateSeedTitleCovered => 'Your seed phrase';

  @override
  String get generateSeedSubtitleCovered =>
      'These fifteen words, in this order, are the wallet. Write them on paper — not in a photo or a notes app.';

  @override
  String get generateSeedSubtitleRevealed => 'Anyone with these words has your funds.';

  @override
  String get generateSeedScreenshotNote =>
      'Screenshots are blocked on this screen. Make sure nobody is looking over your shoulder.';

  @override
  String get generateSeedReveal => 'Tap to reveal';

  @override
  String get generateSeedBirthdayLabel => 'Wallet birthday';

  @override
  String get generateSeedBirthdayReason => 'Where a future restore starts scanning';

  @override
  String get generateSeedConfirm =>
      'I have written down all 15 words and stored them somewhere only I can reach.';

  @override
  String get generateSeedContinueButton => 'Continue';

  @override
  String get lwsDetailsTitle => 'Wallet Details';

  @override
  String get lwsDetailsDescription =>
      'You can use these details to whitelist this wallet on the light wallet server if needed.';

  @override
  String get lwsDetailsPrimaryAddressLabel => 'Primary Address';

  @override
  String get lwsDetailsSecretViewKeyLabel => 'Secret View Key';

  @override
  String get lwsDetailsRestoreHeightLabel => 'Restore Height';

  @override
  String get restoreWalletTitle => 'Restore wallet';

  @override
  String get restoreWalletSubtitle => 'Any BIP39 phrase, from Spice Wallet or another wallet.';

  @override
  String get restoreWalletSeedLength => 'Seed length';

  @override
  String get restoreWalletPaste => 'Paste';

  @override
  String get restoreWalletScanFrom => 'Scan from';

  @override
  String get restoreWalletScanFromReason => 'Earlier is slower but never misses funds.';

  @override
  String get restoreWalletNotSet => 'Not set';

  @override
  String get restoreScanTitle => 'When did this seed first hold funds?';

  @override
  String get restoreScanDescription =>
      'For some assets, Spice Wallet only scans forward from this point. Guess early — a wrong-but-earlier answer costs sync time, a wrong-but-later one hides transactions.';

  @override
  String get restoreScanPickMonth => 'Pick a month';

  @override
  String get restoreScanNotSure => 'I\'m not sure';

  @override
  String get restoreScanNotSureDesc =>
      'Scan everything. Slower this first setup but not any slower later. Always complete.';

  @override
  String get restoreScanFromStart => 'Genesis';

  @override
  String get restoreScanDone => 'Done';

  @override
  String restoreWalletBadWord(int position) {
    return 'Word $position isn\'t a BIP39 word.';
  }

  @override
  String restoreWalletDidYouMean(String word) {
    return 'Did you mean $word?';
  }

  @override
  String get restoreWalletChecksumError =>
      'This isn\'t a valid seed phrase — check the words and their order.';

  @override
  String get restoreWalletDescription =>
      'Enter your 15-word seed phrase to restore every coin in this wallet.';

  @override
  String get restoreWalletSeedLabel => 'Seed';

  @override
  String get restoreWalletRestoreHeightLabel => 'Restore Height (optional)';

  @override
  String get restoreWalletRestoreDateLabel => 'Restore from date';

  @override
  String get restoreWalletRestoreButton => 'Restore';

  @override
  String get restoreWalletInvalidMnemonic => 'Invalid seed.';

  @override
  String get navigationBarWallet => 'Wallet';

  @override
  String get navigationBarHome => 'Home';

  @override
  String get navigationBarSettings => 'Settings';

  @override
  String get unlockButton => 'Unlock';

  @override
  String get unlockReason => 'Unlock wallet';

  @override
  String get unlockUnableToAuthError => 'Unable to authenticate.';

  @override
  String get unlockTitle => 'Unlock Wallet';

  @override
  String get unlockLockedTitle => 'Spice Wallet is locked';

  @override
  String get unlockWithFaceId => 'Unlock with Face ID';

  @override
  String get unlockWithTouchId => 'Unlock with Touch ID';

  @override
  String get unlockDescription => 'Enter your wallet password to unlock';

  @override
  String get unlockPasswordLabel => 'Password';

  @override
  String get unlockPasswordHint => 'Enter your password';

  @override
  String get unlockIncorrectPasswordError => 'Incorrect password. Please try again.';

  @override
  String get homeConnecting => 'Connecting';

  @override
  String get homeSyncing => 'Syncing';

  @override
  String get homeSynced => 'Synced';

  @override
  String get homeNoConnection => 'No connection';

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
  String get coinHomeActivityTitle => 'Activity';

  @override
  String get coinHomeSwap => 'Swap';

  @override
  String get coinHomeSwapComingSoon => 'Swap is coming soon.';

  @override
  String get coinHomeReceived => 'Received';

  @override
  String get coinHomeSent => 'Sent';

  @override
  String get coinHomeServerConnection => 'Server connection';

  @override
  String get coinHomeViewKeys => 'View keys';

  @override
  String get coinHomeRouteTor => 'Tor';

  @override
  String get coinHomeRouteProxy => 'Proxy';

  @override
  String get coinHomeRouteDirect => 'Direct';

  @override
  String get coinHomeAddExplorerTitle => 'Add an explorer to see history';

  @override
  String get coinHomeAddExplorerButton => 'Add explorer';

  @override
  String get homeFiatSource => 'Kraken over Tor';

  @override
  String get homeHeight => 'Height';

  @override
  String get homeReceive => 'Receive';

  @override
  String get homeSend => 'Send';

  @override
  String get homeBalanceLocked => 'locked';

  @override
  String get homeTransactionsTitle => 'Transactions';

  @override
  String get homeOutgoingTxSemanticLabel => 'Outgoing Transaction';

  @override
  String get homeIncomingTxSemanticLabel => 'Incoming Transaction';

  @override
  String get homeTransactionConfirmed => 'Confirmed';

  @override
  String get homeNoTransactions => 'No transactions';

  @override
  String get homeFiatApiError => 'Error connecting to fiat API';

  @override
  String get homeTotalBalanceLabel => 'Total Balance';

  @override
  String get homeYourCoinsTitle => 'Your Coins';

  @override
  String get homeCoinNotConfigured => 'Not configured';

  @override
  String get homeCoinSetUp => 'Set up';

  @override
  String get homeConnectionErrorTooltip => 'Couldn\'t connect to the server';

  @override
  String get coinHomeServerConnectionButton => 'Server connection';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receivePrimaryAddressWarn =>
      'Warning: Unless you know what you\'re doing, please consider using subaddresses for better privacy.';

  @override
  String get receiveShareButton => 'Share';

  @override
  String get receiveShowSubaddressButton => 'Show Subaddress';

  @override
  String get receiveShowPrimaryAddressButton => 'Show Primary Address';

  @override
  String get receiveServerNoSubaddressesWarn =>
      'Warning: This server does not support subaddresses. For better privacy, consider using a server that supports them. You are receiving to your primary address.';

  @override
  String get receiveMaxSubaddressesReachedWarn =>
      'You have reached the maximum number of subaddresses supported by this server. This is a used address.';

  @override
  String get receiveSubaddressTab => 'Subaddress';

  @override
  String get receivePrimaryTab => 'Primary address';

  @override
  String get receiveCopyAddress => 'Copy address';

  @override
  String receiveAddressHeading(String coin) {
    return 'Your $coin address';
  }

  @override
  String receiveBlockchainSubtitle(String coin) {
    return '$coin blockchain';
  }

  @override
  String get sendTitle => 'Send';

  @override
  String get sendSendButton => 'Send';

  @override
  String get sendTransactionSuccessfullySent => 'Transaction successfully sent!';

  @override
  String get sendOpenAliasResolveError => 'Invalid OpenAlias.';

  @override
  String get sendContactsButton => 'Contacts';

  @override
  String get sendInvalidAddressError => 'Invalid address.';

  @override
  String get sendInsufficientBalanceError => 'Insufficient balance.';

  @override
  String get sendInsufficientBalanceToCoverFeeError =>
      'Insufficient balance to cover the network fee.';

  @override
  String get sendInsufficientGasError => 'Insufficient ETH to cover the network fee.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionBehaviour => 'Behaviour';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionWallet => 'Wallet';

  @override
  String get settingsCoinConnectionSection => 'Connection';

  @override
  String get settingsCoinKeysSection => 'Keys';

  @override
  String get settingsCoinConnectionSetup => 'Connection setup';

  @override
  String get settingsCoinExplorer => 'Explorer';

  @override
  String get settingsCoinNotConfigured => 'Not configured';

  @override
  String homeBlocksRemaining(String count) {
    return '$count blocks left';
  }

  @override
  String get settingsNotifyNewTxsLabel => 'Notify New Transactions';

  @override
  String get settingsNotifyNewTxsDescription =>
      'Shows a notification when you receive a transaction. When connected to a Monero node, Background Sync must also be enabled.';

  @override
  String get settingsNotifyNewTxsDescriptionIos =>
      'Shows a notification when you receive a transaction.';

  @override
  String get settingsBackgroundSyncLabel => 'Background Sync';

  @override
  String get settingsBackgroundSyncDescription =>
      'Periodically sync your wallets in the background so they\'re up to date when you open the app.';

  @override
  String get settingsBackgroundSyncIntervalLabel => 'Sync Interval';

  @override
  String get settingsForegroundSyncLabel => 'Continuous Sync';

  @override
  String get settingsForegroundSyncDescription =>
      'Keep your wallets syncing continuously while the app runs in the background, with a persistent notification. Uses more battery.';

  @override
  String get settingsAppLockLabel => 'App Lock';

  @override
  String get settingsAppLockUnlockReason => 'Unlock wallet';

  @override
  String get settingsAppLockUnableToAuthError =>
      'Unable to authenticate. Make sure you have device unlock set up.';

  @override
  String get settingsVerboseLoggingLabel => 'Enable Logging to File';

  @override
  String get settingsTestnetCoinsLabel => 'Testnet Coins';

  @override
  String get settingsTestnetCoinsDescription =>
      'Show testnet coins (e.g. Bitcoin Testnet) in your coin list.';

  @override
  String get settingsVerboseLoggingDescription =>
      'Logs wallet operations to a text file in the app\'s data folder for debugging purposes.';

  @override
  String get settingsVerboseLoggingDescriptionIos =>
      'Logs wallet operations and allows the logs to be exported to a text file.';

  @override
  String get settingsExportLogsLabel => 'Export Logs';

  @override
  String get settingsExportLogsButton => 'Export';

  @override
  String get settingsExportLogsError => 'No logs found to export.';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsFiatApiSettingsLabel => 'Fiat API Settings';

  @override
  String get settingsLwsViewKeysLabel => 'LWS View Keys';

  @override
  String get settingsLwsViewKeysButton => 'View';

  @override
  String get settingsSecretKeysLabel => 'Secret Restore Keys';

  @override
  String get settingsSecretKeysButton => 'View';

  @override
  String get settingsViewLwsKeysDialogText =>
      'Only share this information with your light-wallet server. These keys allow the holder to permanently see all transactions related to your wallets. Sharing these with an untrusted person will significantly harm your privacy.';

  @override
  String get settingsViewLwsKeysDialogRevealButton => 'Reveal';

  @override
  String get settingsViewSecretKeysDialogText =>
      'Do not share these keys with anyone, including anyone claiming to be support. If you receive a request to provide these, you are being scammed. If you provide this information to another person, you will lose your money and it cannot be recovered.';

  @override
  String get settingsViewSecretKeysDialogRevealButton => 'Reveal';

  @override
  String get settingsDeleteWalletButton => 'Delete Wallet';

  @override
  String get settingsDeleteWalletDialogText =>
      'Are you sure you want to delete your wallet? You will lose access to your funds unless you have backed up your seed phrase.';

  @override
  String get settingsDeleteWalletDialogDeleteButton => 'Delete';

  @override
  String get txDetailsTitle => 'Transaction Details';

  @override
  String get txDetailsCopyHint => 'tap any value to copy';

  @override
  String get txDetailsHashLabel => 'Hash';

  @override
  String get txDetailsTimeAndDateLabel => 'Time and Date';

  @override
  String get txDetailsConfirmationHeightLabel => 'Confirmation Height';

  @override
  String get txDetailsConfirmationsLabel => 'Confirmations';

  @override
  String get txDetailsViewKeyLabel => 'View Key';

  @override
  String get txDetailsRecipientsLabel => 'Recipients';

  @override
  String get txDetailsChangeRecipientLabel => 'Change Recipient';

  @override
  String get lwsKeysTitle => 'LWS Keys';

  @override
  String get lwsKeysPrimaryAddress => 'Primary Address';

  @override
  String get lwsKeysRestoreHeight => 'Restore Height';

  @override
  String get lwsKeysSecretViewKey => 'Secret View Key';

  @override
  String get secretKeysTitle => 'Secret Restore Keys';

  @override
  String get secretKeysMnemonic => 'Seed';

  @override
  String get secretKeysPublicSpendKey => 'Public Spend Key';

  @override
  String get secretKeysSecretSpendKey => 'Secret Spend Key';

  @override
  String get secretKeysPublicViewKey => 'Public View Key';

  @override
  String get scanQrTitle => 'Scan QR Code';

  @override
  String get confirmSendTitle => 'Confirm Send';

  @override
  String get confirmSendDescription =>
      'Transactions are irreversible, so make sure that these details match exactly.';

  @override
  String confirmSendHighFeeWarning(String percent) {
    return 'The network fee is $percent of the amount you are sending.';
  }

  @override
  String get addressBookTitle => 'Address Book';

  @override
  String get addressBookAddContact => 'Add Contact';

  @override
  String get addressBookEditContact => 'Edit Contact';

  @override
  String get addressBookDeleteContact => 'Delete Contact';

  @override
  String addressBookDeleteContactConfirmation(String contactName) {
    return 'Are you sure you want to delete \"$contactName\"?';
  }

  @override
  String get addressBookDelete => 'Delete';

  @override
  String get addressBookSearchHint => 'Search contacts...';

  @override
  String get addressBookNoContacts => 'No contacts yet';

  @override
  String get addressBookNoContactsDescription => 'Add your first contact by tapping the + button';

  @override
  String get addressBookNoSearchResults => 'No contacts found';

  @override
  String get addressBookCopyAddress => 'Copy Address';

  @override
  String get addressBookEdit => 'Edit';

  @override
  String get addressBookContactName => 'Contact Name';

  @override
  String get addressBookNameHint => 'Name';

  @override
  String get addressBookAddDescription => 'A name, and at least one address to pay them on.';

  @override
  String get addressBookEditDescription =>
      'Addresses get pasted or scanned, not typed. At least one is required.';

  @override
  String get addressBookAddressesLabel => 'Addresses';

  @override
  String get addressBookAddressesNoneYet => 'none yet';

  @override
  String get addressBookUpdate => 'Update';

  @override
  String get addressBookSave => 'Save';

  @override
  String get addressBookAtLeastOneAddressError => 'Enter at least one address';

  @override
  String addressBookNoContactsForCoin(String coinSymbol) {
    return 'No contacts with a $coinSymbol address';
  }

  @override
  String get sendSelectedContact => 'Selected contact';

  @override
  String get sendClearSelectedContact => 'Clear selected contact';

  @override
  String get sendPriorityLow => 'Low';

  @override
  String get sendPriorityNormal => 'Normal';

  @override
  String get sendPriorityHigh => 'High';

  @override
  String get sendPriorityLabel => 'priority';

  @override
  String get sendTransactionPriority => 'Transaction Priority';

  @override
  String get sendFeeLabel => 'Fee';

  @override
  String get sendFromLabel => 'From';

  @override
  String get sendToLabel => 'To';

  @override
  String get sendPriorityHeading => 'Priority';

  @override
  String get sendAvailableSuffix => 'available';

  @override
  String get sendNetworkFee => 'Network fee';

  @override
  String get sendMaxButton => 'MAX';

  @override
  String get sendPasteButton => 'Paste';

  @override
  String get sendScanButton => 'Scan';

  @override
  String sendAddressHint(String coin) {
    return '$coin address';
  }

  @override
  String get sendBalanceLabel => 'Balance';

  @override
  String get sendFailedToGetFeesError => 'Failed to get fees.';

  @override
  String get torInfoTitle => 'Tor Built-in';

  @override
  String get torInfoDescription =>
      'Spice Wallet automatically uses built-in Tor to protect your internet connections.';

  @override
  String get torInfoContinueButton => 'Continue';

  @override
  String get torInfoConfigureButton => 'Configure';

  @override
  String get torSettingsTitle => 'Tor Settings';

  @override
  String get torSettingsModeLabel => 'Tor Mode';

  @override
  String get torSettingsModeBuiltIn => 'Built-in Tor';

  @override
  String get torSettingsModeExternal => 'External Tor';

  @override
  String get torSettingsModeDisabled => 'No Tor';

  @override
  String get torSettingsSocksPortLabel => 'SOCKS Port';

  @override
  String get torSettingsSocksPortHint => 'e.g. 9050';

  @override
  String get torSettingsUseOrbotLabel => 'Use Orbot/InviZible';

  @override
  String get torSettingsUseOrbotLabelIos => 'Use Orbot';

  @override
  String get torSettingsSaveButton => 'Save';

  @override
  String get torSettingsTestConnectionButton => 'Test Connection';

  @override
  String get torDisabledWalletsWarningTitle => 'Disable Tor?';

  @override
  String get torDisabledWalletsWarningBody =>
      'Some wallets are set to connect over Tor. Disabling Tor will disconnect them, and they will stay disconnected until you reconfigure their connection.';

  @override
  String get torDisabledWalletsWarningConfirm => 'Disable Tor';

  @override
  String get connectionRemoteIpNotAllowed =>
      'Connections to remote IP addresses aren\'t allowed. Use a domain name or a local IP address.';

  @override
  String get connectionIndicatorTorInternal => 'Internal Tor';

  @override
  String connectionIndicatorTorExternal(String port) {
    return 'Using Port $port';
  }

  @override
  String get connectionIndicatorHttps => 'HTTPS';

  @override
  String get connectionIndicatorLocal => 'Local';

  @override
  String get connectionProtocolHttps => 'Removing protocol. Using HTTPS for domains.';

  @override
  String get connectionProtocolHttp => 'Removing protocol. Using HTTP for local addresses.';

  @override
  String get settingsLwsSettingsLabel => 'LWS Settings';

  @override
  String get settingsTorSettingsLabel => 'Tor Settings';

  @override
  String get lwsSetupUsingInternalTor => 'Using internal Tor';

  @override
  String lwsSetupUsingExternalTor(String address) {
    return 'Using external Tor proxy at $address';
  }

  @override
  String get lwsSetupTorDisabledError => 'Tor is disabled. Please go back and enable it.';

  @override
  String get lwsSetupInvalidQrCode => 'Invalid connection address.';

  @override
  String get save => 'Save';

  @override
  String get explorerSetupTitle => 'Block Explorer Setup';

  @override
  String get explorerSetupDescription =>
      'Optionally set a Blockscout instance to load full transaction history. Leave empty to disable — future sent transactions still appear without it.';

  @override
  String get explorerAddressLabel => 'Explorer Address';

  @override
  String get explorerRemoveButton => 'Remove Explorer';

  @override
  String get explorerRemovedMessage => 'Explorer removed.';

  @override
  String get explorerSetupButton => 'Set Up Explorer';

  @override
  String get explorerSetupHint => 'Set up a block explorer to see your full transaction history.';

  @override
  String get legacyTitle => 'Unsupported Wallet';

  @override
  String get legacyDescription =>
      'Spice Wallet is dropping support for legacy and polyseed seed phrases in favor of BIP39. Please write down the seed phrase below, delete this wallet and create a new wallet. You can restore the seed below on another Monero wallet and move the funds to your new BIP39 seed wallet.';

  @override
  String get legacyShowSeedButton => 'Show seed';

  @override
  String get legacySeedLabel => 'Seed';

  @override
  String get legacyError => 'Couldn\'t open the wallet. Check your password and try again.';
}
