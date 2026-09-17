import 'package:flutter_test/flutter_test.dart';
import 'package:spice_wallet/screens/history.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// The recipient filter's predicate.
///
/// `recipients` is one list serving both directions — the wallet's own
/// addresses on an incoming transaction, who was paid on an outgoing one — so
/// the filter needs no direction branch. What is worth pinning is the two
/// deliberate calls: change is matched, and nothing else is.
TxDetails _tx({required List<TxRecipient> recipients, int direction = 0}) => TxDetails(
  index: 0,
  direction: direction,
  hash: 'h',
  amountBaseUnits: BigInt.one,
  feeBaseUnits: BigInt.zero,
  recipients: recipients,
  accountIndex: 0,
  subaddrIndexList: const [],
  timestamp: 0,
  height: 1,
  confirmations: 1,
  key: '',
);

void main() {
  const alice = '4Alice';
  const bob = '4Bob';

  test('an incoming transaction received at the address matches', () {
    final tx = _tx(recipients: [TxRecipient(alice, BigInt.one)], direction: 1);
    expect(txPaysRecipient(tx, alice), isTrue);
  });

  test('an outgoing transaction that paid the address matches', () {
    final tx = _tx(recipients: [TxRecipient(bob, BigInt.one)]);
    expect(txPaysRecipient(tx, bob), isTrue);
  });

  test('change returned to the address matches', () {
    // Deliberate: a spend that sent change back to this address involved it.
    // Excluding change would narrow the filter to "who did I pay".
    final tx = _tx(
      recipients: [TxRecipient(bob, BigInt.one), TxRecipient(alice, BigInt.two, isChange: true)],
    );
    expect(txPaysRecipient(tx, alice), isTrue);
  });

  test('one match among several recipients is enough', () {
    final tx = _tx(recipients: [TxRecipient(bob, BigInt.one), TxRecipient(alice, BigInt.one)]);
    expect(txPaysRecipient(tx, alice), isTrue);
  });

  test('an unrelated transaction does not match', () {
    expect(txPaysRecipient(_tx(recipients: [TxRecipient(bob, BigInt.one)]), alice), isFalse);
  });

  test('a transaction with no recipients does not match', () {
    expect(txPaysRecipient(_tx(recipients: const []), alice), isFalse);
  });

  test('matching is exact, not a prefix or a substring', () {
    final tx = _tx(recipients: [TxRecipient('${alice}Extra', BigInt.one)]);
    expect(txPaysRecipient(tx, alice), isFalse);
  });
}
