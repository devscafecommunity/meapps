import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart';
import 'package:meapps_ui/meapps_ui.dart';

import 'database.dart';

class ChecklistItem {
  ChecklistItem(this.text, {this.done = false});
  final String text;
  bool done;
}

class Note {
  Note({
    required this.id,
    required this.title,
    this.body = '',
    this.checklist = const [],
    this.tag,
    this.pinned = false,
    this.tone = MeTone.plain,
    this.reminder,
  });

  final String id;
  final String title;
  final String body;
  final List<ChecklistItem> checklist;
  final String? tag;
  final bool pinned;
  final MeTone tone;
  final DateTime? reminder;

  Note copyWith({
    String? title,
    String? body,
    List<ChecklistItem>? checklist,
  }) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    checklist: checklist ?? this.checklist,
    tag: tag,
    pinned: pinned,
    tone: tone,
    reminder: reminder,
  );
}

enum Repeat {
  never('Não repetir'),
  daily('Diário'),
  weekly('Semanal');

  const Repeat(this.label);
  final String label;
}

class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.when,
    this.done = false,
    this.repeat = Repeat.never,
    this.noteId,
  });

  final String id;
  final String title;
  final DateTime when;
  bool done;
  final Repeat repeat;
  final String? noteId;
}

DateTime _at(int dayOffset, int hour, [int minute = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + dayOffset, hour, minute);
}

// --- Demo seed (first launch only) -------------------------------------

/// Dates are relative to "now" so the demo data always looks alive.
List<Note> _demoNotes() => [
  Note(
    id: 'n1',
    title: 'Lista de compras',
    tag: 'Casa',
    pinned: true,
    tone: MeTone.tertiary,
    checklist: [
      ChecklistItem('Leite', done: true),
      ChecklistItem('Pão'),
      ChecklistItem('Ovos'),
      ChecklistItem('Café'),
      ChecklistItem('Fruta'),
    ],
  ),
  Note(
    id: 'n2',
    title: 'Reunião de projeto',
    body:
        'Rever roadmap do primeiro trimestre, alinhar prioridades com a '
        'equipa e definir responsáveis por cada entrega.',
    tag: 'Trabalho',
    pinned: true,
    tone: MeTone.primary,
    reminder: _at(1, 10),
  ),
  Note(
    id: 'n3',
    title: 'Ideias para o fim de semana',
    body:
        'Caminhada na serra, almoço com a família, ver o filme que ficou '
        'pendente.',
    tag: 'Pessoal',
  ),
  Note(
    id: 'n4',
    title: 'Receita de bolo de cenoura',
    body:
        '3 cenouras, 3 ovos, 1 chávena de óleo, 2 de açúcar, 2 de farinha. '
        'Forno a 180º durante 40 minutos.',
    tag: 'Casa',
    tone: MeTone.secondary,
  ),
  Note(
    id: 'n5',
    title: 'Livros para ler',
    tag: 'Pessoal',
    checklist: [
      ChecklistItem('Hábitos Atómicos'),
      ChecklistItem('O Nome da Rosa', done: true),
      ChecklistItem('Sapiens'),
    ],
  ),
  Note(
    id: 'n6',
    title: 'Consulta no dentista',
    body: 'Levar o cartão de utente e os exames anteriores.',
    tag: 'Pessoal',
    reminder: _at(3, 15, 30),
  ),
];

List<Reminder> _demoReminders() => [
  Reminder(id: 'r1', title: 'Pagar a renda', when: _at(-1, 9)),
  Reminder(
    id: 'r2',
    title: 'Tomar vitaminas',
    when: _at(0, 8),
    done: true,
    repeat: Repeat.daily,
  ),
  Reminder(id: 'r3', title: 'Ligar à mãe', when: _at(0, 18, 30)),
  Reminder(id: 'r4', title: 'Enviar relatório semanal', when: _at(0, 17)),
  Reminder(
    id: 'r5',
    title: 'Reunião de projeto',
    when: _at(1, 10),
    noteId: 'n2',
  ),
  Reminder(
    id: 'r6',
    title: 'Regar as plantas',
    when: _at(2, 19),
    repeat: Repeat.weekly,
  ),
  Reminder(
    id: 'r7',
    title: 'Consulta no dentista',
    when: _at(3, 15, 30),
    noteId: 'n6',
  ),
  Reminder(id: 'r8', title: 'Renovar seguro do carro', when: _at(9, 12)),
  Reminder(id: 'r9', title: 'Aniversário da Ana', when: _at(5, 9)),
];

