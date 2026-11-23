import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meremind/data/app_store.dart';
import 'package:meremind/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Schema exactly as shipped in v1 (commit 836361a).
const _v1 = [
  '''CREATE TABLE notes (id TEXT NOT NULL, title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '', tag TEXT NULL,
    pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0, 1)),
    tone INTEGER NOT NULL DEFAULT 0, reminder INTEGER NULL,
    PRIMARY KEY (id))''',
  '''CREATE TABLE checklist_items (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    note_id TEXT NOT NULL REFERENCES notes (id) ON DELETE CASCADE,
    position INTEGER NOT NULL, label TEXT NOT NULL,
    done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)))''',
  '''CREATE TABLE reminders (id TEXT NOT NULL, title TEXT NOT NULL,
    due_at INTEGER NOT NULL,
    done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)),
    repeat INTEGER NOT NULL DEFAULT 0, note_id TEXT NULL,
    PRIMARY KEY (id))''',
];

void main() {
  test(
    'v1 -> v2 keeps data and moves note reminders to the reminders table',
    () async {
      final dir = Directory.systemTemp.createTempSync('meremind_mig');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/db.sqlite');

      // Dec 1 2026 09:00 UTC, stored as unix seconds like Drift does.
      const due = 1796115600;
      final raw = sqlite3.open(file.path);
      for (final stmt in _v1) {
        raw.execute(stmt);
      }
      raw
        ..execute(
          "INSERT INTO notes (id, title, pinned, tone, reminder) "
          "VALUES ('a', 'Com lembrete', 1, 2, $due)",
        )
        ..execute(
          "INSERT INTO notes (id, title, reminder) "
          "VALUES ('b', 'Já ligada', $due)",
        )
        ..execute("INSERT INTO notes (id, title) VALUES ('c', 'Simples')")
        ..execute(
          "INSERT INTO checklist_items (note_id, position, label) "
          "VALUES ('c', 0, 'item')",
        )
        ..execute(
          "INSERT INTO reminders (id, title, due_at, note_id) "
          "VALUES ('rb', 'Já ligada', $due, 'b')",
        )
        ..execute('PRAGMA user_version = 1')
        ..close();

      final store = AppStore(AppDatabase(NativeDatabase(file)));
      await store.init(seedDemo: false);

      expect(store.notes, hasLength(3));
      final a = store.noteById('a')!;
      expect(a.pinned, isTrue);
      expect(a.archived, isFalse);
      expect(a.updatedAt, isNull);
      expect(store.noteById('c')!.checklist.single.text, 'item');

      // 'a' got a reminder from its old column; 'b' kept its existing one.
      expect(
        store.reminderFor('a')?.when.toUtc(),
        DateTime.utc(2026, 12, 1, 9),
      );
      expect(store.reminders.where((r) => r.noteId == 'b'), hasLength(1));
      expect(store.reminders, hasLength(2));

      await store.setSetting('k', 'v');
      expect(store.settings['k'], 'v');
      await store.close();
    },
  );
}
