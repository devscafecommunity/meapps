import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meremind/data/app_store.dart';
import 'package:meremind/data/database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('meremind_test');
    file = File('${dir.path}/db.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppStore> open({bool seedDemo = false}) async {
    final store = AppStore(AppDatabase(NativeDatabase(file)));
    await store.init(seedDemo: seedDemo);
    return store;
  }

  test('seeds demo data only on a brand new database', () async {
    final first = await open(seedDemo: true);
    final count = first.notes.length;
    expect(count, greaterThan(0));
    await first.saveNote(first.notes.first.copyWith(title: 'Alterada'));

    await first.close();
    final second = await open(seedDemo: true);
    expect(second.notes.length, count);
  });

  test('notes, checklists and reminders survive a restart', () async {
    final a = await open();
    await a.saveNote(
      Note(
        id: 'x',
        title: 'Compras',
        body: 'corpo',
        checklist: [ChecklistItem('Pão'), ChecklistItem('Leite', done: true)],
      ),
    );
    final r = Reminder(id: 'r', title: 'Ligar', when: DateTime(2026, 12, 1, 9));
    await a.add(r);
    await a.toggle(r);

    await a.close();
    final b = await open();
    final n = b.noteById('x')!;
    expect(n.title, 'Compras');
    expect(n.checklist.map((c) => (c.text, c.done)), [
      ('Pão', false),
      ('Leite', true),
    ]);
    expect(b.reminders.single.done, isTrue);
    expect(b.reminders.single.when, DateTime(2026, 12, 1, 9));
  });

  test('saving a note again replaces its checklist', () async {
    final a = await open();
    final n = Note(id: 'x', title: 't', checklist: [ChecklistItem('a')]);
    await a.saveNote(n);
    await a.saveNote(n.copyWith(checklist: [ChecklistItem('b')]));

    await a.close();
    final b = await open();
    expect(b.notes.single.checklist.map((c) => c.text), ['b']);
  });
}
