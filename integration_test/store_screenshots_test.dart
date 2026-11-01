import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:spice_wallet/main.dart' as app;
import 'package:spice_wallet/models/contact_model.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart' show CoinHomeScreenArgs;
import 'package:spice_wallet/screens/connection_setup.dart' show ConnectionSetupScreenArgs;
import 'package:spice_wallet/screens/receive.dart' show ReceiveScreenArgs;
import 'package:spice_wallet/screens/send.dart' show SendScreenArgs;
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/coin_assets.dart' show tokensOf;
import 'package:spice_wallet/wallet_core_glue.dart' show appCoins;
import 'package:wallet_bitcoin/screenshots.dart';
import 'package:wallet_backup/screenshots.dart';
import 'package:wallet_backup_platform/wallet_backup_platform.dart'
    show ICloudLocation, MetadataBackupSetup;
import 'package:wallet_bitcoin/wallet_bitcoin.dart' show BitcoinTestnetWallet;
import 'package:wallet_domain/screenshots.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager;
import 'package:wallet_ethereum/screenshots.dart';
import 'package:wallet_ethereum/wallet_ethereum.dart' show EthereumSepoliaWallet, DaiSepoliaWallet;
import 'package:wallet_fhse/screenshots.dart';
import 'package:wallet_fhse/security_keys_ui.dart' show AdvancedSecurityScreen;
import 'package:wallet_fiat/wallet_fiat.dart' show FiatRates;
import 'package:wallet_monero/screenshots.dart';

