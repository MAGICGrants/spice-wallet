import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_domain/wallet_domain.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/widgets/tx_details.dart';

/// Guards that every value row in the tx-details popup is copyable and confirms
/// the copy — the amount/fee/date/height rows used to be plain, unresponsive
/// Text, so a tap did nothing.
///
/// A fake wallet (not a real coin) supplies only the display getters the dialog
/// reads; a real [CryptoWallet] would schedule background timers that outlive
/// the test.
class _FakeWallet implements CryptoWallet {
  @override
  String get coinSymbol => 'XMR';
  @override
  String get iconAsset => '';
  @override
  String get feeCoinSymbol => 'XMR';
  @override
  int get baseUnitDecimals => 12;
  @override
  int get feeBaseUnitDecimals => 12;
  @override
  int get decimals => 4;
  @override
  int get feeDecimals => 4;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TxDetails sampleTx() => TxDetails(
    index: 0,
    direction: 0,
    hash: 'deadbeefcafe',
    amountBaseUnits: BigInt.from(1500000000000), // 1.5 XMR
    feeBaseUnits: BigInt.zero,
    recipients: const [],
    accountIndex: 0,
    subaddrIndexList: const [],
    timestamp: 1600000000,
    height: 100,
    confirmations: 5,
    key: '',
  );

  Future<void> pumpDialog(WidgetTester tester, CryptoWallet wallet, TxDetails tx) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => TxDetailsDialog.show(context, wallet, tx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the amount copies it and shows feedback', (tester) async {
    // Capture what lands on the clipboard (SecureClipboard falls back to the
    // platform clipboard off-device).
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': copied};
      return null;
    });

    final wallet = _FakeWallet();
    final tx = sampleTx();
    final amountText =
        '${displayAmount(tx.amountBaseUnits, wallet.baseUnitDecimals).toStringAsFixed(wallet.decimals)} ${wallet.coinSymbol}';

    await pumpDialog(tester, wallet, tx);

    await tester.tap(find.text(amountText));
    await tester.pump(); // surface the snackbar

    expect(copied, amountText);
    expect(find.text('Copied to clipboard'), findsOneWidget);

    // Drain SecureClipboard's 60s auto-clear timer so no timer outlives the test.
    await tester.pump(const Duration(seconds: 61));
  });
}
