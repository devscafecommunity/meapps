const ptMonths = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

const ptMonthsShort = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

/// Indexed by [DateTime.weekday] - 1 (Monday first).
const ptWeekdays = [
  'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira',
  'sexta-feira', 'sábado', 'domingo',
];

const ptWeekdaysShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Relative past time: "agora", "há 5 min", "há 3 h", "ontem", "12 nov".
String formatAgo(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inHours < 1) return 'há ${diff.inMinutes} min';
  if (isSameDay(d, n)) return 'há ${diff.inHours} h';
  if (dateOnly(n).difference(dateOnly(d)).inDays == 1) return 'ontem';
  final year = d.year == n.year ? '' : ' ${d.year}';
  return '${d.day} ${ptMonthsShort[d.month - 1]}$year';
}

/// "Hoje", "Amanhã" or "qui, 12 nov".
String formatDayLabel(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Amanhã';
  if (diff == -1) return 'Ontem';
  return '${ptWeekdaysShort[d.weekday - 1]}, ${d.day} ${ptMonthsShort[d.month - 1]}';
}

/// The calendar day [days] days after [d] (negative goes back), at
/// midnight. DST-safe, unlike adding a [Duration].
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Calendar days from [a] to [b] (negative if [b] is earlier), ignoring the
/// time of day and DST.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

/// Monday of the week containing [d], at midnight.
DateTime weekStart(DateTime d) => addDays(dateOnly(d), 1 - d.weekday);

/// First day of the month of [d]: the way the apps name a month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// [month] moved by [delta] months (negative goes back), as its first day.
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// "novembro 2026" (use [capitalize] for a title).
String formatMonth(DateTime month) =>
    '${ptMonths[month.month - 1]} ${month.year}';
