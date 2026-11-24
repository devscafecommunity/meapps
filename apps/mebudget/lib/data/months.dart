import 'package:meapps_ui/meapps_ui.dart';

/// First day of the month of [d] (the app's way to name a month).
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// [month] moved by [delta] months (negative goes back).
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// "novembro 2026".
String formatMonth(DateTime month) =>
    '${ptMonths[month.month - 1]} ${month.year}';

/// Calendar day as `yyyymmdd`, the storage format for dates without time.
int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime fromDayKey(int key) =>
    DateTime(key ~/ 10000, key ~/ 100 % 100, key % 100);
