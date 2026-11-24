import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:metasks/data/app_store.dart';
import 'package:metasks/data/database.dart';

void main() {
  late Directory dir;
  late File file;
  late AppDatabase db;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('metasks_test');
    file = File('${dir.path}/db.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppStore> open({bool seedDemo = false}) async {
    db = AppDatabase(NativeDatabase(file));
    final store = AppStore(db);
    await store.init(seedDemo: seedDemo);
    return store;
  }

  DateTime inDays(int days) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + days);
  }

  final created = DateTime(2026, 1, 1, 12);

  Task task(
    String id, {
    String listId = inboxId,
    String title = 't',
    DateTime? due,
    Priority priority = Priority.none,
    bool done = false,
    DateTime? doneAt,
    int position = 0,
    List<Subtask> subtasks = const [],
    String notes = '',
  }) => Task(
    id: id,
    listId: listId,
    title: title,
    notes: notes,
    dueDate: due,
    priority: priority,
    done: done,
    doneAt: doneAt,
    createdAt: created,
    position: position,
    subtasks: subtasks,
  );

  test('seeds demo data only on a brand new database', () async {
    final first = await open(seedDemo: true);
    final count = first.tasks.length;
    expect(count, greaterThan(0));
    expect(first.lists.first.id, inboxId);
    expect(first.lists.map((l) => l.name), contains('Trabalho'));
    expect(first.doneToday(), isNotEmpty);
    expect(first.overdue(), isNotEmpty);
    await first.deleteTask(first.tasks.first.id);

    await first.close();
    final second = await open(seedDemo: true);
    expect(second.tasks.length, count - 1);
    await second.close();
  });

  test('a database opened without demo data still has the inbox', () async {
    final s = await open();
    expect(s.tasks, isEmpty);
    expect(s.lists.single.id, inboxId);
    expect(s.inbox.name, 'Caixa de entrada');
    expect(s.inbox.isInbox, isTrue);
    await s.close();
  });

  test('tasks, subtasks and lists survive a restart', () async {
    final a = await open();
    await a.saveList(
      const TaskList(id: 'l', name: 'Casa', tone: MeTone.tertiary, position: 1),
    );
    await a.saveTask(
      task(
        'x',
        listId: 'l',
        title: 'Limpar',
        notes: 'cozinha',
        due: DateTime(2026, 12, 1),
        priority: Priority.medium,
        position: 3,
        subtasks: const [Subtask('Chão'), Subtask('Loiça', done: true)],
      ),
    );
    await a.toggleTask(a.taskById('x')!);

    await a.close();
    final b = await open();
    final l = b.listById('l')!;
    expect(l.name, 'Casa');
    expect(l.tone, MeTone.tertiary);
    expect(l.position, 1);
    final t = b.taskById('x')!;
    expect(t.title, 'Limpar');
    expect(t.notes, 'cozinha');
    expect(t.listId, 'l');
    expect(t.dueDate, DateTime(2026, 12, 1));
    expect(t.priority, Priority.medium);
    expect(t.done, isTrue);
    expect(t.doneAt, isNotNull);
    expect(t.createdAt, created);
    expect(t.position, 3);
    expect(t.subtasks.map((s) => (s.label, s.done)), [
      ('Chão', false),
      ('Loiça', true),
    ]);
    expect(t.subtasksDone, 1);
    await b.close();
  });

  test('saving a task again replaces its subtasks', () async {
    final a = await open();
    final t = task('x', subtasks: const [Subtask('a'), Subtask('b')]);
    await a.saveTask(t);
    await a.saveTask(t.copyWith(subtasks: const [Subtask('c')]));

    await a.close();
    final b = await open();
    expect(b.tasks.single.subtasks.map((s) => s.label), ['c']);
    await b.close();
  });

  test('a task whose list is gone is saved to the inbox', () async {
    final s = await open();
    await s.saveTask(task('x', listId: 'missing'));
    expect(s.tasks.single.listId, inboxId);
    await s.close();
  });

  group('models', () {
    test('copyWith can clear the due date and the completion time', () {
      final t = task('x', due: inDays(1), done: true, doneAt: inDays(0));
      expect(t.copyWith(title: 'u').dueDate, inDays(1));
      expect(t.copyWith(title: 'u').doneAt, inDays(0));
      final cleared = t.copyWith(dueDate: null, doneAt: null, done: false);
      expect(cleared.dueDate, isNull);
      expect(cleared.doneAt, isNull);
      expect(cleared.createdAt, created);
      expect(cleared.id, 'x');
    });

    test('TaskList and Subtask copyWith', () {
      const l = TaskList(id: 'l', name: 'A');
      expect(l.copyWith(name: 'B').name, 'B');
      expect(l.copyWith(tone: MeTone.primary).tone, MeTone.primary);
      expect(l.copyWith(position: 4).position, 4);
      expect(l.copyWith().isInbox, isFalse);
      const s = Subtask('a');
      expect(s.copyWith(done: true).done, isTrue);
      expect(s.copyWith(label: 'b').label, 'b');
    });

    test('matches title, notes and subtasks, ignoring case', () {
      final t = task(
        'x',
        title: 'Proposta',
        notes: 'Cliente novo',
        subtasks: const [Subtask('Anexar portefólio')],
      );
      expect(t.matches(''), isTrue);
      expect(t.matches('PROPOSTA'), isTrue);
      expect(t.matches('cliente'), isTrue);
      expect(t.matches('portefólio'), isTrue);
      expect(t.matches('fatura'), isFalse);
    });

    test('overdue only when pending and due before today', () {
      final now = DateTime(2026, 11, 24, 15);
      expect(task('a', due: DateTime(2026, 11, 23)).isOverdue(now), isTrue);
      expect(task('b', due: DateTime(2026, 11, 24)).isOverdue(now), isFalse);
      expect(task('c').isOverdue(now), isFalse);
      expect(
        task('d', due: DateTime(2026, 11, 1), done: true).isOverdue(now),
        isFalse,
      );
    });
  });

  test('sorts by priority, then due date (undated last), then position', () {
    final tasks = [
      task('none-early', due: DateTime(2026, 1, 1)),
      task('low-undated', priority: Priority.low),
      task('high-late', priority: Priority.high, due: DateTime(2026, 3, 1)),
      task('high-early', priority: Priority.high, due: DateTime(2026, 2, 1)),
      task('low-dated', priority: Priority.low, due: DateTime(2026, 5, 1)),
      task('none-undated-2', position: 2),
      task('none-undated-1', position: 1),
      task('medium', priority: Priority.medium),
    ]..sort(compareTasks);
    expect(tasks.map((t) => t.id), [
      'high-early',
      'high-late',
      'medium',
      'low-dated',
      'low-undated',
      'none-early',
      'none-undated-1',
      'none-undated-2',
    ]);
  });

  group('grouping', () {
    final now = DateTime(2026, 11, 24, 15);

    Future<AppStore> seeded() async {
      final s = await open();
      for (final t in [
        task('late', due: DateTime(2026, 11, 20)),
        task('late-high', due: DateTime(2026, 11, 23), priority: Priority.high),
        task('today', due: DateTime(2026, 11, 24)),
        task('today-done', due: DateTime(2026, 11, 24), done: true),
        task('tomorrow', due: DateTime(2026, 11, 25)),
        task(
          'tomorrow-high',
          due: DateTime(2026, 11, 25),
          priority: Priority.high,
        ),
        task('next-week', due: DateTime(2026, 12, 1)),
        task('undated'),
        task('undated-done', done: true, doneAt: DateTime(2026, 11, 24, 9)),
        task('done-later', done: true, doneAt: DateTime(2026, 11, 24, 11)),
        task('done-yesterday', done: true, doneAt: DateTime(2026, 11, 23, 9)),
      ]) {
        await s.saveTask(t);
      }
      return s;
    }

    test('today: overdue, due today and completed today', () async {
      final s = await seeded();
      expect(s.overdue(now: now).map((t) => t.id), ['late-high', 'late']);
      expect(s.dueToday(now: now).map((t) => t.id), ['today']);
      expect(s.doneToday(now: now).map((t) => t.id), [
        'done-later',
        'undated-done',
      ]);
      await s.close();
    });

    test('upcoming: one group per day from tomorrow, then undated', () async {
      final s = await seeded();
      final groups = s.upcoming(now: now);
      expect(groups.map((g) => g.day), [
        DateTime(2026, 11, 25),
        DateTime(2026, 12, 1),
        null,
      ]);
      expect(groups.first.tasks.map((t) => t.id), [
        'tomorrow-high',
        'tomorrow',
      ]);
      expect(groups.last.tasks.map((t) => t.id), ['undated']);
      await s.close();
    });

    test('defaults to the current day', () async {
      final s = await open();
      await s.saveTask(task('a', due: inDays(-2)));
      await s.saveTask(task('b', due: inDays(0)));
      await s.saveTask(task('c', due: inDays(3)));
      await s.toggleTask(s.taskById('b')!);
      expect(s.overdue().map((t) => t.id), ['a']);
      expect(s.dueToday(), isEmpty);
      expect(s.doneToday().map((t) => t.id), ['b']);
      expect(s.upcoming().single.tasks.single.id, 'c');
      await s.close();
    });
  });

  test('per list: pending, done, counts and next position', () async {
    final s = await open();
    await s.saveList(const TaskList(id: 'l', name: 'L', position: 1));
    expect(s.nextPosition('l'), 0);
    await s.saveTask(task('a', listId: 'l', position: 0));
    await s.saveTask(
      task('b', listId: 'l', position: 4, priority: Priority.high),
    );
    await s.saveTask(
      task('c', listId: 'l', done: true, doneAt: DateTime(2026, 1, 2)),
    );
    await s.saveTask(task('d', listId: 'l', done: true));
    await s.saveTask(task('e'));

    expect(s.pendingIn('l').map((t) => t.id), ['b', 'a']);
    expect(s.doneIn('l').map((t) => t.id), ['c', 'd']);
    expect(s.pendingCount('l'), 2);
    expect(s.pendingCount(inboxId), 1);
    expect(s.nextPosition('l'), 5);
    await s.close();
  });

  test('search finds pending tasks first', () async {
    final s = await open();
    await s.saveTask(task('a', title: 'Pão', done: true));
    await s.saveTask(task('b', title: 'Leite', notes: 'e pão'));
    await s.saveTask(
      task('c', title: 'Compras', subtasks: const [Subtask('Pão')]),
    );
    await s.saveTask(task('d', title: 'Outra'));
    expect(s.search('pão').map((t) => t.id), ['b', 'c', 'a']);
    expect(s.search('  '), isEmpty);
    await s.close();
  });

  group('undo', () {
    test('completing a task stamps doneAt; undo restores it', () async {
      final s = await open();
      await s.saveTask(task('x', due: inDays(0)));

      final previous = await s.toggleTask(s.taskById('x')!);
      expect(previous.done, isFalse);
      expect(s.taskById('x')!.done, isTrue);
      expect(s.taskById('x')!.doneAt, isNotNull);

      await s.saveTask(previous);
      await s.close();
      final b = await open();
      expect(b.taskById('x')!.done, isFalse);
      expect(b.taskById('x')!.doneAt, isNull);

      await b.toggleTask(b.taskById('x')!);
      final reopened = await b.toggleTask(b.taskById('x')!);
      expect(reopened.done, isTrue);
      expect(b.taskById('x')!.done, isFalse);
      await b.close();
    });

    test(
      'deleting a task removes its subtasks; undo brings all back',
      () async {
        final s = await open();
        await s.saveTask(
          task('x', subtasks: const [Subtask('a'), Subtask('b')]),
        );

        final removed = await s.deleteTask('x');
        expect(s.tasks, isEmpty);
        expect(await db.select(db.subtasks).get(), isEmpty);
        expect(await s.deleteTask('x'), isNull);

        await s.saveTask(removed!);
        await s.close();
        final b = await open();
        expect(b.taskById('x')!.subtasks.map((s) => s.label), ['a', 'b']);
        await b.close();
      },
    );

    test('deleting a list moves its tasks to the inbox; undo moves them '
        'back', () async {
      final s = await open();
      await s.saveList(const TaskList(id: 'l', name: 'Casa', position: 1));
      await s.saveTask(task('a', listId: 'l'));
      await s.saveTask(task('b', listId: 'l', done: true));
      await s.saveTask(task('c'));

      final deleted = await s.deleteList('l');
      expect(s.listById('l'), isNull);
      expect(s.tasks.map((t) => t.listId).toSet(), {inboxId});
      await s.close();

      final b = await open();
      expect(b.lists.map((l) => l.id), [inboxId]);
      expect(b.tasks.map((t) => t.listId).toSet(), {inboxId});

      await b.restoreList(deleted!);
      expect(b.listById('l')?.name, 'Casa');
      expect(b.taskById('a')!.listId, 'l');
      expect(b.taskById('c')!.listId, inboxId);
      await b.close();

      final c = await open();
      expect(c.lists.map((l) => l.id), [inboxId, 'l']);
      expect(c.pendingIn('l').single.id, 'a');
      expect(c.doneIn('l').single.id, 'b');
      await c.close();
    });

    test('the inbox can be renamed but never deleted', () async {
      final s = await open();
      expect(await s.deleteList(inboxId), isNull);
      expect(await s.deleteList('missing'), isNull);
      await s.saveList(s.inbox.copyWith(name: 'Entrada'));
      await s.close();
      final b = await open();
      expect(b.inbox.name, 'Entrada');
      expect(b.lists, hasLength(1));
      await b.close();
    });
  });

  test('new lists go after the existing ones', () async {
    final s = await open();
    expect(s.nextListPosition, 1);
    await s.saveList(
      TaskList(id: 'b', name: 'B', position: s.nextListPosition),
    );
    await s.saveList(
      TaskList(id: 'a', name: 'A', position: s.nextListPosition),
    );
    expect(s.lists.map((l) => l.id), [inboxId, 'b', 'a']);
    await s.close();
  });

  test('settings persist', () async {
    final a = await open();
    await a.setSetting('appearance.mode', 'dark');
    await a.setSetting('appearance.mode', 'dark');
    await a.close();
    final b = await open();
    expect(b.settings['appearance.mode'], 'dark');
    await b.close();
  });

  test('ids carry their prefix', () {
    expect(newId('t'), startsWith('t'));
  });
}
