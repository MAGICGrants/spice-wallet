// Labeled addresses in Spice: Receive offers the Labeled tab only on a chain
// that hands out a new address each time, and an address's Transactions button
// opens History already filtered to it, under its label.
//
// Stand-in wallets with only what these screens read: real ones would need
// keys and a server. The test host lays the screens out as on a desktop.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/history.dart';
import 'package:spice_wallet/screens/receive.dart';
import 'package:spice_wallet/widgets/ui/ui.dart'
    show
        LabeledAddressList,
        LabeledAddressPicker,
        TxActivityRow,
        WalletUiLocalizations,
        labeledAddressName;

class _FakeWallet extends ChangeNotifier implements CryptoWallet {
  _FakeWallet({
    required this.coinSymbol,
    required this.blockchainName,
    required this.address,
    this.rotatingAddressKind,
    this.used = const [],
    this.txHistory = const [],
  });

  @override
  final String coinSymbol;
  @override
  final String blockchainName;
  @override
  final RotatingAddressKind? rotatingAddressKind;
  @override
  final List<TxDetails> txHistory;
  final String address;
  final List<UsedReceiveAddress> used;

  @override
  String get assetName => blockchainName;
  @override
  String get iconAsset => '';
  @override
  String get connectionAddress => '';
  @override
  bool get isTestnet => false;
  @override
  int get decimals => 8;
  @override
  int get baseUnitDecimals => 8;
  @override
  int get txHistoryRevision => 0;
  @override
  String getPrimaryAddress() => address;
  @override
  String? getReceiveAddress() => address;
  @override
  bool isTxConfirmed(TxDetails tx) => true;
  @override
  Future<List<UsedReceiveAddress>> loadUsedReceiveAddresses() async => used;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TxDetails _received(String hash, String address, int timestamp) => TxDetails(
  index: 0,
  direction: txDirectionIncoming,
  hash: hash,
  amountBaseUnits: BigInt.from(100000),
  feeBaseUnits: BigInt.zero,
  recipients: [TxRecipient(address, BigInt.from(100000))],
  accountIndex: 0,
  subaddrIndexList: const [],
  timestamp: timestamp,
  height: 1,
  confirmations: 6,
  key: '',
);

void main() {
  late Directory tmp;

  const donations = 'bc1qdonations';
  const rent = 'bc1qrent';
  final usedDonations = UsedReceiveAddress(
    address: donations,
    index: 4,
    receivedBaseUnits: BigInt.from(100000),
    txCount: 1,
    lastUsed: 1700000200,
  );
  final usedRent = UsedReceiveAddress(
    address: rent,
    index: 3,
    receivedBaseUnits: BigInt.from(100000),
    txCount: 1,
    lastUsed: 1700000100,
  );

  _FakeWallet bitcoin() => _FakeWallet(
    coinSymbol: 'BTC',
    blockchainName: 'Bitcoin',
    address: 'bc1qfresh',
    rotatingAddressKind: RotatingAddressKind.address,
    used: [usedDonations, usedRent],
    txHistory: [
      _received('b', donations, usedDonations.lastUsed),
      _received('a', rent, usedRent.lastUsed),
    ],
  );

  _FakeWallet ethereum() =>
      _FakeWallet(coinSymbol: 'ETH', blockchainName: 'Ethereum', address: '0xabc');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('labeled_addresses');
    SharedPreferencesService.store = MemoryPreferenceStore();
    WalletSecrets.store = MemorySecretStore();
    WalletAppConfig.install(WalletAppConfig.spice, directories: FixedDirectories(tmp));
    WalletLog.sink = MemoryLogSink();
  });

  tearDown(() {
    WalletAppConfig.resetForTesting();
    SharedPreferencesService.resetForTesting();
    tmp.deleteSync(recursive: true);
  });

  /// A few frames: the used addresses load asynchronously.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pumps [screen] as the route [name] with [args], over wallets [coins] and
  /// the one label "Donations".
  Future<void> pump(
    WidgetTester tester, {
    required List<CryptoWallet> coins,
    required String name,
    required Object args,
    required Widget screen,
  }) async {
    // The test font (Ahem) is wider than the app's, so the fixed-width desktop
    // sidebar overflows; that layout warning is not what these tests are about.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final labels = AddressLabelModel(
      read: () async => const [AddressLabel(coin: 'BTC', address: donations, label: 'Donations')],
      write: (_) async {},
    );
    await labels.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletManager>(create: (_) => WalletManager(coins: () => coins)),
          ChangeNotifierProvider<FiatRateModel>(create: (_) => FiatRateModel()),
          ChangeNotifierProvider<AddressLabelModel>.value(value: labels),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            WalletUiLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (_) => MaterialPageRoute(
            settings: RouteSettings(name: name, arguments: args),
            builder: (_) => screen,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

  group('Receive', () {
    testWidgets('Bitcoin has an Address tab and a Labeled tab listing its used addresses', (
      tester,
    ) async {
      await pump(
        tester,
        coins: [bitcoin()],
        name: '/receive',
        args: ReceiveScreenArgs(coinSymbol: 'BTC'),
        screen: const ReceiveScreen(),
      );
      final shared = l10n(tester).shared;
      expect(find.text(shared.receiveAddressTab), findsOneWidget);
      expect(find.text(shared.receiveLabeledTab), findsOneWidget);
      expect(find.byType(LabeledAddressList), findsNothing);

      await tester.tap(find.text(shared.receiveLabeledTab));
      await settle(tester);

      expect(find.byType(LabeledAddressList), findsOneWidget);
      // The labeled one under its label, the other under its index.
      expect(find.text('Donations'), findsOneWidget);
      expect(find.text(labeledAddressName(shared, RotatingAddressKind.address, 3)), findsOneWidget);

      await tearDownScreen(tester);
    });

    testWidgets('Ethereum keeps one address, so it has no tabs at all', (tester) async {
      await pump(
        tester,
        coins: [ethereum()],
        name: '/receive',
        args: ReceiveScreenArgs(coinSymbol: 'ETH'),
        screen: const ReceiveScreen(),
      );
      final shared = l10n(tester).shared;
      expect(find.text(shared.receiveLabeledTab), findsNothing);
      expect(find.text(shared.receiveAddressTab), findsNothing);

      await tearDownScreen(tester);
    });
  });

  group('History opened on an address', () {
    testWidgets('shows only its transactions, under its label, with a way back', (tester) async {
      await pump(
        tester,
        coins: [bitcoin(), ethereum()],
        name: '/history',
        args: HistoryScreenArgs(coinSymbol: 'BTC', address: donations, backLabel: 'Donations'),
        screen: const HistoryScreen(),
      );

      // One of the two Bitcoin payments.
      expect(find.byType(TxActivityRow), findsOneWidget);
      // The filter pill names the address by its label, and the back link
      // returns to that address.
      expect(find.text('Donations'), findsNWidgets(2));
      expect(find.text(l10n(tester).historyFilterRecipient), findsNothing);

      await tearDownScreen(tester);
    });

    testWidgets('its labeled addresses can be picked in the address filter', (tester) async {
      await pump(
        tester,
        coins: [bitcoin(), ethereum()],
        name: '/history',
        args: HistoryScreenArgs(coinSymbol: 'BTC', address: rent),
        screen: const HistoryScreen(),
      );
      expect(find.byType(TxActivityRow), findsOneWidget);
      final i18n = l10n(tester);

      // Rent has no label, so the pill keeps its name.
      await tester.tap(find.text(i18n.historyFilterRecipient));
      await settle(tester);
      expect(find.byType(LabeledAddressPicker), findsOneWidget);

      await tester.tap(find.text('Donations'));
      await settle(tester);

      // Now filtered to Donations: still one payment, and the pill and the
      // panel's card name it.
      expect(find.byType(TxActivityRow), findsOneWidget);
      expect(find.text('Donations'), findsNWidgets(3));

      await tearDownScreen(tester);
    });
  });
}
