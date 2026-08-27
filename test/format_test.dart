import 'package:flutter_test/flutter_test.dart';
import 'package:spice_wallet/util/format.dart';

void main() {
  group('formatFiat', () {
    test('groups thousands and keeps two decimals', () {
      expect(formatFiat(1234.5, '\$'), '\$1,234.50');
      expect(formatFiat(0, '\$'), '\$0.00');
      expect(formatFiat(9.999, '€'), '€10.00');
    });
  });

  group('shortenMiddle', () {
    test('leaves short strings untouched', () {
      expect(shortenMiddle('abc'), 'abc');
      expect(shortenMiddle('1234567890123'), '1234567890123'); // 13 <= 6+6+1
    });

    test('middle-truncates long strings with defaults', () {
      expect(shortenMiddle('0123456789abcdef'), '012345…abcdef');
    });

    test('honours custom head/tail', () {
      expect(shortenMiddle('0123456789abcdef', head: 4, tail: 4), '0123…cdef');
    });
  });

  group('formatAmount', () {
    test('caps precision at the coin decimals', () {
      expect(formatAmount(412.090412345, 5), '412.09041');
      expect(formatAmount(1, 0), '1');
    });

    test('clamps decimals into [0, 8]', () {
      expect(formatAmount(1.123456789012, 12), '1.12345679');
    });

    test('appends the symbol when given', () {
      expect(formatAmount(2.5, 2, symbol: 'BTC'), '2.50 BTC');
    });
  });
}