/// The App Store and F-Droid screenshots: the real app on sample wallets,
/// walked through the screens the listings show.
///
/// Not a test to run on its own. wallet-core's `scripts/store-screenshots.sh`
/// runs it (through scripts/store-screenshots.sh here) and takes each picture
/// [StoreShots.capture] asks for. Nothing reaches a server: the wallets are
/// sample ones ([SampleWallet]), prices are [FiatRates.fixedRates], and the
/// security keys and the backup are samples that only tell their screens so.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store screenshots', (tester) async {
    // A test build is a debug build: no DEBUG ribbon, and typing goes straight
    // to the field rather than raising the system keyboard over the screen.
    WidgetsApp.debugAllowBannerOverride = false;
    tester.testTextInput.register();
    FiatRates.fixedRates = _prices;
    sampleSecurityKeysState = _securityKeys();
    MetadataBackupSetup.serviceForTesting = (locations) => SampleMetadataBackupService(
      locations: locations,
      on: {ICloudLocation.locationId, MetadataBackupSetup.autoBackupLocationId},
      payments: 7,
      contacts: _contacts.length,
      lastSync: _now.subtract(const Duration(minutes: 3)),
    );
    appCoins = () => [
      SampleMoneroWallet(_monero()),
      SampleBitcoinWallet(_bitcoin()),
      BitcoinTestnetWallet(),
      SampleEthereumWallet(_ether()),
      EthereumSepoliaWallet(),
      SampleDaiWallet(_dai()),
      DaiSepoliaWallet(),
    ];
    // main() installs the app's own error logger; the test framework needs its
    // own back before a failure reaches it, or the run hangs instead of ending.
    final onError = FlutterError.onError;
    app.main();
    try {
      // Onboarding, from the welcome screen to restored sample wallets.
      await _tap(tester, find.text('Get Started'));
      await _tap(tester, find.text('No Tor'));
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Restore from a recovery phrase'));
      await Clipboard.setData(const ClipboardData(text: _seed));
      await _tap(tester, find.byTooltip('Paste'));
      // Restore waits for a scan-from choice; the sheet offers this month.
      await _tap(tester, find.text('Scan from'));
      await _tap(tester, find.text('Done'));
      await _tap(tester, find.text('Restore').last);
      // No backup to import: the sample wallets start from their seed alone.
      await _tap(tester, find.text('Skip'));

      // Every coin on a server of its own, behind Tor, as the coin pages would
      // set them up, and an address book.
      await _waitFor(tester, find.text('Receive'));
      final context = tester.element(find.text('Receive').first);
      final manager = Provider.of<WalletManager>(context, listen: false);
      await _useExternalTor(context, manager);
      await _connect(manager, 'XMR', 'lws.example.com:18090', type: 'lws');
      await _connect(manager, 'BTC', 'electrum.example.com:50002');
      await _connect(manager, 'ETH', 'eth.example.com');
      await _addContacts(tester, Provider.of<ContactModel>(context, listen: false), _contacts);

      // The pictures, in the order the app is walked; scripts/store-screenshots.sh
      // puts them in the listing's order. History first: the home it returns
      // to is a fresh one, whose security checklist reads the settings above.
      await _tap(tester, find.text('History'));
      await _shot(tester, 'history', light: false, dark: true);
      await _tap(tester, find.text('Home'));
      await _shot(tester, 'wallet_home', light: false, dark: true);

      for (final (symbol, name) in [('ETH', 'ether'), ('XMR', 'monero'), ('BTC', 'bitcoin')]) {
        await _open(tester, '/coin_home', CoinHomeScreenArgs(coinSymbol: symbol));
        await _shot(tester, '${name}_coin');
        await _back(tester);
      }

      await _open(tester, '/receive', ReceiveScreenArgs(coinSymbol: 'XMR'));
      await _waitFor(tester, find.text('Copy address'));
      await _shot(tester, 'receive');
      await _back(tester);

      await _open(
        tester,
        '/send',
        SendScreenArgs(coinSymbol: 'XMR', destinationAddress: _payee['XMR']!, amount: '0.25'),
      );
      await _shot(tester, 'send');
      await _back(tester);

      await _open(tester, '/connection_setup', ConnectionSetupScreenArgs(coinSymbol: 'XMR'));
      await _tap(tester, find.text('Test Connection'));
      await _waitFor(tester, find.text('Connection works'));
      await _shot(tester, 'connection_settings');
      await _back(tester);

      await _open(tester, '/metadata_backup');
      await _shot(tester, 'backup');
      await _back(tester);
      // Not the app's own route: that one asks the device to unlock first.
      await _push(tester, const AdvancedSecurityScreen());
      await _shot(tester, 'advanced_security');
      await _back(tester);

      await _tap(tester, find.text('Address Book'));
      await _tap(tester, find.text('Alice'));
      await _shot(tester, 'address_book');

      await _tap(tester, find.text('Settings').last);
      await _tap(tester, find.text('Tor Settings'));
      await _shot(tester, 'tor_settings', light: false, dark: true);
      await _back(tester);
    } catch (_) {
      // Where it stopped, for whoever runs this next: the screen, as the
      // script's <device>-failure.png, and the text on it.
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);
      debugPrint('store shots: stopped on: ${texts.nonNulls.join(' | ')}');
      await StoreShots.capture('_failure');
      rethrow;
    } finally {
      FlutterError.onError = onError;
    }
  });
}

// ----- The sample wallets -----

/// A throwaway wallet made for these pictures. It never held funds, and its
/// recovery phrase is public on purpose: it is in this file.
const _seed =
    'coconut craft couple unveil draft ride web south upon cover toss jazz '
    'salmon fame nominee';

const _prices = {'XMR': 508.83, 'BTC': 76541.0, 'ETH': 2437.30, 'DAI': 1.0};