// --- Store -------------------------------------------------------------

/// Single source of truth for the UI. Keeps the data in memory for
/// synchronous reads and writes every change through to SQLite (Drift).
class AppStore extends ChangeNotifier {
  AppStore(this._db);

  final AppDatabase _db;
  List<Note> notes = [];
  List<Reminder> reminders = [];

  /// Loads from disk; seeds demo data when the database is brand new.
  Future<void> init({bool seedDemo = true}) async {
    if (seedDemo &&
        await _db.select(_db.notes).get().then((r) => r.isEmpty) &&
        await _db.select(_db.reminders).get().then((r) => r.isEmpty)) {
      for (final n in _demoNotes()) {
        await _writeNote(n);
      }
      for (final r in _demoReminders()) {
        await _writeReminder(r);
      }
    }
    await _load();
  }

  Future<void> _load() async {
    final checks = await (_db.select(
      _db.checklistItems,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    notes = [
      for (final row in await _db.select(_db.notes).get())
        Note(
          id: row.id,
          title: row.title,
          body: row.body,
          tag: row.tag,
          pinned: row.pinned,
          tone: MeTone.values[row.tone],
          reminder: row.reminder,
          checklist: [
            for (final c in checks.where((c) => c.noteId == row.id))
              ChecklistItem(c.label, done: c.done),
          ],
        ),
    ];
    reminders = [
      for (final row in await _db.select(_db.reminders).get())
        Reminder(
          id: row.id,
          title: row.title,
          when: row.dueAt,
          done: row.done,
          repeat: Repeat.values[row.repeat],
          noteId: row.noteId,
        ),
    ];
    notifyListeners();
  }

  Future<void> _writeNote(Note n) => _db.transaction(() async {
    await _db
        .into(_db.notes)
        .insertOnConflictUpdate(
          NotesCompanion(
            id: Value(n.id),
            title: Value(n.title),
            body: Value(n.body),
            tag: Value(n.tag),
            pinned: Value(n.pinned),
            tone: Value(n.tone.index),
            reminder: Value(n.reminder),
          ),
        );
    await (_db.delete(
      _db.checklistItems,
    )..where((t) => t.noteId.equals(n.id))).go();
    for (var i = 0; i < n.checklist.length; i++) {
      await _db
          .into(_db.checklistItems)
          .insert(
            ChecklistItemsCompanion.insert(
              noteId: n.id,
              position: i,
              label: n.checklist[i].text,
              done: Value(n.checklist[i].done),
            ),
          );
    }
  });

  Future<void> _writeReminder(Reminder r) => _db
      .into(_db.reminders)
      .insertOnConflictUpdate(
        RemindersCompanion(
          id: Value(r.id),
          title: Value(r.title),
          dueAt: Value(r.when),
          done: Value(r.done),
          repeat: Value(r.repeat.index),
          noteId: Value(r.noteId),
        ),
      );

  Future<void> close() => _db.close();

  Note? noteById(String? id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<Reminder> remindersOn(DateTime day) =>
      reminders.where((r) => isSameDay(r.when, day)).toList()
        ..sort((a, b) => a.when.compareTo(b.when));

  Future<void> toggle(Reminder r) async {
    r.done = !r.done;
    notifyListeners();
    await _writeReminder(r);
  }

  Future<void> add(Reminder r) async {
    reminders.add(r);
    notifyListeners();
    await _writeReminder(r);
  }

  /// Inserts or replaces a note (matched by id).
  Future<void> saveNote(Note n) async {
    final i = notes.indexWhere((e) => e.id == n.id);
    if (i >= 0) {
      notes[i] = n;
    } else {
      notes.insert(0, n);
    }
    notifyListeners();
    await _writeNote(n);
  }
}
