/// Middle-truncates a long string (address / hash / key): `abcdef…uvwxyz`.
String shortenMiddle(String s, {int head = 6, int tail = 6}) =>
    s.length <= head + tail + 1 ? s : '${s.substring(0, head)}…${s.substring(s.length - tail)}';

/// [shortenMiddle] as a screen reader says it: [ends] (`a11yAddressEnds`,
/// "{start}, ending {end}") in place of the ellipsis.
String spokenShortened(
  String s,
  String Function(String start, String end) ends, {
  int head = 6,
  int tail = 6,
}) => s.length <= head + tail + 1 ? s : ends(s.substring(0, head), s.substring(s.length - tail));
