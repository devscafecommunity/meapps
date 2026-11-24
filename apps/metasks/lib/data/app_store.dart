import 'dart:collection';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart';
import 'package:meapps_ui/meapps_ui.dart';

import 'database.dart';

/// Fixed id of the built-in list. It can be renamed but never deleted.
const inboxId = 'inbox';
const inboxName = 'Caixa de entrada';

const _unset = Object();

enum Priority {
  none('Nenhuma'),
  low('Baixa'),
  medium('Média'),
  high('Alta');

  const Priority(this.label);
  final String label;
}

@immutable
class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    this.tone = MeTone.plain,
    this.position = 0,
  });

  final String id;
  final String name;
  final MeTone tone;
  final int position;

  bool get isInbox => id == inboxId;

  TaskList copyWith({String? name, MeTone? tone, int? position}) => TaskList(
    id: id,
    name: name ?? this.name,
    tone: tone ?? this.tone,
    position: position ?? this.position,
  );
}

@immutable
class Subtask {
  const Subtask(this.label, {this.done = false});

  final String label;
  final bool done;

  Subtask copyWith({String? label, bool? done}) =>
      Subtask(label ?? this.label, done: done ?? this.done);
}

@immutable
class Task {
  const Task({
    required this.id,
    required this.listId,
    required this.title,
    required this.createdAt,
    this.notes = '',
    this.dueDate,
    this.priority = Priority.none,
    this.done = false,
    this.doneAt,
    this.position = 0,
    this.subtasks = const [],
  });

  final String id;
  final String listId;
  final String title;
  final String notes;

  /// Day only (local midnight).
  final DateTime? dueDate;
  final Priority priority;
  final bool done;
  final DateTime? doneAt;
  final DateTime createdAt;

  /// Order of creation inside its list; the last sort key.
  final int position;
  final List<Subtask> subtasks;

  int get subtasksDone => subtasks.where((s) => s.done).length;

  /// Pending and due before the day of [now].
  bool isOverdue([DateTime? now]) =>
      !done &&
      dueDate != null &&
      dueDate!.isBefore(dateOnly(now ?? DateTime.now()));

  /// [dueDate] and [doneAt] accept `null` to clear them; omit them to keep
  /// the current value.
  Task copyWith({
    String? listId,
    String? title,
    String? notes,
    Object? dueDate = _unset,
    Priority? priority,
    bool? done,
    Object? doneAt = _unset,
    int? position,
    List<Subtask>? subtasks,
  }) => Task(
    id: id,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
    priority: priority ?? this.priority,
    done: done ?? this.done,
    doneAt: identical(doneAt, _unset) ? this.doneAt : doneAt as DateTime?,
    createdAt: createdAt,
    position: position ?? this.position,
    subtasks: subtasks ?? this.subtasks,
  );

  /// Case-insensitive match on title, notes and subtasks.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String s) => s.toLowerCase().contains(q);
    return has(title) || has(notes) || subtasks.any((s) => has(s.label));
  }
}

/// Priority high to low, then due date (undated last), then position.
int compareTasks(Task a, Task b) {
  final p = b.priority.index.compareTo(a.priority.index);
  if (p != 0) return p;
  final da = a.dueDate, db = b.dueDate;
  if (da != null && db != null && da != db) return da.compareTo(db);
  if (da != null && db == null) return -1;
  if (da == null && db != null) return 1;
  final pos = a.position.compareTo(b.position);
  if (pos != 0) return pos;
  return a.createdAt.compareTo(b.createdAt);
}

/// Pending tasks due on [day]; `null` groups the tasks without a date.
typedef DayGroup = ({DateTime? day, List<Task> tasks});

/// What [AppStore.deleteList] changed, so it can be put back.
typedef DeletedList = ({TaskList list, List<String> movedTaskIds});

String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}';

DateTime _day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset);
}

// --- Demo seed (first launch only) -------------------------------------

const _demoLists = [
  TaskList(id: inboxId, name: inboxName),
  TaskList(id: 'pessoal', name: 'Pessoal', tone: MeTone.primary, position: 1),
  TaskList(
    id: 'trabalho',
    name: 'Trabalho',
    tone: MeTone.secondary,
    position: 2,
  ),
  TaskList(id: 'casa', name: 'Casa', tone: MeTone.tertiary, position: 3),
];

