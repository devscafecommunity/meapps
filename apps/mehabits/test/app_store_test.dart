import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:mehabits/data/app_store.dart';
import 'package:mehabits/data/database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mehabits_test');
    file = File('${dir.path}/db.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppStore> open({bool seedDemo = false}) async {
    final store = AppStore(AppDatabase(NativeDatabase(file)));
    await store.init(seedDemo: seedDemo);
    return store;
  }

  final today = dateOnly(DateTime.now());
  DateTime ago(int days) => addDays(today, -days);

  Habit water({String id = 'w', DateTime? createdAt}) => Habit(
    id: id,
    name: 'Beber água',
    icon: HabitIcon.water,
    dailyTarget: 8,
    createdAt: createdAt ?? ago(10),
  );

  group('demo seed', () {
    test('seeds plausible demo data on a brand new database', () async {
      final s = await open(seedDemo: true);
      expect(s.habits.length, inInclusiveRange(4, 5));
      expect(s.habits.map((h) => h.name), contains('Beber água'));
      expect(
        s.habits.any((h) => h.weekdays == Weekdays.workdays),
        isTrue,
        reason: 'a habit scheduled on weekdays only',
      );
      for (final h in s.habits) {
        expect(s.checkinsOf(h.id), isNotEmpty);
        expect(s.bestStreak(h), greaterThan(0));
        expect(s.checkinsOf(h.id).keys.every((d) => !d.isAfter(today)), isTrue);
      }
      expect(s.habits.map((h) => h.position), [0, 1, 2, 3, 4]);
      await s.close();
    });

    test('seeds only once, even after every habit was deleted', () async {
      final first = await open(seedDemo: true);
      expect(first.habits, isNotEmpty);
      for (final h in [...first.habits]) {
        await first.deleteHabit(h.id);
      }
      await first.close();

      final second = await open(seedDemo: true);
      expect(second.habits, isEmpty);
      await second.close();
    });

    test('seedDemo: false starts empty', () async {
      final s = await open();
      expect(s.habits, isEmpty);
      await s.close();
    });
  });

  test('habits and check-ins survive a restart', () async {
    final a = await open();
    await a.saveHabit(
      Habit(
        id: 'x',
        name: 'Meditar',
        icon: HabitIcon.meditate,
        tone: MeTone.tertiary,
        weekdays: Weekdays.workdays,
        dailyTarget: 2,
        createdAt: DateTime(2026, 11, 2, 15, 30),
      ),
    );
    final h = a.habitById('x')!;
    expect(h.createdAt, DateTime(2026, 11, 2), reason: 'stored as a date');
    await a.checkIn(h, ago(1));
    await a.checkIn(h, ago(1));
    await a.checkIn(h, ago(2));
    await a.setSetting('appearance.mode', 'dark');

    await a.close();
    final b = await open();
    final x = b.habitById('x')!;
    expect(x.name, 'Meditar');
    expect(x.icon, HabitIcon.meditate);
    expect(x.tone, MeTone.tertiary);
    expect(x.weekdays, Weekdays.workdays);
    expect(x.dailyTarget, 2);
    expect(x.createdAt, DateTime(2026, 11, 2));
    expect(x.archived, isFalse);
    expect(b.countOn(x, ago(1)), 2);
    expect(b.countOn(x, ago(2)), 1);
    expect(b.countOn(x, today), 0);
    expect(b.settings['appearance.mode'], 'dark');
    await b.close();
  });

  group('check-ins', () {
    test('stay between 0 and the daily target', () async {
      final s = await open();
      final h = habit1();
      await s.saveHabit(h);
      for (var i = 0; i < 3; i++) {
        await s.checkIn(h, today);
      }
      expect(s.countOn(h, today), 2);
      expect(s.isComplete(h, today), isTrue);
      expect(await s.checkIn(h, today, delta: -5), 0);
      expect(s.checkinsOf(h.id), isEmpty);
      expect(await s.checkIn(h, today, delta: -1), 0);
      await s.close();
    });

    test('a removed check-in is gone after a restart', () async {
      final a = await open();
      final h = water();
      await a.saveHabit(h);
      await a.checkIn(h, ago(1));
      await a.checkIn(h, ago(1), delta: -1);
      await a.close();
      final b = await open();
      expect(b.checkinsOf('w'), isEmpty);
      await b.close();
    });

    test('future days are ignored', () async {
      final s = await open();
      final h = water();
      await s.saveHabit(h);
      expect(await s.checkIn(h, addDays(today, 1)), 0);
      expect(s.checkinsOf(h.id), isEmpty);
      await s.close();
    });

    test('a count above a lowered target can only go down', () async {
      final s = await open();
      final h = water();
      await s.saveHabit(h);
      for (var i = 0; i < 6; i++) {
        await s.checkIn(h, today);
      }
      final lowered = h.copyWith(dailyTarget: 4);
      await s.saveHabit(lowered);
      expect(await s.checkIn(lowered, today), 6);
      expect(await s.checkIn(lowered, today, delta: -1), 5);
      await s.close();
    });

    test('editing a habit keeps its check-ins', () async {
      final a = await open();
      final h = water();
      await a.saveHabit(h);
      await a.checkIn(h, ago(1));
      await a.saveHabit(h.copyWith(name: 'Água', icon: HabitIcon.health));
      await a.close();
      final b = await open();
      expect(b.habitById('w')?.name, 'Água');
      expect(b.countOn(b.habitById('w')!, ago(1)), 1);
      await b.close();
    });
  });

  test('delete removes the check-ins; undo restores everything', () async {
    final a = await open();
    final h = water();
    await a.saveHabit(h);
    await a.saveHabit(water(id: 'other'));
    await a.checkIn(h, ago(1));
    await a.checkIn(h, ago(3));
    await a.checkIn(h, ago(3));

    final deleted = await a.deleteHabit('w');
    expect(deleted?.habit.name, 'Beber água');
    expect(deleted?.checkins, {ago(1): 1, ago(3): 2});
    expect(a.habitById('w'), isNull);
    expect(a.checkinsOf('w'), isEmpty);
    expect(await a.deleteHabit('w'), isNull);
    await a.close();

    // Cascade: nothing left on disk for that habit.
    final raw = AppDatabase(NativeDatabase(file));
    expect(await raw.select(raw.checkins).get(), isEmpty);
    await raw.close();

    final b = await open();
    expect(b.habits.map((h) => h.id), ['other']);
    await b.restoreHabit(deleted!);
    expect(b.habits.map((h) => h.id), ['w', 'other']);
    await b.close();

    final c = await open();
    final restored = c.habitById('w')!;
    expect(c.countOn(restored, ago(1)), 1);
    expect(c.countOn(restored, ago(3)), 2);
    expect(c.habits.map((h) => h.id), ['w', 'other'], reason: 'same place');
    await c.close();
  });

  test('archived habits are kept but hidden from the day lists', () async {
    final a = await open();
    final h = water();
    await a.saveHabit(h);
    await a.checkIn(h, ago(1));
    await a.setArchived('w', true);
    expect(a.activeHabits, isEmpty);
    expect(a.archivedHabits.single.id, 'w');
    expect(a.habitsOn(today).scheduled, isEmpty);
    await a.setArchived('nope', true);
    await a.close();

    final b = await open();
    expect(b.habitById('w')?.archived, isTrue);
    expect(b.countOn(b.habitById('w')!, ago(1)), 1);
    await b.setArchived('w', false);
    expect(b.activeHabits.single.id, 'w');
    await b.close();
  });

  test('new habits go last; moveHabit reorders and persists', () async {
    final a = await open();
    for (final id in ['a', 'b', 'c', 'd']) {
      await a.saveHabit(water(id: id));
    }
    expect(a.habits.map((h) => h.position), [0, 1, 2, 3]);
    await a.setArchived('b', true);
    // Active: a c d. Move "d" to the top.
    await a.moveHabit(2, 0);
    expect(a.activeHabits.map((h) => h.id), ['d', 'a', 'c']);
    await a.moveHabit(0, 9);
    expect(a.activeHabits.map((h) => h.id), ['a', 'c', 'd']);
    await a.moveHabit(5, 0);
    await a.moveHabit(1, 1);
    await a.close();

    final b = await open();
    expect(b.habits.map((h) => h.id), ['a', 'c', 'd', 'b']);
    expect(b.archivedHabits.single.id, 'b');
    await b.close();
  });

  test('habitsOn splits scheduled and unscheduled habits', () async {
    final s = await open();
    await s.saveHabit(water(id: 'daily'));
    final notToday = Weekdays.all ^ Weekdays.bit(today.weekday);
    await s.saveHabit(water(id: 'other-days').copyWith(weekdays: notToday));
    await s.saveHabit(water(id: 'new', createdAt: today));
    final (:scheduled, :unscheduled) = s.habitsOn(today);
    expect(scheduled.map((h) => h.id), ['daily', 'new']);
    expect(unscheduled.map((h) => h.id), ['other-days']);
    // Not shown before it existed.
    expect(
      s.habitsOn(ago(1)).scheduled.map((h) => h.id),
      isNot(contains('new')),
    );
    expect(
      s.habitsOn(ago(1)).unscheduled.map((h) => h.id),
      isNot(contains('new')),
    );
    await s.close();
  });

  test('stats through the store', () async {
    final s = await open();
    final h = habit1(createdAt: ago(5));
    await s.saveHabit(h);
    for (final d in [ago(3), ago(2), ago(1)]) {
      await s.checkIn(h, d, delta: 2);
    }
    expect(s.currentStreak(h), 3);
    expect(s.bestStreak(h), 3);
    // 5 days before today, 3 complete; today not done yet.
    expect(s.completionRate(h), closeTo(3 / 5, 1e-9));
    expect(s.currentStreak(h, today: ago(2)), 2);
    await s.close();
  });

  test('unknown stored values fall back to defaults', () async {
    final raw = AppDatabase(NativeDatabase(file));
    await raw
        .into(raw.habits)
        .insert(
          HabitsCompanion.insert(
            id: 'z',
            name: 'Futuro',
            icon: 'icon_from_a_newer_version',
            createdAt: '2026-11-01',
            tone: const Value(42),
            dailyTarget: const Value(0),
          ),
        );
    await raw.close();
    final s = await open();
    final z = s.habitById('z')!;
    expect(z.icon, HabitIcon.other);
    expect(z.tone, MeTone.plain);
    expect(z.dailyTarget, 1);
    expect(z.weekdays, Weekdays.all);
    await s.close();
  });
}

Habit habit1({DateTime? createdAt}) => Habit(
  id: 'two',
  name: 'Duas vezes',
  dailyTarget: 2,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
);
