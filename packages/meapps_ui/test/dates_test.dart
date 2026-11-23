import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';

void main() {
  final now = DateTime(2026, 11, 23, 15, 0);

  test('formatAgo', () {
    String ago(DateTime d) => formatAgo(d, now: now);
    expect(ago(now.subtract(const Duration(seconds: 20))), 'agora');
    expect(ago(now.subtract(const Duration(minutes: 5))), 'há 5 min');
    expect(ago(DateTime(2026, 11, 23, 9)), 'há 6 h');
    expect(ago(DateTime(2026, 11, 22, 23)), 'ontem');
    expect(ago(DateTime(2026, 11, 2)), '2 nov');
    expect(ago(DateTime(2025, 3, 4)), '4 mar 2025');
  });

  test('formatDayLabel', () {
    expect(formatDayLabel(DateTime(2026, 11, 24), now: now), 'Amanhã');
    expect(formatDayLabel(DateTime(2026, 11, 26), now: now), 'qui, 26 nov');
  });
}