/// Dates are relative to "now" so the demo data always looks alive.
List<Task> _demoTasks() {
  final now = DateTime.now();
  return [
    Task(
      id: 't1',
      listId: 'casa',
      title: 'Pagar a conta da luz',
      dueDate: _day(-1),
      priority: Priority.high,
      createdAt: now,
    ),
    Task(
      id: 't2',
      listId: 'trabalho',
      title: 'Enviar proposta ao cliente',
      notes: 'Confirmar prazos com a equipa antes de enviar.',
      dueDate: _day(0),
      priority: Priority.high,
      createdAt: now,
      subtasks: const [
        Subtask('Rever orçamento', done: true),
        Subtask('Anexar portefólio'),
        Subtask('Enviar email'),
      ],
    ),
    Task(
      id: 't3',
      listId: inboxId,
      title: 'Comprar pão',
      dueDate: _day(0),
      createdAt: now,
    ),
    Task(
      id: 't4',
      listId: 'pessoal',
      title: 'Marcar consulta no dentista',
      dueDate: _day(0),
      priority: Priority.medium,
      createdAt: now,
      position: 1,
    ),
    Task(
      id: 't5',
      listId: 'pessoal',
      title: 'Ir ao ginásio',
      dueDate: _day(0),
      done: true,
      doneAt: now,
      createdAt: now,
      position: 2,
    ),
    Task(
      id: 't6',
      listId: 'trabalho',
      title: 'Preparar apresentação',
      notes: 'Slides para a reunião de equipa.',
      dueDate: _day(1),
      priority: Priority.medium,
      createdAt: now,
      position: 1,
      subtasks: const [
        Subtask('Recolher números do trimestre'),
        Subtask('Fazer gráficos'),
      ],
    ),
    Task(
      id: 't7',
      listId: 'casa',
      title: 'Regar as plantas',
      dueDate: _day(2),
      priority: Priority.low,
      createdAt: now,
      position: 1,
    ),
    Task(
      id: 't8',
      listId: 'pessoal',
      title: 'Renovar o cartão de cidadão',
      dueDate: _day(7),
      createdAt: now,
      position: 3,
    ),
    Task(
      id: 't9',
      listId: 'pessoal',
      title: 'Ler "O Nome da Rosa"',
      priority: Priority.low,
      createdAt: now,
      position: 4,
    ),
    Task(
      id: 't10',
      listId: 'casa',
      title: 'Arrumar a garagem',
      createdAt: now,
      position: 2,
      subtasks: const [
        Subtask('Separar o que é para dar'),
        Subtask('Levar caixas ao ecoponto'),
      ],
    ),
    Task(
      id: 't11',
      listId: inboxId,
      title: 'Ideias para o blogue',
      notes: 'Rotinas da manhã, apps locais sem conta, receitas rápidas.',
      createdAt: now,
      position: 1,
    ),
    Task(
      id: 't12',
      listId: 'trabalho',
      title: 'Responder a emails',
      dueDate: _day(-1),
      done: true,
      doneAt: now.subtract(const Duration(days: 1)),
      createdAt: now,
      position: 2,
    ),
  ];
}

// --- Store -------------------------------------------------------------

/// Single source of truth for the UI. Keeps the data in memory for
/// synchronous reads and writes every change through to SQLite (Drift).
class AppStore extends ChangeNotifier {
  AppStore(this._db);

  final AppDatabase _db;

  /// Sorted by position; the inbox is always present.
  List<TaskList> lists = [];
  List<Task> tasks = [];
  Map<String, String> settings = {};

  /// Loads from disk; seeds demo data when the database is brand new.
  Future<void> init({bool seedDemo = true}) async {
    if (seedDemo &&
        await _db.select(_db.taskLists).get().then((r) => r.isEmpty) &&
        await _db.select(_db.tasks).get().then((r) => r.isEmpty)) {
      for (final l in _demoLists) {
        await _writeList(l);
      }
      for (final t in _demoTasks()) {
        await _writeTask(t);
      }
    }
    final inbox = await (_db.select(
      _db.taskLists,
    )..where((t) => t.id.equals(inboxId))).getSingleOrNull();
    if (inbox == null) {
      await _writeList(const TaskList(id: inboxId, name: inboxName));
    }
    await _load();
  }

