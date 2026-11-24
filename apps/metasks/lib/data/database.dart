import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('TaskListRow')
class TaskLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Index into `MeTone.values`.
  IntColumn get tone => integer().withDefault(const Constant(0))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get id => text()();

  /// Lists are never deleted while they hold tasks: the store moves them to
  /// the inbox first.
  TextColumn get listId => text().references(TaskLists, #id)();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Local midnight of the due day; null when the task has no date.
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Index into the `Priority` enum.
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SubtaskRow')
class Subtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get label => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

/// Small key/value store for preferences (theme, brightness, ...).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [TaskLists, Tasks, Subtasks, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database: a SQLite file in the app documents directory, or
  /// on the web the browser's storage (OPFS or IndexedDB) through the
  /// `sqlite3.wasm` and `drift_worker.js` files in `web/`.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'metasks',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
