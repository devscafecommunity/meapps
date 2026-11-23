import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../services/reminder_notifier.dart';
import 'database.dart';

class ChecklistItem {
  ChecklistItem(this.text, {this.done = false});
  String text;
  bool done;

  ChecklistItem copy() => ChecklistItem(text, done: done);
}

const _unset = Object();

@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    this.body = '',
    this.checklist = const [],
    this.tag,
    this.pinned = false,
    this.archived = false,
    this.tone = MeTone.plain,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final List<ChecklistItem> checklist;
  final String? tag;
  final bool pinned;
  final bool archived;
  final MeTone tone;
  final DateTime? updatedAt;

  bool get isChecklist => checklist.isNotEmpty;

  /// [tag] accepts `null` to clear it; omit it to keep the current one.
  Note copyWith({
    String? title,
    String? body,
    List<ChecklistItem>? checklist,
    Object? tag = _unset,
    bool? pinned,
    bool? archived,
    MeTone? tone,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    checklist: checklist ?? this.checklist,
    tag: identical(tag, _unset) ? this.tag : tag as String?,
    pinned: pinned ?? this.pinned,
    archived: archived ?? this.archived,
    tone: tone ?? this.tone,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Case-insensitive match on title, body, tag and checklist items.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String? s) => s != null && s.toLowerCase().contains(q);
    return has(title) ||
        has(body) ||
        has(tag) ||
        checklist.any((c) => has(c.text));
  }
}

enum Repeat {
  never('Não repetir'),
  daily('Diário'),
  weekly('Semanal'),
  monthly('Mensal'),
  yearly('Anual');

  const Repeat(this.label);
  final String label;

  /// The occurrence after [d], keeping the time of day. Months and years
  /// clamp to the last valid day (31 jan -> 28/29 fev).
  DateTime after(DateTime d) {
    DateTime clamped(int y, int m) {
      final last = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, d.day > last ? last : d.day, d.hour, d.minute);
    }

    return switch (this) {
      never => d,
      daily => DateTime(d.year, d.month, d.day + 1, d.hour, d.minute),
      weekly => DateTime(d.year, d.month, d.day + 7, d.hour, d.minute),
      monthly => clamped(d.year, d.month + 1),
      yearly => clamped(d.year + 1, d.month),
    };
  }
}