  Future<void> _load() async {
    lists = [
      for (final row in await _db.select(_db.taskLists).get())
        TaskList(
          id: row.id,
          name: row.name,
          tone: MeTone.values[row.tone],
          position: row.position,
        ),
    ]..sort((a, b) => a.position.compareTo(b.position));
    final subs = await (_db.select(
      _db.subtasks,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    tasks = [
      for (final row in await _db.select(_db.tasks).get())
        Task(
          id: row.id,
          listId: row.listId,
          title: row.title,
          notes: row.notes,
          dueDate: row.dueDate,
          priority: Priority.values[row.priority],
          done: row.done,
          doneAt: row.doneAt,
          createdAt: row.createdAt,
          position: row.position,
          subtasks: [
            for (final s in subs.where((s) => s.taskId == row.id))
              Subtask(s.label, done: s.done),
          ],
        ),
    ];
    settings = {
      for (final row in await _db.select(_db.settings).get())
        row.key: row.value,
    };
    notifyListeners();
  }

  Future<void> _writeList(TaskList l) => _db
      .into(_db.taskLists)
      .insertOnConflictUpdate(
        TaskListsCompanion(
          id: Value(l.id),
          name: Value(l.name),
          tone: Value(l.tone.index),
          position: Value(l.position),
        ),
      );

  Future<void> _writeTask(Task t) => _db.transaction(() async {
    await _db
        .into(_db.tasks)
        .insertOnConflictUpdate(
          TasksCompanion(
            id: Value(t.id),
            listId: Value(t.listId),
            title: Value(t.title),
            notes: Value(t.notes),
            dueDate: Value(t.dueDate),
            priority: Value(t.priority.index),
            done: Value(t.done),
            doneAt: Value(t.doneAt),
            createdAt: Value(t.createdAt),
            position: Value(t.position),
          ),
        );
    await (_db.delete(_db.subtasks)..where((s) => s.taskId.equals(t.id))).go();
    for (var i = 0; i < t.subtasks.length; i++) {
      await _db
          .into(_db.subtasks)
          .insert(
            SubtasksCompanion.insert(
              taskId: t.id,
              position: i,
              label: t.subtasks[i].label,
              done: Value(t.subtasks[i].done),
            ),
          );
    }
  });

  Future<void> close() => _db.close();

  // --- Queries ---------------------------------------------------------

  TaskList? listById(String? id) {
    for (final l in lists) {
      if (l.id == id) return l;
    }
    return null;
  }

  TaskList get inbox => listById(inboxId)!;

  Task? taskById(String? id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  int pendingCount(String listId) =>
      tasks.where((t) => t.listId == listId && !t.done).length;

  /// Position for a new task appended to [listId].
  int nextPosition(String listId) =>
      tasks
          .where((t) => t.listId == listId)
          .fold(-1, (m, t) => t.position > m ? t.position : m) +
      1;

  List<Task> _pending(bool Function(Task t) test) =>
      tasks.where((t) => !t.done && test(t)).toList()..sort(compareTasks);

  /// Pending tasks due before today.
  List<Task> overdue({DateTime? now}) => _pending((t) => t.isOverdue(now));

  /// Pending tasks due today.
  List<Task> dueToday({DateTime? now}) {
    final today = now ?? DateTime.now();
    return _pending((t) => t.dueDate != null && isSameDay(t.dueDate!, today));
  }

  /// Tasks completed today, most recent first.
  List<Task> doneToday({DateTime? now}) {
    final today = now ?? DateTime.now();
    return tasks
        .where((t) => t.done && t.doneAt != null && isSameDay(t.doneAt!, today))
        .toList()
      ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
  }

  /// Pending tasks from tomorrow on, one group per day, then the undated.
  List<DayGroup> upcoming({DateTime? now}) {
    final n = now ?? DateTime.now();
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    final byDay = SplayTreeMap<DateTime, List<Task>>();
    final undated = <Task>[];
    for (final t in _pending((_) => true)) {
      final due = t.dueDate;
      if (due == null) {
        undated.add(t);
      } else if (!due.isBefore(tomorrow)) {
        byDay.putIfAbsent(dateOnly(due), () => []).add(t);
      }
    }
    return [
      for (final e in byDay.entries) (day: e.key, tasks: e.value),
      if (undated.isNotEmpty) (day: null, tasks: undated),
    ];
  }

  List<Task> pendingIn(String listId) => _pending((t) => t.listId == listId);

  /// Completed tasks of a list, most recent first.
  List<Task> doneIn(String listId) =>
      tasks.where((t) => t.listId == listId && t.done).toList()..sort(
        (a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt),
      );

  /// Matches on title, notes and subtasks; pending first.
  List<Task> search(String query) {
    if (query.trim().isEmpty) return [];
    final found = tasks.where((t) => t.matches(query)).toList();
    return [
      ...found.where((t) => !t.done).toList()..sort(compareTasks),
      ...found.where((t) => t.done).toList()..sort(compareTasks),
    ];
  }

  // --- Tasks -----------------------------------------------------------

  void _replaceTask(Task t) {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
  }

  /// Inserts or replaces a task (matched by id). A task whose list no
  /// longer exists lands in the inbox.
  Future<void> saveTask(Task t) async {
    final task = listById(t.listId) == null ? t.copyWith(listId: inboxId) : t;
    _replaceTask(task);
    notifyListeners();
    await _writeTask(task);
  }

  /// Removes a task and its subtasks. Returns it so the UI can offer
  /// "undo" through [saveTask].
  Future<Task?> deleteTask(String id) async {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return null;
    final removed = tasks.removeAt(i);
    notifyListeners();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
    return removed;
  }

  /// Marks a task done (stamping [Task.doneAt]) or pending again.
  /// Returns the previous state, for "undo" via [saveTask].
  Future<Task> toggleTask(Task t) async {
    final current = taskById(t.id) ?? t;
    await saveTask(
      current.done
          ? current.copyWith(done: false, doneAt: null)
          : current.copyWith(done: true, doneAt: DateTime.now()),
    );
    return current;
  }

  // --- Lists -----------------------------------------------------------

  /// Position for a new list, after every existing one.
  int get nextListPosition =>
      lists.fold(-1, (m, l) => l.position > m ? l.position : m) + 1;

  /// Inserts or replaces a list (matched by id).
  Future<void> saveList(TaskList l) async {
    final i = lists.indexWhere((e) => e.id == l.id);
    if (i >= 0) {
      lists[i] = l;
    } else {
      lists.add(l);
    }
    lists.sort((a, b) => a.position.compareTo(b.position));
    notifyListeners();
    await _writeList(l);
  }

  /// Deletes a list and moves its tasks to the inbox, which itself can't be
  /// deleted. Returns what changed, for "undo" through [restoreList].
  Future<DeletedList?> deleteList(String id) async {
    final list = listById(id);
    if (list == null || list.isInbox) return null;
    final moved = [
      for (final t in tasks)
        if (t.listId == id) t.id,
    ];
    tasks = [
      for (final t in tasks) t.listId == id ? t.copyWith(listId: inboxId) : t,
    ];
    lists.remove(list);
    notifyListeners();
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.listId.equals(id))).write(
        const TasksCompanion(listId: Value(inboxId)),
      );
      await (_db.delete(_db.taskLists)..where((t) => t.id.equals(id))).go();
    });
    return (list: list, movedTaskIds: moved);
  }

  /// Puts a deleted list back, with the tasks that are still in the inbox.
  Future<void> restoreList(DeletedList deleted) async {
    final ids = deleted.movedTaskIds.toSet();
    final back = [
      for (final t in tasks)
        if (ids.contains(t.id) && t.listId == inboxId)
          t.copyWith(listId: deleted.list.id),
    ];
    lists
      ..add(deleted.list)
      ..sort((a, b) => a.position.compareTo(b.position));
    back.forEach(_replaceTask);
    notifyListeners();
    await _db.transaction(() async {
      await _writeList(deleted.list);
      await (_db.update(_db.tasks)
            ..where((t) => t.id.isIn([for (final t in back) t.id])))
          .write(TasksCompanion(listId: Value(deleted.list.id)));
    });
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
