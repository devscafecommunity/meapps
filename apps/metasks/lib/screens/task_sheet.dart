import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/task_tile.dart';

/// Creates a task, or edits [task] when given. [initialListId] and
/// [initialDue] preselect the list and day of a new task.
Future<void> showTaskSheet(
  BuildContext context,
  AppStore store, {
  Task? task,
  String? initialListId,
  DateTime? initialDue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TaskSheet(
      store: store,
      existing: task,
      initialListId: initialListId,
      initialDue: initialDue,
    ),
  );
}

class _Quick {
  const _Quick(this.label, this.day);
  final String label;
  final DateTime day;
}

class _SubItem {
  _SubItem(String label, {this.done = false})
    : controller = TextEditingController(text: label);
  final TextEditingController controller;
  final focus = FocusNode();
  bool done;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({
    required this.store,
    this.existing,
    this.initialListId,
    this.initialDue,
  });

  final AppStore store;
  final Task? existing;
  final String? initialListId;
  final DateTime? initialDue;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late String _listId =
      widget.existing?.listId ?? widget.initialListId ?? inboxId;
  late DateTime? _due = widget.existing != null
      ? widget.existing!.dueDate
      : widget.initialDue;
  late Priority _priority = widget.existing?.priority ?? Priority.none;
  late final List<_SubItem> _subs = [
    for (final s in widget.existing?.subtasks ?? const <Subtask>[])
      _SubItem(s.label, done: s.done),
  ];
  late final List<_Quick> _quick = _quickOptions();
  bool _emptyTitle = false;

  bool get _editing => widget.existing != null;

  List<_Quick> _quickOptions() {
    final n = DateTime.now();
    return [
      _Quick('Hoje', DateTime(n.year, n.month, n.day)),
      _Quick('Amanhã', DateTime(n.year, n.month, n.day + 1)),
      _Quick('Próxima semana', DateTime(n.year, n.month, n.day + 7)),
    ];
  }

  bool get _isCustom => _due != null && !_quick.any((q) => q.day == _due);

  Future<void> _pickCustom() async {
    final picked = await pickDate(context, _due ?? _quick[1].day);
    if (picked != null) setState(() => _due = dateOnly(picked));
  }

  void _addSub() {
    final item = _SubItem('');
    setState(() => _subs.add(item));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) item.focus.requestFocus();
    });
  }

  void _removeSub(_SubItem item) {
    setState(() => _subs.remove(item));
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _emptyTitle = true);
      return;
    }
    final store = widget.store;
    final subtasks = [
      for (final s in _subs)
        if (s.controller.text.trim().isNotEmpty)
          Subtask(s.controller.text.trim(), done: s.done),
    ];
    final existing = widget.existing;
    final task = existing == null
        ? Task(
            id: newId('t'),
            listId: _listId,
            title: title,
            notes: _notes.text.trim(),
            dueDate: _due,
            priority: _priority,
            createdAt: DateTime.now(),
            position: store.nextPosition(_listId),
            subtasks: subtasks,
          )
        : existing.copyWith(
            listId: _listId,
            title: title,
            notes: _notes.text.trim(),
            dueDate: _due,
            priority: _priority,
            subtasks: subtasks,
            // Moving to another list appends it there.
            position: existing.listId == _listId
                ? null
                : store.nextPosition(_listId),
          );
    Navigator.pop(context);
    await store.saveTask(task);
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await deleteTaskWithUndo(messenger, widget.store, widget.existing!.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final s in _subs) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: MeSpacing.md, bottom: MeSpacing.sm),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    Wrap chips(List<Widget> children) => Wrap(
      spacing: MeSpacing.sm,
      runSpacing: MeSpacing.sm,
      children: children,
    );

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
                  _editing ? 'Editar tarefa' : 'Nova tarefa',
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
              hintText: 'O que há para fazer?',
              errorText: _emptyTitle ? 'Escreva um título' : null,
            ),
          ),
          const SizedBox(height: MeSpacing.sm),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Notas',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          label('Lista'),
          chips([
            for (final l in widget.store.lists)
              ChoiceChip(
                label: Text(l.name),
                selected: _listId == l.id,
                onSelected: (_) => setState(() => _listId = l.id),
              ),
          ]),
          label('Data'),
          chips([
            for (final q in _quick)
              ChoiceChip(
                label: Text(q.label),
                selected: _due == q.day,
                onSelected: (_) => setState(() => _due = q.day),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(_isCustom ? formatDayLabel(_due!) : 'Personalizada'),
              selected: _isCustom,
              onSelected: (_) => _pickCustom(),
            ),
            ChoiceChip(
              label: const Text('Sem data'),
              selected: _due == null,
              onSelected: (_) => setState(() => _due = null),
            ),
          ]),
          label('Prioridade'),
          chips([
            for (final p in Priority.values)
              ChoiceChip(
                avatar: p == Priority.none
                    ? null
                    : Icon(Icons.flag, size: 18, color: p.color(scheme)),
                label: Text(p.label),
                selected: _priority == p,
                showCheckmark: false,
                onSelected: (_) => setState(() => _priority = p),
              ),
          ]),
          label('Subtarefas'),
          for (final s in _subs)
            _SubtaskRow(
              key: ObjectKey(s),
              item: s,
              onToggle: (v) => setState(() => s.done = v),
              onSubmitted: _addSub,
              onRemove: () => _removeSub(s),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addSub,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar subtarefa'),
            ),
          ),
          const SizedBox(height: MeSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onSubmitted,
    required this.onRemove,
  });

  final _SubItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSubmitted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Checkbox(value: item.done, onChanged: (v) => onToggle(v ?? false)),
        Expanded(
          child: TextField(
            controller: item.controller,
            focusNode: item.focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onSubmitted(),
            style: item.done
                ? theme.textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Subtarefa',
              filled: false,
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Remover subtarefa',
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}
