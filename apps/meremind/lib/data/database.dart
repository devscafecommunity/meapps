import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get tag => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// Index into `MeTone.values`.
  IntColumn get tone => integer().withDefault(const Constant(0))();
  DateTimeColumn get reminder => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChecklistRow')
class ChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get label => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

@DataClassName('ReminderRow')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// Index into the `Repeat` enum.
  IntColumn get repeat => integer().withDefault(const Constant(0))();
  TextColumn get noteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes, ChecklistItems, Reminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database (SQLite file in the app documents directory).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'meremind'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
