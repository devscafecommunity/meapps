import 'dart:collection';
import 'dart:math';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, OrderingTerm, Value;
import 'package:flutter/foundation.dart';
import 'package:meapps_ui/meapps_ui.dart';

import 'database.dart';
import 'habit.dart';
import 'habit.dart' as stats show currentStreak, bestStreak, completionRate;

export 'habit.dart';

/// What [AppStore.deleteHabit] removed, so it can be put back.
typedef DeletedHabit = ({Habit habit, DayCounts checkins});

String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}';

// --- Demo seed (first launch only) -------------------------------------

/// Dates are relative to [today] so the demo data always looks alive.
List<Habit> _demoHabits(DateTime today) => [
  Habit(
    id: 'h1',
    name: 'Beber água',
    icon: HabitIcon.water,
    tone: MeTone.primary,
    dailyTarget: 8,
    createdAt: addDays(today, -42),
    position: 0,
  ),
  Habit(
    id: 'h2',
    name: 'Ler 20 min',
    icon: HabitIcon.read,
    tone: MeTone.tertiary,
    createdAt: addDays(today, -42),
    position: 1,
  ),
  Habit(
    id: 'h3',
    name: 'Caminhar',
    icon: HabitIcon.walk,
    tone: MeTone.secondary,
    createdAt: addDays(today, -36),
    position: 2,
  ),
  Habit(
    id: 'h4',
    name: 'Meditar',
    icon: HabitIcon.meditate,
    tone: MeTone.plain,
    weekdays: Weekdays.workdays,
    createdAt: addDays(today, -40),
    position: 3,
  ),
  Habit(
    id: 'h5',
    name: 'Ginásio',
    icon: HabitIcon.gym,
    tone: MeTone.secondary,
    weekdays:
        Weekdays.bit(DateTime.tuesday) |
        Weekdays.bit(DateTime.thursday) |
        Weekdays.bit(DateTime.saturday),
    createdAt: addDays(today, -18),
    position: 4,
  ),
];

/// About six weeks of plausible check-ins: mostly complete days with a few
/// misses (partial for counted habits), an unbroken recent run per habit,
/// and some progress already logged today.
Map<String, DayCounts> _demoCheckins(List<Habit> habits, DateTime today) {
  final rng = Random(7);
  const rate = {'h1': 0.8, 'h2': 0.7, 'h3': 0.65, 'h4': 0.85, 'h5': 0.9};
  const recent = {'h1': 9, 'h2': 4, 'h3': 2, 'h4': 6, 'h5': 5};
  const todayCount = {'h1': 3, 'h2': 1};
  final result = <String, DayCounts>{};
  for (final h in habits) {
    final counts = result[h.id] = {};
    for (var back = 60; back >= 1; back--) {
      final day = addDays(today, -back);
      if (!isScheduled(h, day)) continue;
      final done = back <= recent[h.id]! || rng.nextDouble() < rate[h.id]!;
      final count = done
          ? h.dailyTarget
          : (h.dailyTarget > 1 ? rng.nextInt(h.dailyTarget) : 0);
      if (count > 0) counts[day] = count;
    }
    final now = todayCount[h.id];
    if (now != null) counts[today] = now;
  }
  return result;
}

// --- Store -------------------------------------------------------------

/// Single source of truth for the UI. Keeps the data in memory for
/// synchronous reads and writes every change through to SQLite (Drift).
class AppStore extends ChangeNotifier {
  AppStore(this._db);

  final AppDatabase _db;

  /// Every habit (active and archived), ordered by [Habit.position].
  List<Habit> habits = [];
  final Map<String, DayCounts> _checkins = {};
  Map<String, String> settings = {};

  /// Loads from disk; seeds demo data when the database is brand new.
  Future<void> init({bool seedDemo = true}) async {
    // The first query opens the database and tells whether it was created.
    await _db.select(_db.settings).get();
    if (seedDemo && _db.created) await _seed();
    await _load();
  }