/// Addresses made for these pictures from random bytes: valid, and unspendable
/// by anyone.
const _contacts = {
  'Alice': {
    'XMR': '45JEhQFx1on7V9yXvTbmXfKJw9VyqDeW8N9YqtbbqimLPV89PJiocbSaUg8FyoUbktQ7c7YGHCgNzNY8Y9BWNEucD933fzZ',
    'BTC': 'bc1q9jwq32py8u4vz4ydng5lkganrj8mytgm2da2jk',
    'ETH': '0xad3191FeF7FdB9D7E549c11EB1E923161499bd22',
  },
  'Bob': {
    'XMR': '43cda4NMuFkcnhxHQd4h9VDTfPCBER8tkNoTPtKFrx27YwnSZJYJG7pEZm2moL1wyCCaW37nhXbYLPrBQoDDrMrNKCBVnjZ',
    'BTC': 'bc1qyg448wd8hnjalpjuxxf8ttmx8mevpwf9f276dp',
  },
  'Charlie': {
    'ETH': '0x28BF61055fc0a2e511C191E67465F3d40830ED33',
    'BTC': 'bc1qusmrgxzarh2hxk4ndehflsd3enff9mx0sfhlft',
  },
  'David': {
    'XMR': '41tDUaQwyAgTStMK4JRpPBEHRW8EFnYBu5q9QnvLroTVQpVX432zho58VSRrwAYW7haS46rcnwFPg4yJQVpatUzPTmT6hhd',
  },
  'Eve': {
    'XMR': '4B1e8NPHWbaKShBH4hGeqEK8TwLJBrh1eGWYVeEff985XLgQQLKt87aVcFEdpgXJ8mQaQNZBNjcmPAdvb9zpPSk8AS9xwNM',
    'ETH': '0x04fFa3113f1563277540638B1C9D43b9A8DeAa8b',
  },
};
const _payee = {
  'XMR': '461qQuRxsfjAJawskpPKqo7qhBtZdm7uMXzca8U2Cp8gTz6D8fqG1HWJPqn4Y91jNL7fAbX8XjgR3LCJcoxCha1HVVf8K7T',
  'ETH': '0x960aE365a0e698077D62a5b705DB57b8eEb0699D',
};

/// 9:41 today, the time the status bar shows.
DateTime get _now {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9, 41);
}

/// Two security keys set up three weeks ago, as Advanced Security shows them.
/// Nothing is set up: only the screen is told so.
SecurityKeysState _securityKeys() {
  final added = _now.subtract(const Duration(days: 21));
  return SecurityKeysState(
    available: true,
    engaged: true,
    keys: [
      SecurityKeyRecord(id: 'sample-1', name: 'YubiKey 5C NFC', addedAt: added, serial: 28417035),
      SecurityKeyRecord(id: 'sample-2', name: 'Backup key', addedAt: added, serial: 28417291),
    ],
  );
}

SampleActivity _monero() => SampleActivity(
  decimals: 12,
  price: _prices['XMR']!,
  balance: '12.4837',
  fee: '0.0001228',
  height: 3790200,
  blockTime: const Duration(minutes: 2),
  counterparty: _contacts['Alice']!['XMR']!,
  now: _now,
  seed: 1,
  txs: const [
    SampleTx(daysAgo: 0, at: (9, 29), incoming: true, fiat: 182, confirmations: 4),
    SampleTx(daysAgo: 1, at: (19, 12), incoming: false, fiat: 47.5),
    SampleTx(daysAgo: 4, at: (14, 5), incoming: true, fiat: 128),
    SampleTx(daysAgo: 9, at: (10, 33), incoming: false, fiat: 12.75),
    SampleTx(daysAgo: 16, at: (17, 20), incoming: true, fiat: 199),
    SampleTx(daysAgo: 34, at: (11, 48), incoming: true, fiat: 1450),
    SampleTx(daysAgo: 58, at: (13, 15), incoming: true, fiat: 3200),
    SampleTx(daysAgo: 74, at: (16, 2), incoming: false, fiat: 140),
  ],
);

SampleActivity _bitcoin() => SampleActivity(
  decimals: 8,
  price: _prices['BTC']!,
  balance: '0.31204',
  fee: '0.0000084',
  height: 921400,
  blockTime: const Duration(minutes: 10),
  counterparty: _contacts['Bob']!['BTC']!,
  requiredConfirmations: 1,
  now: _now,
  seed: 2,
  txs: const [
    SampleTx(daysAgo: 0, at: (8, 21), incoming: true, fiat: 250),
    SampleTx(daysAgo: 2, at: (12, 40), incoming: false, fiat: 64),
    SampleTx(daysAgo: 7, at: (15, 55), incoming: true, fiat: 410),
    SampleTx(daysAgo: 21, at: (10, 12), incoming: false, fiat: 95.5),
    SampleTx(daysAgo: 47, at: (14, 30), incoming: true, fiat: 12000),
    SampleTx(daysAgo: 81, at: (11, 45), incoming: true, fiat: 11000),
  ],
);

