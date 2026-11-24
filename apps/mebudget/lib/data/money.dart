/// Money helpers. Amounts are always integer cents (never `double`), so sums
/// are exact.
library;

/// Groups thousands: narrow no-break space, as in "1 234,50 €".
const thousandsSeparator = ' ';

/// Between the number and the euro sign, so "€" never wraps alone.
const _currencySpace = ' ';

/// pt-PT euro amount: `123450` -> "1 234,50 €", `-5` -> "-0,05 €".
/// With [signed], positive amounts get a leading "+" (e.g. incomes).
String formatMoney(int cents, {bool signed = false}) {
  final sign = cents < 0 ? '-' : (signed && cents > 0 ? '+' : '');
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(thousandsSeparator);
    buffer.write(whole[i]);
  }
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$sign$buffer,$frac$_currencySpace€';
}

/// Amount as typed in a text field, without grouping or currency:
/// `1250` -> "12,50", `1200` -> "12".
String formatMoneyInput(int cents) {
  final whole = cents ~/ 100;
  final frac = cents % 100;
  return frac == 0 ? '$whole' : '$whole,${frac.toString().padLeft(2, '0')}';
}

/// Plain digits with optional "," or "." decimals: "12", "12,5", "12.50".
final _plain = RegExp(r'^(\d+)(?:[.,](\d{0,2}))?$');

/// Space-grouped thousands: "1 234,56".
final _spaced = RegExp(r'^(\d{1,3}(?: \d{3})+)(?:[.,](\d{0,2}))?$');

/// Dot-grouped thousands with comma decimals: "1.234,56".
final _dotted = RegExp(r'^(\d{1,3}(?:\.\d{3})+)(?:,(\d{0,2}))?$');

/// Largest accepted amount: 999 999 999,99 €.
const _maxWholeDigits = 9;

/// Parses a positive euro amount typed by the user into cents.
///
/// Accepts "12", "12,5", "12,50", "1 234,56", "1.234,56", "12.50" and an
/// optional "€". Returns null for anything else, and for zero or negative
/// amounts.
int? parseMoney(String input) {
  var s = input.replaceAll(RegExp(r'[\s  ]+'), ' ').trim();
  if (s.endsWith('€')) {
    s = s.substring(0, s.length - 1).trim();
  } else if (s.startsWith('€')) {
    s = s.substring(1).trim();
  }
  final match =
      _plain.firstMatch(s) ?? _spaced.firstMatch(s) ?? _dotted.firstMatch(s);
  if (match == null) return null;
  final whole = match.group(1)!.replaceAll(RegExp('[ .]'), '');
  if (whole.replaceFirst(RegExp('^0+'), '').length > _maxWholeDigits) {
    return null;
  }
  final frac = (match.group(2) ?? '').padRight(2, '0');
  final cents = int.parse(whole) * 100 + int.parse(frac);
  return cents > 0 ? cents : null;
}
