import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Calendar days (`createdAt`, `day`) are stored as `yyyy-mm-dd` text rather
/// than timestamps, so a habit's history does not shift by a day when the
/// device changes time zone.
@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Name of a `HabitIcon` value.
  TextColumn get icon => text()();

  /// Index into `MeTone.values`.
  IntColumn get tone => integer().withDefault(const Constant(0))();

  /// Scheduled days of the week, Monday = bit 0 … Sunday = bit 6.
  IntColumn get weekdays => integer().withDefault(const Constant(0x7F))();
  IntColumn get dailyTarget => integer().withDefault(const Constant(1))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CheckinRow')
class Checkins extends Table {
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get day => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {habitId, day};
}

/// Small key/value store for preferences (theme, brightness, ...).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Habits, Checkins, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database: a SQLite file in the app documents directory, or
  /// on the web the browser's storage (OPFS or IndexedDB) through the
  /// `sqlite3.wasm` and `drift_worker.js` files in `web/`.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'mehabits',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  bool _created = false;

  /// Whether opening this connection created the schema, i.e. the database
  /// is brand new (first launch). Only meaningful once it has been queried.
  bool get created => _created;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      _created = details.wasCreated;
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
