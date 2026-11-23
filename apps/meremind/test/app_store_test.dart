import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:meremind/data/app_store.dart';
import 'package:meremind/data/database.dart';
import 'package:meremind/services/reminder_notifier.dart';

import 'fakes.dart';

void main() {
  late Directory dir;
  late File file;
  late FakeNotifier notifier;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('meremind_test');
    file = File('${dir.path}/db.sqlite');
    notifier = FakeNotifier();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppStore> open({bool seedDemo = false}) async {
    final store = AppStore(
      AppDatabase(NativeDatabase(file)),
      notifier: notifier,
    );
    await store.init(seedDemo: seedDemo);
    return store;
  }

  DateTime inDays(int days, [int hour = 9]) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + days, hour);
  }

  test('seeds demo data only on a brand new database', () async {
    final first = await open(seedDemo: true);
    final count = first.notes.length;
    expect(count, greaterThan(0));
    await first.saveNote(first.notes.first.copyWith(title: 'Alterada'));

    await first.close();
    final second = await open(seedDemo: true);
    expect(second.notes.length, count);
    await second.close();
  });

  test('notes, checklists and reminders survive a restart', () async {
    final a = await open();
    await a.saveNote(
      Note(
        id: 'x',
        title: 'Compras',
        body: 'corpo',
        tag: 'Casa',
        tone: MeTone.secondary,
        archived: true,
        checklist: [ChecklistItem('Pão'), ChecklistItem('Leite', done: true)],
      ),
    );
    final r = Reminder(id: 'r', title: 'Ligar', when: DateTime(2026, 12, 1, 9));
    await a.saveReminder(r);
    await a.toggle(r);

    await a.close();
    final b = await open();
    final n = b.noteById('x')!;
    expect(n.title, 'Compras');
    expect(n.tag, 'Casa');
    expect(n.tone, MeTone.secondary);
    expect(n.archived, isTrue);
    expect(n.updatedAt, isNotNull);
    expect(n.checklist.map((c) => (c.text, c.done)), [
      ('Pão', false),
      ('Leite', true),
    ]);
    expect(b.reminders.single.done, isTrue);
    expect(b.reminders.single.when, DateTime(2026, 12, 1, 9));
    await b.close();
  });

  test('saving a note again replaces its checklist', () async {
    final a = await open();
    final n = Note(id: 'x', title: 't', checklist: [ChecklistItem('a')]);
    await a.saveNote(n);
    await a.saveNote(n.copyWith(checklist: [ChecklistItem('b')]));

    await a.close();
    final b = await open();
    expect(b.notes.single.checklist.map((c) => c.text), ['b']);
    await b.close();
  });

  test('copyWith can clear the tag', () {
    const n = Note(id: 'x', title: 't', tag: 'Casa');
    expect(n.copyWith(title: 'u').tag, 'Casa');
    expect(n.copyWith(tag: null).tag, isNull);
  });

  group('reminders', () {
    test(
      'completing a one-off reminder marks it done; undo restores',
      () async {
        final s = await open();
        final r = Reminder(id: 'r', title: 'Ligar', when: inDays(1));
        await s.saveReminder(r);
        expect(notifier.scheduled.keys, contains('r'));

        final previous = await s.toggle(r);
        expect(s.reminders.single.done, isTrue);
        expect(notifier.scheduled.keys, isNot(contains('r')));

        await s.saveReminder(previous);
        expect(s.reminders.single.done, isFalse);
        expect(notifier.scheduled.keys, contains('r'));
        await s.close();
      },
    );

    test('completing a repeating reminder moves it to the next future '
        'occurrence', () async {
      final s = await open();
      final r = Reminder(
        id: 'r',
        title: 'Vitaminas',
        when: inDays(-3, 8),
        repeat: Repeat.daily,
      );
      await s.saveReminder(r);
      await s.toggle(r);

      final next = s.reminders.single;
      expect(next.done, isFalse);
      expect(next.when.isAfter(DateTime.now()), isTrue);
      expect(next.when.hour, 8);
      expect(
        next.when.difference(DateTime.now()),
        lessThanOrEqualTo(const Duration(days: 1)),
      );
      expect(notifier.scheduled['r'], next.when);
      await s.close();
    });

    test('Repeat.after clamps months and years', () {
      expect(
        Repeat.monthly.after(DateTime(2026, 1, 31, 10)),
        DateTime(2026, 2, 28, 10),
      );
      expect(
        Repeat.yearly.after(DateTime(2028, 2, 29, 9)),
        DateTime(2029, 2, 28, 9),
      );
      expect(Repeat.weekly.after(DateTime(2026, 12, 28)), DateTime(2027, 1, 4));
    });

    test('deleting cancels the notification', () async {
      final s = await open();
      await s.saveReminder(Reminder(id: 'r', title: 'x', when: inDays(2)));
      final removed = await s.deleteReminder('r');
      expect(removed?.title, 'x');
      expect(s.reminders, isEmpty);
      expect(notifier.scheduled, isEmpty);
      await s.close();
    });

    test('past reminders are not scheduled', () async {
      final s = await open();
      await s.saveReminder(Reminder(id: 'r', title: 'x', when: inDays(-1)));
      expect(notifier.scheduled, isEmpty);
      await s.close();
    });

    test('init re-syncs every pending notification', () async {
      final a = await open();
      await a.saveReminder(Reminder(id: 'a', title: 'a', when: inDays(1)));
      await a.saveReminder(
        Reminder(id: 'b', title: 'b', when: inDays(2), done: true),
      );
      await a.close();

      notifier = FakeNotifier();
      final b = await open();
      expect(notifier.initialized, isTrue);
      expect(notifier.scheduled.keys, ['a']);
      await b.close();
    });

    test('a failing notifier never breaks persistence', () async {
      notifier = FakeNotifier(fail: true);
      final s = await open();
      await s.saveReminder(Reminder(id: 'r', title: 'x', when: inDays(1)));
      expect(s.reminders, hasLength(1));
      await s.close();
    });
  });

  group('note reminders', () {
    test('set, move and remove the reminder of a note', () async {
      final s = await open();
      const n = Note(id: 'n', title: 'Dentista');
      await s.saveNote(n);
      expect(s.reminderFor('n'), isNull);

      await s.setNoteReminder(n, inDays(1));
      expect(s.reminderFor('n')?.when, inDays(1));
      expect(s.reminderFor('n')?.title, 'Dentista');

      await s.setNoteReminder(n, inDays(2));
      expect(s.reminders, hasLength(1));
      expect(s.reminderFor('n')?.when, inDays(2));

      await s.setNoteReminder(n, null);
      expect(s.reminders, isEmpty);
      await s.close();
    });

    test('renaming a note renames its reminders', () async {
      final s = await open();
      const n = Note(id: 'n', title: 'Antigo');
      await s.saveNote(n);
      await s.setNoteReminder(n, inDays(1));
      await s.saveNote(n.copyWith(title: 'Novo'));
      expect(s.reminders.single.title, 'Novo');
      expect(notifier.titles[s.reminders.single.id], 'Novo');
      await s.close();
    });

    test(
      'deleting a note removes its reminders; restore brings all back',
      () async {
        final s = await open();
        final n = Note(
          id: 'n',
          title: 'Lista',
          checklist: [ChecklistItem('a')],
        );
        await s.saveNote(n);
        await s.setNoteReminder(n, inDays(1));

        final deleted = await s.deleteNote('n');
        expect(s.notes, isEmpty);
        expect(s.reminders, isEmpty);
        expect(notifier.scheduled, isEmpty);

        await s.restoreNote(deleted!);
        await s.close();
        final b = await open();
        expect(b.noteById('n')?.checklist.single.text, 'a');
        expect(b.reminderFor('n'), isNotNull);
        await b.close();
      },
    );
  });

  group('filterNotes', () {
    test('filters by archive, tag and query; newest edit first', () async {
      final s = await open();
      await s.saveNote(const Note(id: 'a', title: 'Bolo', tag: 'Casa'));
      await s.saveNote(
        Note(id: 'b', title: 'Compras', checklist: [ChecklistItem('Farinha')]),
      );
      await s.saveNote(
        const Note(id: 'c', title: 'Velha', body: 'bolo', archived: true),
      );

      expect(s.filterNotes().map((n) => n.id), ['b', 'a']);
      expect(s.filterNotes(archived: true).map((n) => n.id), ['c']);
      expect(s.filterNotes(tag: 'Casa').map((n) => n.id), ['a']);
      expect(s.filterNotes(query: 'FARINHA').map((n) => n.id), ['b']);
      expect(s.filterNotes(query: 'bolo').map((n) => n.id), ['a']);
      expect(s.tags, ['Casa']);
      await s.close();
    });
  });

  test('settings persist', () async {
    final a = await open();
    await a.setSetting('appearance.mode', 'dark');
    await a.close();
    final b = await open();
    expect(b.settings['appearance.mode'], 'dark');
    await b.close();
  });

  test('notification ids are stable and positive', () {
    expect(notificationIdFor('r1'), notificationIdFor('r1'));
    expect(notificationIdFor('r1'), isNot(notificationIdFor('r2')));
    expect(notificationIdFor('r1'), greaterThanOrEqualTo(0));
  });
}
