import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('pt')];

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'A simple, open-source, and modern self-custody wallet for Serai and the blockchain networks that Serai supports: Bitcoin, Ethereum, and Monero. You are in total control. Maintained by MAGIC Grants, a public charity.'**
  String get welcomeDescription;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the '**
  String get welcomeAgreePrefix;

  /// No description provided for @welcomeTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get welcomeTermsLink;

  /// No description provided for @welcomeAgreeMiddle.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get welcomeAgreeMiddle;

  /// No description provided for @welcomePrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get welcomePrivacyLink;

  /// No description provided for @torChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. You can enable or disable Tor for each connection individually. In general, how do you want Spice Wallet to handle Tor connections?'**
  String get torChoiceSubtitle;

  /// No description provided for @connectionSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your {type}. Only select a server you trust. Even if you use Tor, this server can learn information about you.'**
  String connectionSetupDescription(String type);

  /// No description provided for @connectionSetupDescriptionLws.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your {type}. Only select a server you trust. Even if you use Tor, this server can learn information about you. Your private view key and primary address will be shared with this server.'**
  String connectionSetupDescriptionLws(String type);

  /// No description provided for @connectionProxyPortLabel.
  ///
  /// In en, this message translates to:
  /// **'HTTP Proxy Port'**
  String get connectionProxyPortLabel;

  /// No description provided for @connectionProxyPortHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get connectionProxyPortHint;

  /// No description provided for @fiatApiSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Spice Wallet can automatically fetch the latest asset prices. Your balances are not sent to the server. How do you want to fetch this price data?'**
  String get fiatApiSetupDescription;

  /// No description provided for @createWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'A single recovery phrase secures access to your wallet across all blockchain networks. Would you like to create a new wallet or restore an existing wallet?'**
  String get createWalletDescription;

  /// No description provided for @createWalletRestoreExistingDesc.
  ///
  /// In en, this message translates to:
  /// **'Any BIP39 phrase'**
  String get createWalletRestoreExistingDesc;

  /// No description provided for @createWalletCreateNewDesc.
  ///
  /// In en, this message translates to:
  /// **'Spice Wallet generates a 15-word BIP39 recovery phrase'**
  String get createWalletCreateNewDesc;

  /// No description provided for @generateSeedSubtitleCovered.
  ///
  /// In en, this message translates to:
  /// **'These fifteen words, in this order, are your wallet. Write them down and keep them in a physical safe. If you lose these words or if you share them with anyone else, you will lose your money permanently. Careful planning now avoids a potential disaster later.'**
  String get generateSeedSubtitleCovered;

  /// No description provided for @onboardingPasswordAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand that no one, including the Spice Wallet team, can recover this password.'**
  String get onboardingPasswordAcknowledge;

  /// No description provided for @restoreWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Any BIP39 phrase, from Spice Wallet or another wallet.'**
  String get restoreWalletSubtitle;

  /// No description provided for @restoreScanDescription.
  ///
  /// In en, this message translates to:
  /// **'For some assets, Spice Wallet can skip irrelevant history to save you time. Either pick the first month that you used the wallet or select I\'m not sure to check everything. It\'s okay to pick a month that is too early, but it\'s bad to pick a month that is too late.'**
  String get restoreScanDescription;

  /// No description provided for @navigationBarHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navigationBarHome;

  /// No description provided for @historyFilterBlockchain.
  ///
  /// In en, this message translates to:
  /// **'Blockchain'**
  String get historyFilterBlockchain;

  /// No description provided for @historyFilterAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get historyFilterAsset;

  /// No description provided for @historyFilterRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get historyFilterRecipient;

  /// No description provided for @historyFilterRecipientAny.
  ///
  /// In en, this message translates to:
  /// **'Any Blockchain'**
  String get historyFilterRecipientAny;

  /// No description provided for @historyFilterRecipientInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid address for supported blockchains'**
  String get historyFilterRecipientInvalid;

  /// No description provided for @historyTypeBridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get historyTypeBridge;

  /// No description provided for @historyTypeSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get historyTypeSwap;

  /// No description provided for @historyTypeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get historyTypeAdd;

  /// No description provided for @historyTypeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get historyTypeRemove;

  /// No description provided for @unlockLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Spice Wallet Is Locked'**
  String get unlockLockedTitle;

  /// No description provided for @unlockPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet Password'**
  String get unlockPasswordLabel;

  /// No description provided for @homeNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get homeNoConnection;

  /// No description provided for @homeCoinNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get homeCoinNotConfigured;

  /// No description provided for @homeUnknownCoin.
  ///
  /// In en, this message translates to:
  /// **'Unknown coin: {symbol}'**
  String homeUnknownCoin(String symbol);

  /// No description provided for @homeAssetsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 asset} other{{count} assets}}'**
  String homeAssetsCount(int count);

  /// No description provided for @coinHomeAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get coinHomeAssetsTitle;

  /// No description provided for @coinHomeBalancesMayBeStale.
  ///
  /// In en, this message translates to:
  /// **'Balances may be out of date while syncing'**
  String get coinHomeBalancesMayBeStale;

  /// No description provided for @coinHomeAddExplorerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an explorer to see history'**
  String get coinHomeAddExplorerTitle;

  /// No description provided for @coinHomeAddExplorerButton.
  ///
  /// In en, this message translates to:
  /// **'Add Explorer'**
  String get coinHomeAddExplorerButton;

  /// No description provided for @homeTotalBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get homeTotalBalanceLabel;

  /// No description provided for @receiveQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan this from the sending wallet, or send your {coin} address.'**
  String receiveQrHint(String coin);

  /// No description provided for @receiveBlockchainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{coin} blockchain'**
  String receiveBlockchainSubtitle(String coin);

  /// No description provided for @sendInsufficientGasError.
  ///
  /// In en, this message translates to:
  /// **'Insufficient ETH to cover the network fee.'**
  String get sendInsufficientGasError;

  /// No description provided for @settingsCoinConnectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsCoinConnectionSection;

  /// No description provided for @settingsCoinKeysSection.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get settingsCoinKeysSection;

  /// No description provided for @settingsCoinConnectionSetup.
  ///
  /// In en, this message translates to:
  /// **'Connection Setup'**
  String get settingsCoinConnectionSetup;

  /// No description provided for @settingsCoinExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get settingsCoinExplorer;

  /// No description provided for @settingsCoinNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsCoinNotConfigured;

  /// No description provided for @syncFrequencySheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often your wallets sync while the app is closed.'**
  String get syncFrequencySheetSubtitle;

  /// No description provided for @syncFrequencyContinuousDesc.
  ///
  /// In en, this message translates to:
  /// **'Continuously sync your wallets in the background so they\'re always up to date when you open the app. Uses more battery and requires a persistent notification.'**
  String get syncFrequencyContinuousDesc;

  /// No description provided for @syncFrequencyPeriodicDesc.
  ///
  /// In en, this message translates to:
  /// **'Periodically sync your wallets in the background so they\'re usually up to date when you open the app. A Monero node only syncs while charging and on WiFi.'**
  String get syncFrequencyPeriodicDesc;

  /// No description provided for @syncFrequencyPeriodicDescIos.
  ///
  /// In en, this message translates to:
  /// **'Periodically sync your wallets in the background so they\'re usually up to date when you open the app. A Monero node only syncs while charging.'**
  String get syncFrequencyPeriodicDescIos;

  /// No description provided for @settingsTestnetCoinsLabel.
  ///
  /// In en, this message translates to:
  /// **'Testnet Coins'**
  String get settingsTestnetCoinsLabel;

  /// No description provided for @settingsTestnetCoinsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show testnet coins (e.g. Bitcoin Testnet) in your coin list.'**
  String get settingsTestnetCoinsDescription;

  /// No description provided for @settingsThemeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm paper, the default'**
  String get settingsThemeLightDesc;

  /// No description provided for @settingsSeedPhraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery Phrase'**
  String get settingsSeedPhraseLabel;

  /// No description provided for @revealSeedSubtitleRevealed.
  ///
  /// In en, this message translates to:
  /// **'Securely save these. Do not share them. If you lose these words or if you share them with anyone else, you will lose your money permanently.'**
  String get revealSeedSubtitleRevealed;

  /// No description provided for @revealSeedBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get revealSeedBackButton;

  /// No description provided for @revealSeedHideButton.
  ///
  /// In en, this message translates to:
  /// **'Hide and Go Back'**
  String get revealSeedHideButton;

  /// No description provided for @addressBookAddDescription.
  ///
  /// In en, this message translates to:
  /// **'A name and at least one address to pay them.'**
  String get addressBookAddDescription;

  /// No description provided for @addressBookEditDescription.
  ///
  /// In en, this message translates to:
  /// **'A name and at least one address to pay them.'**
  String get addressBookEditDescription;

  /// No description provided for @addressBookAddressesLabel.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addressBookAddressesLabel;

  /// No description provided for @addressBookAddressesNoneYet.
  ///
  /// In en, this message translates to:
  /// **'none yet'**
  String get addressBookAddressesNoneYet;

  /// No description provided for @addressBookAtLeastOneAddressError.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one address'**
  String get addressBookAtLeastOneAddressError;

  /// No description provided for @addressBookNoContactsForCoin.
  ///
  /// In en, this message translates to:
  /// **'No contacts with a {coinSymbol} address'**
  String addressBookNoContactsForCoin(String coinSymbol);

  /// No description provided for @invalidAddressForChain.
  ///
  /// In en, this message translates to:
  /// **'Invalid {chain} address'**
  String invalidAddressForChain(String chain);

  /// No description provided for @sendFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get sendFromLabel;

  /// No description provided for @sendIrreversibleNote.
  ///
  /// In en, this message translates to:
  /// **'Transactions are irreversible. You can check these details again in the next step.'**
  String get sendIrreversibleNote;

  /// No description provided for @sendAddressHint.
  ///
  /// In en, this message translates to:
  /// **'{coin} address'**
  String sendAddressHint(String coin);

  /// No description provided for @sendPickContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a contact with a {coin} address.'**
  String sendPickContactSubtitle(String coin);

  /// No description provided for @sendContactNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No {coin} address'**
  String sendContactNoAddress(String coin);

  /// No description provided for @torSettingsSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tor can hide your IP address from servers you connect to. This does not reduce the information that is stored on public blockchains. Changing this reconnects every chain.'**
  String get torSettingsSheetSubtitle;

  /// No description provided for @connectionTorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Tor isn\'t available right now. Make sure it\'s running, then try again.'**
  String get connectionTorUnavailable;

  /// No description provided for @explorerSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Block Explorer Setup'**
  String get explorerSetupTitle;

  /// No description provided for @explorerSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Optionally set a Blockscout explorer instance to load full transaction history. Only select a server you trust. Even if you use Tor, this server can learn information about you.'**
  String get explorerSetupDescription;

  /// No description provided for @explorerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Explorer Address'**
  String get explorerAddressLabel;

  /// No description provided for @explorerRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Explorer removed.'**
  String get explorerRemovedMessage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
