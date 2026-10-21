// Desktop Send keeps a contact's name on that contact's own address only (MAGIC
// Grants AI audit 2026-10-20, M-03). The desktop form keeps Paste beside the
// contact card, and pressing it used to leave the contact's name over the
// clipboard's address, through to the confirm sheet, while the tx paid the
// clipboard's address. Switching the asset to another chain must still move a
// picked contact to its address there.
//
// Runs where the desktop form does: a Linux, macOS or Windows host
// (`isDesktopLayout`). Nothing leaves the machine: Monero is wallet-core's
// MoneroWallet on its FakeMoneroBackend, Bitcoin a stand-in wallet, and the
// clipboard a mocked platform call.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/testing.dart';
import 'package:wallet_infra/wallet_infra.dart';
import 'package:wallet_monero/wallet_monero.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/send.dart';
import 'package:spice_wallet/widgets/ui/ui.dart' show BrandButton, ConfirmSendView, SendAmountCard;

/// A Bitcoin wallet with only what Send and the confirm sheet read. A real one
/// would need keys and an Electrum server.
class _FakeBitcoinWallet extends ChangeNotifier implements CryptoWallet {
  /// Destination of every tx built, in order.
  final List<String> txDestinations = [];

  @override
  String get coinSymbol => 'BTC';
  @override
  String get blockchainName => 'Bitcoin';
  @override
  String get assetName => blockchainName;
  @override
  String get iconAsset => '';
  @override
  int get decimals => 8;
  @override
  int get baseUnitDecimals => 8;
  @override
  String get feeCoinSymbol => coinSymbol;
  @override
  int get feeDecimals => 8;
  @override
  int get feeBaseUnitDecimals => 8;
  @override
  bool get feeIsForeign => false;
  @override
  bool get isTestnet => false;
  @override
  String get aliasAsset => '';
  @override
  String get connectionAddress => '';
  @override
  BigInt? get unlockedBalanceBaseUnits => BigInt.from(10) * BigInt.from(10).pow(8);
  @override
  double? get unlockedBalance => 10;

  @override
  bool isAddressValid(String address) => address.length == 42 && address.startsWith('bc1');

  @override
  Future<BigInt?> estimateFee(
    String destinationAddress,
    BigInt amountBaseUnits, {
    int priority = 0,
  }) async => BigInt.from(1000);

  @override
  Future<PendingTransaction> createTx(
    String destinationAddress,
    BigInt amountBaseUnits,
    bool isSweepAll, {
    int priority = 0,
  }) async {
    txDestinations.add(destinationAddress);
    return _FakePendingTx(amountBaseUnits, BigInt.from(1000));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePendingTx implements PendingTransaction {
  @override
  final BigInt amountBaseUnits;
  @override
  final BigInt feeBaseUnits;

  _FakePendingTx(this.amountBaseUnits, this.feeBaseUnits);
}

void main() {
  late Directory tmp;
  late FakeMoneroBackend backend;
  late _FakeBitcoinWallet bitcoin;
  late WalletManager manager;
  late ContactModel contacts;

  // Stand-ins for addresses (this Monero backend's validator accepts any 95
  // characters starting with '4'; the Bitcoin stand-in any 42 starting 'bc1').
  final alice = '4${'A' * 94}';
  final pasted = '4${'Z' * 94}';
  final aliceBtc = 'bc1${'a' * 39}';
  final pastedBtc = 'bc1${'z' * 39}';
  final aliceContact = Contact(id: 'c1', name: 'Alice', addresses: {'XMR': alice, 'BTC': aliceBtc});

  final onDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  setUpAll(() => WalletFileCrypto.kdf = const FastTestPbkdf2());
  tearDownAll(() => WalletFileCrypto.kdf = const WebCryptoPbkdf2());

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('send_contact_paste');
    SharedPreferencesService.store = MemoryPreferenceStore();
    WalletSecrets.store = MemorySecretStore();
    WalletAppConfig.install(WalletAppConfig.spice, directories: FixedDirectories(tmp));
    useTestCaBundle();
    WalletLog.sink = MemoryLogSink();
    backend = FakeMoneroBackend()
      ..addressValidator = ((a, _) => a.length == 95 && a.startsWith('4'));
    final monero = MoneroWallet(backend: backend);
    backend.existingWalletPaths.add(await monero.walletPathForType('lws'));
    await monero.openExisting(password: 'pw');
    // 10 XMR spendable, so the form can be submitted.
    // ignore: invalid_use_of_protected_member
    monero.setUnlockedBalanceBaseUnits(BigInt.from(10) * BigInt.from(10).pow(12));
    backend.pendingAmount = BigInt.from(10).pow(12);
    backend.pendingFee = BigInt.from(30000000);
    bitcoin = _FakeBitcoinWallet();
    manager = WalletManager(coins: () => [monero, bitcoin]);
    contacts = ContactModel(
      read: () async => [json.encode(aliceContact.toJson())],
      write: (_) async {},
    );
    await contacts.load();
  });