  Future<void> _seed() async {
    final today = dateOnly(DateTime.now());
    final demo = _demoHabits(today);
    final counts = _demoCheckins(demo, today);
    await _db.batch((b) {
      b.insertAll(_db.habits, [for (final h in demo) _habitRow(h)]);
      b.insertAll(_db.checkins, [
        for (final e in counts.entries)
          for (final c in e.value.entries) _checkinRow(e.key, c.key, c.value),
      ]);
    });
  }

  Future<void> _load() async {
    final rows = await (_db.select(
      _db.habits,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    habits = [
      for (final row in rows)
        Habit(
          id: row.id,
          name: row.name,
          icon: HabitIcon.byName(row.icon),
          tone: row.tone >= 0 && row.tone < MeTone.values.length
              ? MeTone.values[row.tone]
              : MeTone.plain,
          weekdays: row.weekdays,
          dailyTarget: max(1, row.dailyTarget),
          archived: row.archived,
          createdAt: parseDayKey(row.createdAt),
          position: row.position,
        ),
    ];
    _checkins.clear();
    for (final row in await _db.select(_db.checkins).get()) {
      (_checkins[row.habitId] ??= {})[parseDayKey(row.day)] = row.count;
    }
    settings = {
      for (final row in await _db.select(_db.settings).get())
        row.key: row.value,
    };
    notifyListeners();
  }

  HabitsCompanion _habitRow(Habit h) => HabitsCompanion(
    id: Value(h.id),
    name: Value(h.name),
    icon: Value(h.icon.name),
    tone: Value(h.tone.index),
    weekdays: Value(h.weekdays),
    dailyTarget: Value(h.dailyTarget),
    archived: Value(h.archived),
    createdAt: Value(dayKey(h.createdAt)),
    position: Value(h.position),
  );

  CheckinsCompanion _checkinRow(String habitId, DateTime day, int count) =>
      CheckinsCompanion.insert(
        habitId: habitId,
        day: dayKey(day),
        count: count,
      );

  // An upsert (not INSERT OR REPLACE), so the check-ins are not cascaded away.
  Future<void> _writeHabit(Habit h) =>
      _db.into(_db.habits).insertOnConflictUpdate(_habitRow(h));

  Future<void> _writeCount(String habitId, DateTime day, int count) => count > 0
      ? _db
            .into(_db.checkins)
            .insertOnConflictUpdate(_checkinRow(habitId, day, count))
      : (_db.delete(_db.checkins)..where(
              (t) => t.habitId.equals(habitId) & t.day.equals(dayKey(day)),
            ))
            .go();

  Future<void> close() => _db.close();

  // --- Queries ---------------------------------------------------------

  Habit? habitById(String? id) {
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  List<Habit> get activeHabits => habits.where((h) => !h.archived).toList();

  List<Habit> get archivedHabits => habits.where((h) => h.archived).toList();

  /// Read-only check-ins of a habit, by day.
  DayCounts checkinsOf(String habitId) =>
      UnmodifiableMapView(_checkins[habitId] ?? const {});

  int countOn(Habit h, DateTime day) => _checkins[h.id]?[dateOnly(day)] ?? 0;

  bool isComplete(Habit h, DateTime day) => countOn(h, day) >= h.dailyTarget;

  int currentStreak(Habit h, {DateTime? today}) =>
      stats.currentStreak(h, checkinsOf(h.id), today: today ?? DateTime.now());

  int bestStreak(Habit h, {DateTime? today}) =>
      stats.bestStreak(h, checkinsOf(h.id), today: today ?? DateTime.now());

  double? completionRate(Habit h, {DateTime? today}) =>
      stats.completionRate(h, checkinsOf(h.id), today: today ?? DateTime.now());

  /// Active habits that exist on [day], split into the ones planned for that
  /// weekday and the others (which can still be checked).
  ({List<Habit> scheduled, List<Habit> unscheduled}) habitsOn(DateTime day) {
    final d = dateOnly(day);
    final existing = activeHabits.where(
      (h) => !d.isBefore(dateOnly(h.createdAt)),
    );
    return (
      scheduled: existing.where((h) => isScheduled(h, d)).toList(),
      unscheduled: existing.where((h) => !isScheduled(h, d)).toList(),
    );
  }

  // --- Habits ----------------------------------------------------------

  void _sort() => habits.sort((a, b) => a.position.compareTo(b.position));

  /// Inserts or replaces a habit (matched by id). New habits go last;
  /// existing ones keep their place (see [moveHabit]).
  Future<void> saveHabit(Habit h) async {
    final i = habits.indexWhere((e) => e.id == h.id);
    final habit = h.copyWith(
      createdAt: dateOnly(h.createdAt),
      dailyTarget: max(1, h.dailyTarget),
      position: i >= 0
          ? habits[i].position
          : habits.fold<int>(-1, (m, e) => max(m, e.position)) + 1,
    );
    if (i >= 0) {
      habits[i] = habit;
    } else {
      habits.add(habit);
    }
    _sort();
    notifyListeners();
    await _writeHabit(habit);
  }

  /// Archived habits are hidden from "Hoje" and "Progresso"; their history
  /// is kept.
  Future<void> setArchived(String id, bool archived) async {
    final h = habitById(id);
    if (h == null || h.archived == archived) return;
    await saveHabit(h.copyWith(archived: archived));
  }

  /// Removes a habit and its check-ins. Returns what was removed so the UI
  /// can offer "undo" through [restoreHabit].
  Future<DeletedHabit?> deleteHabit(String id) async {
    final habit = habitById(id);
    if (habit == null) return null;
    final counts = _checkins.remove(id) ?? {};
    habits.removeWhere((h) => h.id == id);
    notifyListeners();
    // Check-ins go with it (ON DELETE CASCADE).
    await (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();
    return (habit: habit, checkins: counts);
  }

  Future<void> restoreHabit(DeletedHabit deleted) async {
    final h = deleted.habit;
    habits.add(h);
    _sort();
    _checkins[h.id] = {...deleted.checkins};
    notifyListeners();
    await _db.transaction(() async {
      await _writeHabit(h);
      await _db.batch(
        (b) => b.insertAllOnConflictUpdate(_db.checkins, [
          for (final e in deleted.checkins.entries)
            _checkinRow(h.id, e.key, e.value),
        ]),
      );
    });
  }

  /// Moves the active habit at index [from] to index [to] of
  /// [activeHabits] (both counted before the move). Archived habits keep
  /// their relative order after the active ones.
  Future<void> moveHabit(int from, int to) async {
    final active = activeHabits;
    if (from < 0 || from >= active.length) return;
    final target = max(0, min(to, active.length - 1));
    if (target == from) return;
    active.insert(target, active.removeAt(from));
    final ordered = [...active, ...archivedHabits];
    habits = [
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(position: i),
    ];
    notifyListeners();
    await _db.transaction(() async {
      for (final h in habits) {
        await _writeHabit(h);
      }
    });
  }

  // --- Check-ins -------------------------------------------------------

  /// Adds [delta] check-ins (negative to remove) to [h] on [day]. The count
  /// stays between 0 and the daily target (a count already above a lowered
  /// target can only go down) and future days are ignored.
  /// Returns the resulting count.
  Future<int> checkIn(Habit h, DateTime day, {int delta = 1}) async {
    final d = dateOnly(day);
    final current = countOn(h, d);
    if (d.isAfter(dateOnly(DateTime.now()))) return current;
    final next = max(0, min(current + delta, max(h.dailyTarget, current)));
    if (next == current) return current;
    final counts = _checkins[h.id] ??= {};
    if (next == 0) {
      counts.remove(d);
    } else {
      counts[d] = next;
    }
    notifyListeners();
    await _writeCount(h.id, d, next);
    return next;
  }

  // --- Settings --------------------------------------------------------

  Future<void> setSetting(String key, String value) async {
    if (settings[key] == value) return;
    settings[key] = value;
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingRow(key: key, value: value));
  }
}
