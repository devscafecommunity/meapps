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
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Index into `MeTone.values`.
  IntColumn get tone => integer().withDefault(const Constant(0))();

  /// Last edit; null for rows created before schema v2.
  DateTimeColumn get updatedAt => dateTime().nullable()();

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

/// Small key/value store for preferences (theme, brightness, ...).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Notes, ChecklistItems, Reminders, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database (SQLite file in the app documents directory).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'meremind'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 kept a note's reminder date on the note itself. The reminders
        // table (linked by note_id) is now the single source of truth.
        await customStatement('''
          INSERT INTO reminders (id, title, due_at, done, repeat, note_id)
          SELECT 'rn_' || id, title, reminder, 0, 0, id FROM notes
          WHERE reminder IS NOT NULL
            AND id NOT IN (
              SELECT note_id FROM reminders WHERE note_id IS NOT NULL
            )
        ''');
        await m.alterTable(
          TableMigration(notes, newColumns: [notes.archived, notes.updatedAt]),
        );
        await m.createTable(settings);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
