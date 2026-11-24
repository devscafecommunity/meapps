import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import 'note_editor_screen.dart';

/// Creates a reminder, or edits [reminder] when given. [initialDay] preselects
/// a day (e.g. the one selected in the calendar) for new reminders.
Future<void> showReminderSheet(
  BuildContext context,
  AppStore store, {
  Reminder? reminder,
  DateTime? initialDay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReminderSheet(
      store: store,
      existing: reminder,
      initialDay: initialDay,
      onOpenNote: (note) {
        if (context.mounted) openNoteEditor(context, store, note: note);
      },
    ),
  );
}

class _Quick {
  const _Quick(this.label, this.when);
  final String label;
  final DateTime when;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.store,
    required this.onOpenNote,
    this.existing,
    this.initialDay,
  });

  final AppStore store;
  final ValueChanged<Note> onOpenNote;
  final Reminder? existing;
  final DateTime? initialDay;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late Repeat _repeat = widget.existing?.repeat ?? Repeat.never;
  late final List<_Quick> _quick = _quickOptions();
  late DateTime _when = _initialWhen();
  bool _emptyTitle = false;

  bool get _editing => widget.existing != null;

  List<_Quick> _quickOptions() {
    final n = DateTime.now();
    return [
      if (n.hour < 18)
        _Quick('Hoje 18:00', DateTime(n.year, n.month, n.day, 18)),
      _Quick('Amanhã 09:00', DateTime(n.year, n.month, n.day + 1, 9)),
      _Quick('Próx. semana', DateTime(n.year, n.month, n.day + 7, 9)),
    ];
  }

  DateTime _initialWhen() {
    if (widget.existing != null) return widget.existing!.when;
    final day = widget.initialDay;
    if (day != null && !isSameDay(day, DateTime.now())) {
      return DateTime(day.year, day.month, day.day, 9);
    }
    return _quick.first.when;
  }

  bool get _isCustom => !_quick.any((q) => q.when == _when);

  Future<void> _pickCustom() async {
    final picked = await pickDateTime(context, _when);
    if (picked != null) setState(() => _when = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _emptyTitle = true);
      return;
    }
    final existing = widget.existing;
    final r = existing == null
        ? Reminder(id: newId('r'), title: title, when: _when, repeat: _repeat)
        : existing.copyWith(
            title: title,
            when: _when,
            repeat: _repeat,
            // Moving a done reminder to the future re-activates it.
            done: existing.done && !_when.isAfter(DateTime.now()),
          );
    Navigator.pop(context);
    await widget.store.saveReminder(r);
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final removed = await widget.store.deleteReminder(widget.existing!.id);
    if (removed == null) return;
    showUndoSnackBar(
      messenger,
      'Lembrete apagado',
      () => widget.store.saveReminder(removed),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.store.noteById(widget.existing?.noteId);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MeSpacing.md,
        0,
        MeSpacing.md,
        MeSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editing ? 'Editar lembrete' : 'Novo lembrete',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (_editing)
                IconButton(
                  tooltip: 'Apagar',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_emptyTitle) setState(() => _emptyTitle = false);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'O que quer lembrar?',
              errorText: _emptyTitle ? 'Escreva um título' : null,
            ),
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Quando', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.sm,
            children: [
              for (final q in _quick)
                ChoiceChip(
                  label: Text(q.label),
                  selected: _when == q.when,
                  onSelected: (_) => setState(() => _when = q.when),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _isCustom
                      ? '${formatDayLabel(_when)} · ${formatTime(_when)}'
                      : 'Escolher…',
                ),
                selected: _isCustom,
                onSelected: (_) => _pickCustom(),
              ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Repetir', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.sm,
            children: [
              for (final r in Repeat.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _repeat == r,
                  onSelected: (_) => setState(() => _repeat = r),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: MeSpacing.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenNote(note);
              },
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: Text('Abrir nota "${note.title}"'),
            ),
          ],
          const SizedBox(height: MeSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}
