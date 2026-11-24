import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Index into the `EntryKind` enum (0 despesa, 1 receita).
  IntColumn get kind => integer()();

  /// Name of a `CategoryIcon` value (names survive reordering the enum).
  TextColumn get icon => text()();

  /// Index into `MeTone.values`.
  IntColumn get tone => integer().withDefault(const Constant(0))();

  /// Monthly budget in cents; expenses only, null when not set.
  IntColumn get budgetCents => integer().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EntryRow')
class Entries extends Table {
  TextColumn get id => text()();

  /// Index into the `EntryKind` enum.
  IntColumn get kind => integer()();

  /// Always positive; [kind] says whether it is spent or received.
  IntColumn get amountCents => integer()();
  TextColumn get categoryId => text().references(Categories, #id)();

  /// Calendar day as `yyyymmdd`, so it never shifts with the time zone.
  IntColumn get day => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

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

@DriftDatabase(tables: [Categories, Entries, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-device database (SQLite file in the app documents directory).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'mebudget'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
