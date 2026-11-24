import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:mehabits/data/habit.dart';

/// 2026-11-24 is a Tuesday.
final tue = DateTime(2026, 11, 24);

DateTime day(int y, int m, int d) => DateTime(y, m, d);

Habit habit({
  DateTime? createdAt,
  int weekdays = Weekdays.all,
  int dailyTarget = 1,
}) => Habit(
  id: 'h',
  name: 'Teste',
  createdAt: createdAt ?? DateTime(2026, 1, 1),
  weekdays: weekdays,
  dailyTarget: dailyTarget,
);

/// Every day from [from] to [to] (inclusive) complete for [h].
DayCounts completeRange(Habit h, DateTime from, DateTime to) => {
  for (var d = from; !d.isAfter(to); d = addDays(d, 1)) d: h.dailyTarget,
};

void main() {
  test('reference dates', () {
    expect(tue.weekday, DateTime.tuesday);
    expect(day(2026, 11, 30).weekday, DateTime.monday);
  });

  group('isScheduled / isComplete', () {
    test('follows the weekday bitmask (Monday = bit 0)', () {
      final h = habit(weekdays: Weekdays.bit(DateTime.monday));
      expect(Weekdays.bit(DateTime.monday), 1);
      expect(Weekdays.bit(DateTime.sunday), 64);
      expect(isScheduled(h, day(2026, 11, 30)), isTrue);
      expect(isScheduled(h, tue), isFalse);
      final workdays = habit(weekdays: Weekdays.workdays);
      expect(isScheduled(workdays, day(2026, 11, 27)), isTrue); // Friday
      expect(isScheduled(workdays, day(2026, 11, 28)), isFalse); // Saturday
    });

    test('is never scheduled before it was created', () {
      final h = habit(createdAt: tue);
      expect(isScheduled(h, addDays(tue, -1)), isFalse);
      expect(isScheduled(h, tue), isTrue);
      // The time of day is irrelevant.
      expect(isScheduled(h, DateTime(2026, 11, 24, 23, 59)), isTrue);
    });

    test('a day is complete once the daily target is reached', () {
      final h = habit(dailyTarget: 8);
      expect(isComplete(h, {tue: 7}, tue), isFalse);
      expect(isComplete(h, {tue: 8}, tue), isTrue);
      expect(isComplete(h, {}, tue), isFalse);
      expect(countOn({tue: 3}, DateTime(2026, 11, 24, 15)), 3);
    });
  });

  group('currentStreak', () {
    test('counts complete days back from today', () {
      final h = habit();
      final counts = completeRange(h, addDays(tue, -4), tue);
      expect(currentStreak(h, counts, today: tue), 5);
    });

    test('an incomplete today does not break it', () {
      final h = habit();
      final counts = completeRange(h, addDays(tue, -4), addDays(tue, -1));
      expect(currentStreak(h, counts, today: tue), 4);
      // Partial progress today is still "in progress".
      final partial = habit(dailyTarget: 8);
      final c2 = {
        ...completeRange(partial, addDays(tue, -2), addDays(tue, -1)),
        tue: 5,
      };
      expect(currentStreak(partial, c2, today: tue), 2);
    });

    test('a missed scheduled day breaks it', () {
      final h = habit();
      final counts = {
        ...completeRange(h, addDays(tue, -10), addDays(tue, -3)),
        ...completeRange(h, addDays(tue, -1), tue),
      };
      expect(currentStreak(h, counts, today: tue), 2);
      expect(currentStreak(h, {}, today: tue), 0);
      // Yesterday missed and today not done yet.
      expect(currentStreak(h, {addDays(tue, -2): 1}, today: tue), 0);
    });

    test('partial days do not count', () {
      final h = habit(dailyTarget: 3);
      final counts = {tue: 3, addDays(tue, -1): 2, addDays(tue, -2): 3};
      expect(currentStreak(h, counts, today: tue), 1);
    });

    test('unscheduled days are skipped, neither counted nor breaking', () {
      final h = habit(weekdays: Weekdays.workdays);
      final monday = day(2026, 11, 30);
      // Thu 26, Fri 27, (weekend 28-29 not done), Mon 30.
      final counts = {day(2026, 11, 26): 1, day(2026, 11, 27): 1, monday: 1};
      expect(currentStreak(h, counts, today: monday), 3);
      // Checking an unscheduled day does not add to it.
      expect(
        currentStreak(h, {...counts, day(2026, 11, 29): 1}, today: monday),
        3,
      );
      // Today is Sunday (unscheduled, not done): Fri and Thu still count.
      expect(currentStreak(h, counts, today: day(2026, 11, 29)), 2);
    });

    test('stops at the day the habit was created', () {
      final h = habit(createdAt: addDays(tue, -3));
      // Check-ins from before createdAt are ignored.
      final counts = completeRange(h, addDays(tue, -20), tue);
      expect(currentStreak(h, counts, today: tue), 4);
      // Created today and already done.
      expect(currentStreak(habit(createdAt: tue), {tue: 1}, today: tue), 1);
      expect(currentStreak(habit(createdAt: tue), {}, today: tue), 0);
    });

    test('crosses week, month and year boundaries', () {
      final h = habit();
      final dec1 = day(2026, 12, 1);
      expect(
        currentStreak(
          h,
          completeRange(h, day(2026, 11, 28), dec1),
          today: dec1,
        ),
        4,
      );
      final jan1 = day(2027, 1, 1);
      expect(
        currentStreak(
          h,
          completeRange(h, day(2026, 12, 30), jan1),
          today: jan1,
        ),
        3,
      );
      // Mon 30 Nov back to Sat 28 Nov crosses the week boundary.
      final mon = day(2026, 11, 30);
      expect(
        currentStreak(h, completeRange(h, day(2026, 11, 28), mon), today: mon),
        3,
      );
    });
  });

  group('bestStreak', () {
    test('finds the longest run', () {
      final h = habit(createdAt: day(2026, 11, 1));
      final counts = {
        ...completeRange(h, day(2026, 11, 1), day(2026, 11, 3)), // 3
        ...completeRange(h, day(2026, 11, 5), day(2026, 11, 9)), // 5
        ...completeRange(h, day(2026, 11, 22), day(2026, 11, 23)), // 2
      };
      expect(bestStreak(h, counts, today: tue), 5);
      expect(currentStreak(h, counts, today: tue), 2);
    });

    test('the current run counts even when today is not done yet', () {
      final h = habit(createdAt: day(2026, 11, 1));
      final counts = completeRange(h, day(2026, 11, 10), addDays(tue, -1));
      expect(bestStreak(h, counts, today: tue), 14);
      expect(currentStreak(h, counts, today: tue), 14);
    });

    test('skips unscheduled days and ignores days before creation', () {
      final h = habit(
        createdAt: day(2026, 11, 16),
        weekdays: Weekdays.workdays,
      );
      // Two full work weeks, nothing on the weekend in between, plus
      // check-ins before the habit existed.
      final counts = {
        ...completeRange(h, day(2026, 11, 1), day(2026, 11, 13)),
        ...completeRange(h, day(2026, 11, 16), day(2026, 11, 20)),
        ...completeRange(h, day(2026, 11, 23), day(2026, 11, 27)),
      };
      expect(bestStreak(h, counts, today: day(2026, 11, 27)), 10);
      expect(bestStreak(h, {}, today: tue), 0);
    });
  });

  group('completionRate', () {
    test('uses the last 30 days for an old habit', () {
      final h = habit(createdAt: day(2026, 1, 1));
      // 15 of the 29 days before today, plus today.
      final counts = {
        ...completeRange(h, addDays(tue, -15), tue),
        // Older than the window: ignored.
        ...completeRange(h, addDays(tue, -60), addDays(tue, -31)),
      };
      expect(completionRate(h, counts, today: tue), closeTo(16 / 30, 1e-9));
    });

    test('starts at createdAt for a habit created mid-period', () {
      final h = habit(createdAt: addDays(tue, -9));
      final counts = completeRange(h, addDays(tue, -4), addDays(tue, -1));
      // 9 scheduled days before today, today still in progress.
      expect(completionRate(h, counts, today: tue), closeTo(4 / 9, 1e-9));
      // Once today is done it counts.
      expect(
        completionRate(h, {...counts, tue: 1}, today: tue),
        closeTo(5 / 10, 1e-9),
      );
    });

    test('only scheduled days count', () {
      final h = habit(
        createdAt: day(2026, 11, 16),
        weekdays: Weekdays.workdays,
      );
      // Today is Saturday 28. Mon 16 – Fri 27: 10 workdays, 8 done (the
      // weekend check-in in between does not count).
      final counts = completeRange(h, day(2026, 11, 16), day(2026, 11, 25));
      expect(
        completionRate(h, counts, today: day(2026, 11, 28)),
        closeTo(8 / 10, 1e-9),
      );
    });

    test('is null until a day was scheduled', () {
      expect(completionRate(habit(createdAt: tue), {}, today: tue), isNull);
      expect(completionRate(habit(createdAt: tue), {tue: 1}, today: tue), 1.0);
      final sundays = habit(
        createdAt: day(2026, 11, 23),
        weekdays: Weekdays.bit(DateTime.sunday),
      );
      expect(completionRate(sundays, {}, today: tue), isNull);
    });
  });

  group('helpers', () {
    test('Weekdays.label', () {
      expect(Weekdays.label(Weekdays.all), 'Todos os dias');
      expect(Weekdays.label(Weekdays.workdays), 'Dias úteis');
      expect(Weekdays.label(Weekdays.weekend), 'Fim de semana');
      expect(Weekdays.label(0), 'Nenhum dia');
      expect(
        Weekdays.label(
          Weekdays.bit(DateTime.monday) |
              Weekdays.bit(DateTime.wednesday) |
              Weekdays.bit(DateTime.friday),
        ),
        'seg, qua, sex',
      );
      expect(Weekdays.toggle(Weekdays.all, DateTime.sunday), 0x3F);
    });

    test('day keys round-trip', () {
      expect(dayKey(day(2026, 3, 7)), '2026-03-07');
      expect(parseDayKey('2026-03-07'), day(2026, 3, 7));
      expect(parseDayKey(dayKey(tue)), tue);
    });

    test('unknown icon names fall back to "Outro"', () {
      expect(HabitIcon.byName('water'), HabitIcon.water);
      expect(HabitIcon.byName('nope'), HabitIcon.other);
    });

    test('copyWith keeps what is not given', () {
      final h = habit(dailyTarget: 3);
      final c = h.copyWith(name: 'Novo', tone: MeTone.tertiary);
      expect(c.name, 'Novo');
      expect(c.tone, MeTone.tertiary);
      expect(c.dailyTarget, 3);
      expect(c.id, h.id);
      expect(c.createdAt, h.createdAt);
    });
  });
}