SampleActivity _ether() => SampleActivity(
  decimals: 18,
  price: _prices['ETH']!,
  balance: '2.8451',
  fee: '0.000042',
  height: 23710000,
  blockTime: const Duration(seconds: 12),
  counterparty: _contacts['Charlie']!['ETH']!,
  requiredConfirmations: 1,
  now: _now,
  seed: 3,
  txs: const [
    SampleTx(daysAgo: 0, at: (8, 36), incoming: true, fiat: 182),
    SampleTx(daysAgo: 3, at: (16, 20), incoming: false, fiat: 47.5),
    SampleTx(daysAgo: 12, at: (13, 5), incoming: true, fiat: 620),
    SampleTx(daysAgo: 39, at: (10, 50), incoming: true, fiat: 6400),
  ],
);

SampleActivity _dai() => SampleActivity(
  decimals: 18,
  price: _prices['DAI']!,
  balance: '512.44',
  fee: '0.000091',
  height: 23710000,
  blockTime: const Duration(seconds: 12),
  counterparty: _contacts['Eve']!['ETH']!,
  requiredConfirmations: 1,
  shownDigits: 2,
  now: _now,
  seed: 4,
  txs: const [
    SampleTx(daysAgo: 1, at: (20, 15), incoming: false, fiat: 36),
    SampleTx(daysAgo: 5, at: (12, 25), incoming: true, fiat: 250),
    SampleTx(daysAgo: 26, at: (15, 40), incoming: true, fiat: 400),
  ],
);

// ----- Driving the app -----

/// Adds [book] to the address book, once the model's own first read of the
/// stored (empty) book is over: one that lands after an add drops it.
Future<void> _addContacts(
  WidgetTester tester,
  ContactModel contacts,
  Map<String, Map<String, String>> book,
) async {
  await _settle(tester, const Duration(seconds: 2));
  await contacts.load();
  for (final MapEntry(key: name, value: addresses) in book.entries) {
    await contacts.addContact(name, addresses);
  }
  final missing = book.keys.where((name) => !contacts.contacts.any((c) => c.name == name));
  if (missing.isNotEmpty) throw StateError('Contacts not saved: ${missing.join(', ')}');
}

/// Tor as the listing shows it: the user's own (External, port 9050) for prices
/// and every server. Written straight into the saved settings, because the Tor
/// screens test that Tor first, and here there is none; nothing goes through it.
Future<void> _useExternalTor(BuildContext context, WalletManager manager) async {
  await TorSettingsService.sharedInstance.save(torMode: TorMode.external, socksPort: '9050');
  await FiatRateModel.saveFiatApiMode(FiatApiMode.torOnly);
  if (!context.mounted) return;
  await Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
}

/// Points [symbol] at [address] the way the connection screen saves it, and
/// loads the wallet (and its tokens) against it.
Future<void> _connect(
  WalletManager manager,
  String symbol,
  String address, {
  String type = '',
}) async {
  final wallet = manager.getWallet(symbol)!;
  wallet.setConnection(address: address, proxyPort: '', useTor: true, connectionType: type);
  await wallet.persistCurrentConnection();
  await manager.applyConnectionChange(symbol);
  await wallet.load();
  for (final token in tokensOf(manager, symbol)) {
    await token.loadPersistedConnection();
    await token.load();
  }
}

Future<void> _push(WidgetTester tester, Widget screen) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await _settle(tester, const Duration(milliseconds: 1200));
}

Future<void> _open(WidgetTester tester, String route, [Object? arguments]) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(route, arguments: arguments);
  await _settle(tester, const Duration(milliseconds: 1200));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) throw StateError('Never appeared: $finder');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await _settle(tester, const Duration(milliseconds: 800));
}

Future<void> _back(WidgetTester tester) async {
  await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  await _settle(tester, const Duration(milliseconds: 800));
}

/// Waits for the screen to come to rest, then has the host take it.
Future<void> _shot(WidgetTester tester, String name, {bool light = true, bool dark = false}) async {
  // No blinking cursor in a field just typed into.
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester, const Duration(milliseconds: 1500));
  debugPrint('store shots: $name');
  await StoreShots.capture(name, light: light, dark: dark);
}