@immutable
class Reminder {
  const Reminder({
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
  final bool done;
  final Repeat repeat;
  final String? noteId;

  Reminder copyWith({
    String? title,
    DateTime? when,
    bool? done,
    Repeat? repeat,
  }) => Reminder(
    id: id,
    title: title ?? this.title,
    when: when ?? this.when,
    done: done ?? this.done,
    repeat: repeat ?? this.repeat,
    noteId: noteId,
  );
}

/// What [AppStore.deleteNote] removed, so it can be put back.
typedef DeletedNote = ({Note note, List<Reminder> reminders});

String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}';

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
  const Note(
    id: 'n2',
    title: 'Reunião de projeto',
    body:
        'Rever roadmap do primeiro trimestre, alinhar prioridades com a '
        'equipa e definir responsáveis por cada entrega.',
    tag: 'Trabalho',
    pinned: true,
    tone: MeTone.primary,
  ),
  const Note(
    id: 'n3',
    title: 'Ideias para o fim de semana',
    body:
        'Caminhada na serra, almoço com a família, ver o filme que ficou '
        'pendente.',
    tag: 'Pessoal',
  ),
  const Note(
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
  const Note(
    id: 'n6',
    title: 'Consulta no dentista',
    body: 'Levar o cartão de utente e os exames anteriores.',
    tag: 'Pessoal',
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
  Reminder(
    id: 'r9',
    title: 'Aniversário da Ana',
    when: _at(5, 9),
    repeat: Repeat.yearly,
  ),
];

// --- Store -------------------------------------------------------------

/// Single source of truth for the UI. Keeps the data in memory for
/// synchronous reads and writes every change through to SQLite (Drift).
/// Reminder changes are mirrored to system notifications via [ReminderNotifier].
class AppStore extends ChangeNotifier {
  AppStore(this._db, {ReminderNotifier? notifier})
    : _notifier = notifier ?? NoopReminderNotifier();

  final AppDatabase _db;
  final ReminderNotifier _notifier;
  List<Note> notes = [];
  List<Reminder> reminders = [];
  Map<String, String> settings = {};

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
    await _syncAllNotifications();
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
          archived: row.archived,
          tone: MeTone.values[row.tone],
          updatedAt: row.updatedAt,
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
    settings = {
      for (final row in await _db.select(_db.settings).get())
        row.key: row.value,
    };
    notifyListeners();
  }

  /// Notification failures (permissions, unsupported platform) must never
  /// block the app or lose data.
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      debugPrint('meremind: notification error: $e');
    }
  }

  Future<void> _syncAllNotifications() => _safely(() async {
    await _notifier.init();
    await _notifier.cancelAll();
    for (final r in reminders) {
      await _syncNotification(r);
    }
  });

  Future<void> _syncNotification(Reminder r) => _safely(
    () => r.done || !r.when.isAfter(DateTime.now())
        ? _notifier.cancel(r.id)
        : _notifier.schedule(id: r.id, title: r.title, when: r.when),
  );

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
            archived: Value(n.archived),
            tone: Value(n.tone.index),
            updatedAt: Value(n.updatedAt),
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

  // --- Queries ---------------------------------------------------------

  Note? noteById(String? id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Every tag in use, alphabetically.
  List<String> get tags => {
    for (final n in notes)
      if (n.tag != null) n.tag!,
  }.toList()..sort();

  /// Most recently edited first; notes never edited keep their seed order.
  List<Note> filterNotes({
    String? tag,
    String query = '',
    bool archived = false,
  }) {
    final indexed = [
      for (var i = 0; i < notes.length; i++)
        if (notes[i].archived == archived &&
            (tag == null || notes[i].tag == tag) &&
            notes[i].matches(query))
          (i, notes[i]),
    ];
    indexed.sort((a, b) {
      final ta = a.$2.updatedAt, tb = b.$2.updatedAt;
      if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
      if (ta != null && tb == null) return -1;
      if (ta == null && tb != null) return 1;
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// The next pending reminder attached to a note, if any.
  Reminder? reminderFor(String noteId) {
    Reminder? best;
    for (final r in reminders) {
      if (r.noteId != noteId || r.done) continue;
      if (best == null || r.when.isBefore(best.when)) best = r;
    }
    return best;
  }

  List<Reminder> remindersOn(DateTime day) =>
      reminders.where((r) => isSameDay(r.when, day)).toList()
        ..sort((a, b) => a.when.compareTo(b.when));

  // --- Notes -----------------------------------------------------------

  /// Inserts or replaces a note (matched by id) and stamps [Note.updatedAt].
  /// Reminders attached to it follow its title.
  Future<void> saveNote(Note n) async {
    final note = n.copyWith(updatedAt: DateTime.now());
    final i = notes.indexWhere((e) => e.id == note.id);
    if (i >= 0) {
      notes[i] = note;
    } else {
      notes.insert(0, note);
    }
    final renamed = [
      for (final r in reminders)
        if (r.noteId == note.id && r.title != note.title)
          r.copyWith(title: note.title),
    ];
    for (final r in renamed) {
      _replaceReminder(r);
    }
    notifyListeners();
    await _writeNote(note);
    for (final r in renamed) {
      await _writeReminder(r);
      await _syncNotification(r);
    }
  }

  /// Removes a note together with its reminders. Returns what was removed
  /// so the UI can offer "undo" through [restoreNote].
  Future<DeletedNote?> deleteNote(String id) async {
    final note = noteById(id);
    if (note == null) return null;
    final linked = reminders.where((r) => r.noteId == id).toList();
    notes.removeWhere((n) => n.id == id);
    reminders.removeWhere((r) => r.noteId == id);
    notifyListeners();
    await _db.transaction(() async {
      await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
      await (_db.delete(_db.reminders)..where((t) => t.noteId.equals(id))).go();
    });
    for (final r in linked) {
      await _safely(() => _notifier.cancel(r.id));
    }
    return (note: note, reminders: linked);
  }

  Future<void> restoreNote(DeletedNote deleted) async {
    notes.insert(0, deleted.note);
    reminders.addAll(deleted.reminders);
    notifyListeners();
    await _writeNote(deleted.note);
    for (final r in deleted.reminders) {
      await _writeReminder(r);
      await _syncNotification(r);
    }
  }

  /// Sets, moves or (with `null`) removes the pending reminder of a note.
  Future<void> setNoteReminder(Note note, DateTime? when) async {
    final current = reminderFor(note.id);
    if (when == null) {
      if (current != null) await deleteReminder(current.id);
      return;
    }
    await saveReminder(
      current?.copyWith(when: when, title: note.title) ??
          Reminder(
            id: newId('r'),
            title: note.title,
            when: when,
            noteId: note.id,
          ),
    );
  }

  // --- Reminders -------------------------------------------------------

  void _replaceReminder(Reminder r) {
    final i = reminders.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      reminders[i] = r;
    } else {
      reminders.add(r);
    }
  }

  /// Inserts or replaces a reminder (matched by id).
  Future<void> saveReminder(Reminder r) async {
    _replaceReminder(r);
    notifyListeners();
    await _writeReminder(r);
    await _syncNotification(r);
  }

  Future<Reminder?> deleteReminder(String id) async {
    final i = reminders.indexWhere((r) => r.id == id);
    if (i < 0) return null;
    final removed = reminders.removeAt(i);
    notifyListeners();
    await (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();
    await _safely(() => _notifier.cancel(id));
    return removed;
  }

  /// Marks a reminder done / not done. A repeating reminder that gets
  /// completed is instead moved to its next future occurrence.
  /// Returns the previous state, for "undo" via [saveReminder].
  Future<Reminder> toggle(Reminder r) async {
    final current = reminders.firstWhere((e) => e.id == r.id, orElse: () => r);
    final Reminder next;
    if (!current.done && current.repeat != Repeat.never) {
      final now = DateTime.now();
      var when = current.repeat.after(current.when);
      while (!when.isAfter(now)) {
        when = current.repeat.after(when);
      }
      next = current.copyWith(when: when);
    } else {
      next = current.copyWith(done: !current.done);
    }
    await saveReminder(next);
    return current;
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
