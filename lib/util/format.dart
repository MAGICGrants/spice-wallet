/// Middle-truncates a long string (address / hash / key): `abcdef…uvwxyz`.
String shortenMiddle(String s, {int head = 6, int tail = 6}) =>
    s.length <= head + tail + 1 ? s : '${s.substring(0, head)}…${s.substring(s.length - tail)}';

/// A coin amount at capped precision, optionally suffixed with [symbol].
String formatAmount(double value, int decimals, {String? symbol}) {
  final text = value.toStringAsFixed(decimals.clamp(0, 8));
  return symbol == null ? text : '$text $symbol';
}
