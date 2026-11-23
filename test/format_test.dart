import 'package:flutter_test/flutter_test.dart';
import 'package:spice_wallet/util/format.dart';

void main() {
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
}
