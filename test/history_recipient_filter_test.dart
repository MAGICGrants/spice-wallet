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

  group('EVM addresses match across their three spellings', () {
    // `isAddressValid` accepts all-lower, all-upper and EIP-55 mixed case, and
    // all three name the same account. Comparing with `==` reported "no
    // transactions" for an address that had been paid.
    const lower = '0xab5801a7d398351b8be11c439e05c5b3259aec9b';
    const upper = '0xAB5801A7D398351B8BE11C439E05C5B3259AEC9B';
    const mixed = '0xAb5801a7D398351b8bE11C439e05C5B3259aec9B';

    for (final paid in [lower, upper, mixed]) {
      for (final searched in [lower, upper, mixed]) {
        test('paid ${paid.substring(0, 6)}…, searched ${searched.substring(0, 6)}…', () {
          final tx = _tx(recipients: [TxRecipient(paid, BigInt.one)]);
          expect(txPaysRecipient(tx, searched), isTrue);
        });
      }
    }

    test('a different EVM address still does not match', () {
      final tx = _tx(recipients: [TxRecipient(lower, BigInt.one)]);
      expect(txPaysRecipient(tx, '0x0000000000000000000000000000000000000001'), isFalse);
    });

    test('base58 stays case-significant, so two Monero addresses cannot collide', () {
      // Lowering base58 would fold distinct characters together. `4Ab…` and
      // `4aB…` are different addresses, and must stay different.
      final tx = _tx(recipients: [TxRecipient('4AbCdEfGh', BigInt.one)]);
      expect(txPaysRecipient(tx, '4abcdefgh'), isFalse);
      expect(canonicalAddress('4AbCdEfGh'), '4AbCdEfGh');
    });

    test('a 0x string that is not 20 bytes of hex is left alone', () {
      expect(canonicalAddress('0xNOTHEX'), '0xNOTHEX');
      expect(canonicalAddress('0xAB'), '0xAB');
    });
  });

  test('matching is exact, not a prefix or a substring', () {
    final tx = _tx(recipients: [TxRecipient('${alice}Extra', BigInt.one)]);
    expect(txPaysRecipient(tx, alice), isFalse);
  });
}