  tearDown(() {
    WalletAppConfig.resetForTesting();
    CaBundle.resetForTesting();
    SharedPreferencesService.resetForTesting();
    tmp.deleteSync(recursive: true);
  });

  String short(String a) => '${a.substring(0, 10)}…${a.substring(a.length - 12)}';

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens Send with [args]; the clipboard then holds [clipboard], an address
  /// the user did not mean (or a clipboard hijacker put there).
  Future<void> openSend(WidgetTester tester, SendScreenArgs args, {String? clipboard}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboard ?? pasted};
      }
      return null;
    });

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
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletManager>.value(value: manager),
          ChangeNotifierProvider<ContactModel>.value(value: contacts),
          ChangeNotifierProvider<FiatRateModel>(create: (_) => FiatRateModel()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: RouteSettings(name: '/send', arguments: args),
            builder: (_) => const SendScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SendScreen)))!;

  /// Picks Alice in Send's own contact picker.
  Future<void> pickAlice(WidgetTester tester) async {
    await tester.tap(find.text(l10n(tester).sendContactsButton));
    await settle(tester);
    await tester.tap(find.text('Alice'));
    await settle(tester);
  }

  /// Switches the From asset to Bitcoin.
  Future<void> selectBitcoin(WidgetTester tester) async {
    await tester.tap(find.text('Monero').last);
    await settle(tester);
    await tester.tap(find.text('Bitcoin'));
    await settle(tester);
  }

  /// Enters 1 of the current coin and presses Send, which opens the confirm
  /// sheet.
  Future<void> sendOne(WidgetTester tester) async {
    await tester.enterText(
      find.descendant(of: find.byType(SendAmountCard), matching: find.byType(TextField)),
      '1',
    );
    await settle(tester);
    final sendButton = find.widgetWithText(BrandButton, l10n(tester).sendSendButton);
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await settle(tester);
    expect(find.byType(ConfirmSendView), findsOneWidget);
  }

  Finder onConfirmSheet(Finder finder) =>
      find.descendant(of: find.byType(ConfirmSendView), matching: finder);

  /// The address fields (not the amount) whose text is [text].
  Iterable<TextField> addressFieldsWith(String text) => find
      .byType(TextField)
      .evaluate()
      .map((e) => e.widget as TextField)
      .where((f) => f.controller?.text == text);

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  for (final viaPicker in [false, true]) {
    final how = viaPicker ? "Send's contact picker" : "the address book's Send";
    testWidgets('Paste after a contact from $how replaces the contact', (tester) async {
      await openSend(
        tester,
        viaPicker
            ? SendScreenArgs(coinSymbol: 'XMR', destinationAddress: '')
            : SendScreenArgs(coinSymbol: 'XMR', destinationAddress: alice, contact: aliceContact),
      );
      if (viaPicker) await pickAlice(tester);

      // Before: the contact card names Alice over her address, with Paste beside it.
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text(short(alice)), findsOneWidget);
      final paste = find.text(l10n(tester).sendPasteButton);
      expect(paste, findsOneWidget);

      await tester.tap(paste);
      await tester.pump(const Duration(milliseconds: 100));

      // After: the contact is gone and the card is the address field again,
      // holding the clipboard's address.
      expect(find.text('Alice'), findsNothing);
      expect(find.text(short(alice)), findsNothing);
      expect(addressFieldsWith(pasted), hasLength(1));

      await sendOne(tester);

      // The tx pays the clipboard's address, and the confirm sheet shows that
      // address without the contact's name.
      expect(backend.createTransactionRequests.last.destinations, [pasted]);
      expect(onConfirmSheet(find.text(pasted, findRichText: true)), findsOneWidget);
      expect(onConfirmSheet(find.textContaining('Alice')), findsNothing);
      expect(find.text('(Alice)'), findsNothing);

      await tearDownScreen(tester);
    }, skip: !onDesktop);
  }

  testWidgets('a contact with nothing pasted still names its address on the confirm sheet', (
    tester,
  ) async {
    await openSend(
      tester,
      SendScreenArgs(coinSymbol: 'XMR', destinationAddress: alice, contact: aliceContact),
    );
    expect(find.text('Alice'), findsOneWidget);

    await sendOne(tester);

    expect(backend.createTransactionRequests.last.destinations, [alice]);
    expect(onConfirmSheet(find.text(alice, findRichText: true)), findsOneWidget);
    expect(onConfirmSheet(find.text('(Alice)')), findsOneWidget);

    await tearDownScreen(tester);
  }, skip: !onDesktop);

  testWidgets('a contact handed in with an address that is not theirs is not shown', (
    tester,
  ) async {
    // The contact arrives after the text, so the field's listener never sees it.
    await openSend(
      tester,
      SendScreenArgs(coinSymbol: 'XMR', destinationAddress: pasted, contact: aliceContact),
    );
    expect(find.text('Alice'), findsNothing);

    await sendOne(tester);

    expect(backend.createTransactionRequests.last.destinations, [pasted]);
    expect(find.text('(Alice)'), findsNothing);

    await tearDownScreen(tester);
  }, skip: !onDesktop);

  group('switching the asset to another chain', () {
    // From the multicoin home every asset is offered, so the chain can change.
    final fromHome = SendScreenArgs(coinSymbol: 'XMR', destinationAddress: '', allAssets: true);

    testWidgets('moves a picked contact to its address there', (tester) async {
      await openSend(tester, fromHome);
      await pickAlice(tester);
      expect(find.text(short(alice)), findsOneWidget);

      await selectBitcoin(tester);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text(short(aliceBtc)), findsOneWidget);

      await sendOne(tester);

      expect(bitcoin.txDestinations, [aliceBtc]);
      expect(backend.createTransactionRequests, isEmpty);
      expect(onConfirmSheet(find.text(aliceBtc, findRichText: true)), findsOneWidget);
      expect(onConfirmSheet(find.text('(Alice)')), findsOneWidget);

      await tearDownScreen(tester);
    }, skip: !onDesktop);

    testWidgets('and Paste after the move still replaces the contact', (tester) async {
      await openSend(tester, fromHome, clipboard: pastedBtc);
      await pickAlice(tester);
      await selectBitcoin(tester);
      expect(find.text('Alice'), findsOneWidget);

      await tester.tap(find.text(l10n(tester).sendPasteButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alice'), findsNothing);
      expect(addressFieldsWith(pastedBtc), hasLength(1));

      await sendOne(tester);

      expect(bitcoin.txDestinations, [pastedBtc]);
      expect(onConfirmSheet(find.text(pastedBtc, findRichText: true)), findsOneWidget);
      expect(find.text('(Alice)'), findsNothing);

      await tearDownScreen(tester);
    }, skip: !onDesktop);
  });
}
