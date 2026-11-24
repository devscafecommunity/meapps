import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

/// Icons a habit can show. Each maps to a const [Icons] value, so icon
/// tree-shaking keeps working: never build an [IconData] from stored data.
/// Stored by [name], so values can be reordered or added freely.
enum HabitIcon {
  water(Icons.water_drop_outlined, 'Água'),
  read(Icons.menu_book_outlined, 'Leitura'),
  walk(Icons.directions_walk, 'Caminhada'),
  run(Icons.directions_run, 'Corrida'),
  bike(Icons.directions_bike, 'Bicicleta'),
  gym(Icons.fitness_center, 'Ginásio'),
  meditate(Icons.self_improvement, 'Meditação'),
  sleep(Icons.bedtime_outlined, 'Sono'),
  food(Icons.restaurant_outlined, 'Alimentação'),
  veggie(Icons.eco_outlined, 'Vegetais'),
  pill(Icons.medication_outlined, 'Medicação'),
  write(Icons.edit_note, 'Escrita'),
  study(Icons.school_outlined, 'Estudo'),
  language(Icons.translate, 'Línguas'),
  music(Icons.music_note_outlined, 'Música'),
  clean(Icons.cleaning_services_outlined, 'Limpeza'),
  noPhone(Icons.mobile_off, 'Sem telemóvel'),
  savings(Icons.savings_outlined, 'Poupança'),
  plant(Icons.local_florist_outlined, 'Plantas'),
  health(Icons.favorite_outline, 'Saúde'),
  other(Icons.star_outline, 'Outro');

  const HabitIcon(this.icon, this.label);
  final IconData icon;
  final String label;

  /// Unknown names (e.g. written by a newer version) fall back to [other].
  static HabitIcon byName(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return other;
  }
}

/// Days-of-the-week bitmask helpers: Monday = bit 0 … Sunday = bit 6,
/// matching [DateTime.weekday] - 1.
abstract final class Weekdays {
  static const all = 0x7F;
  static const workdays = 0x1F;
  static const weekend = 0x60;

  static int bit(int weekday) => 1 << (weekday - 1);

  static bool has(int mask, int weekday) => mask & bit(weekday) != 0;

  static int toggle(int mask, int weekday) => mask ^ bit(weekday);

  /// "Todos os dias", "Dias úteis", "Fim de semana" or "seg, qua, sex".
  static String label(int mask) => switch (mask & all) {
    all => 'Todos os dias',
    workdays => 'Dias úteis',
    weekend => 'Fim de semana',
    0 => 'Nenhum dia',
    _ => [
      for (var d = 1; d <= 7; d++)
        if (has(mask, d)) ptWeekdaysShort[d - 1],
    ].join(', '),
  };
}

@immutable
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.createdAt,
    this.icon = HabitIcon.other,
    this.tone = MeTone.primary,
    this.weekdays = Weekdays.all,
    this.dailyTarget = 1,
    this.archived = false,
    this.position = 0,
  });

  final String id;
  final String name;

  /// Day the habit started (date only); earlier days never count.
  final DateTime createdAt;
  final HabitIcon icon;
  final MeTone tone;

  /// Bitmask, see [Weekdays].
  final int weekdays;

  /// Check-ins needed for a day to be complete (e.g. 8 glasses of water).
  final int dailyTarget;
  final bool archived;

  /// Order in the lists (ascending).
  final int position;

  Habit copyWith({
    String? name,
    DateTime? createdAt,
    HabitIcon? icon,
    MeTone? tone,
    int? weekdays,
    int? dailyTarget,
    bool? archived,
    int? position,
  }) => Habit(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    icon: icon ?? this.icon,
    tone: tone ?? this.tone,
    weekdays: weekdays ?? this.weekdays,
    dailyTarget: dailyTarget ?? this.dailyTarget,
    archived: archived ?? this.archived,
    position: position ?? this.position,
  );
}

// --- Days ----------------------------------------------------------------

/// Check-ins of one habit: count per day (keys are [dateOnly] values).
typedef DayCounts = Map<DateTime, int>;

/// [d] moved by [days] calendar days (DST-safe, unlike adding a Duration).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Calendar days from [a] to [b] (negative if [b] is earlier), ignoring the
/// time of day and DST.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) => addDays(dateOnly(d), 1 - d.weekday);

/// `yyyy-mm-dd`, the storage format of a calendar day.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

// --- Statistics (pure) ---------------------------------------------------

/// Whether [h] is planned on [day]: one of its weekdays, not before it
/// was created.
bool isScheduled(Habit h, DateTime day) =>
    !dateOnly(day).isBefore(dateOnly(h.createdAt)) &&
    Weekdays.has(h.weekdays, day.weekday);

int countOn(DayCounts counts, DateTime day) => counts[dateOnly(day)] ?? 0;

/// Whether the daily target of [h] was reached on [day].
bool isComplete(Habit h, DayCounts counts, DateTime day) =>
    countOn(counts, day) >= h.dailyTarget;

/// Consecutive scheduled days that are complete, counting back from
/// [today]. Unscheduled days are skipped (they neither count nor break it),
/// an incomplete [today] is still in progress so counting starts yesterday,
/// and the day before [Habit.createdAt] ends it.
int currentStreak(Habit h, DayCounts counts, {required DateTime today}) {
  var day = dateOnly(today);
  if (!isComplete(h, counts, day)) day = addDays(day, -1);
  final start = dateOnly(h.createdAt);
  var streak = 0;
  for (; !day.isBefore(start); day = addDays(day, -1)) {
    if (!isScheduled(h, day)) continue;
    if (!isComplete(h, counts, day)) break;
    streak++;
  }
  return streak;
}

/// Longest run of complete scheduled days between [Habit.createdAt] and
/// [today], with the same rules as [currentStreak].
int bestStreak(Habit h, DayCounts counts, {required DateTime today}) {
  final end = dateOnly(today);
  var best = 0;
  var run = 0;
  for (
    var day = dateOnly(h.createdAt);
    !day.isAfter(end);
    day = addDays(day, 1)
  ) {
    if (!isScheduled(h, day)) continue;
    if (isComplete(h, counts, day)) {
      run++;
      if (run > best) best = run;
    } else if (day != end) {
      run = 0;
    }
  }
  return best;
}

/// Complete scheduled days / scheduled days over the last [days] days
/// (from max(createdAt, [days] - 1 days before [today]) to [today]). Today
/// is still in progress, so it only counts once complete. Null when no day
/// of the window was scheduled yet.
double? completionRate(
  Habit h,
  DayCounts counts, {
  required DateTime today,
  int days = 30,
}) {
  final end = dateOnly(today);
  final created = dateOnly(h.createdAt);
  var day = addDays(end, 1 - days);
  if (day.isBefore(created)) day = created;
  var scheduled = 0;
  var complete = 0;
  for (; !day.isAfter(end); day = addDays(day, 1)) {
    if (!isScheduled(h, day)) continue;
    final done = isComplete(h, counts, day);
    if (day == end && !done) continue;
    scheduled++;
    if (done) complete++;
  }
  return scheduled == 0 ? null : complete / scheduled;
}
