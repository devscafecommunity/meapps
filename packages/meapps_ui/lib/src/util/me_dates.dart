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
