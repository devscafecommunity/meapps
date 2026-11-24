import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../screens/task_sheet.dart';

extension PriorityColor on Priority {
  /// Marker colour; `null` for tasks without priority.
  Color? color(ColorScheme s) => switch (this) {
    Priority.none => null,
    Priority.low => s.primary,
    Priority.medium => s.tertiary,
    Priority.high => s.error,
  };
}

/// Completes (or reopens) a task, with an undo action.
Future<void> toggleTaskWithUndo(
  BuildContext context,
  AppStore store,
  Task t,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final previous = await store.toggleTask(t);
  showUndoSnackBar(
    messenger,
    previous.done ? 'Tarefa reaberta' : 'Tarefa concluída',
    () => store.saveTask(previous),
  );
}

Future<void> deleteTaskWithUndo(
  ScaffoldMessengerState messenger,
  AppStore store,
  String id,
) async {
  final removed = await store.deleteTask(id);
  if (removed == null) return;
  showUndoSnackBar(messenger, 'Tarefa apagada', () => store.saveTask(removed));
}

/// A task row that can be ticked, tapped to edit and swiped to delete.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.store,
    this.showDue = true,
    this.showList = true,
  });

  final Task task;
  final AppStore store;

  /// Hidden where the section already says the day.
  final bool showDue;

  /// Hidden inside the list's own screen.
  final bool showList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = task;
    final list = showList ? store.listById(t.listId) : null;
    final flag = t.priority.color(scheme);
    final tags = [
      if (showDue && t.dueDate != null)
        MeTag(
          label: formatDayLabel(t.dueDate!),
          icon: Icons.event_outlined,
          color: t.isOverdue() ? scheme.error : null,
        ),
      if (t.subtasks.isNotEmpty)
        MeTag(
          label: '${t.subtasksDone}/${t.subtasks.length}',
          icon: Icons.checklist,
        ),
      if (list != null)
        MeTag(
          label: list.name,
          icon: list.isInbox ? Icons.inbox_outlined : Icons.list_alt,
        ),
    ];

    return Dismissible(
      key: ValueKey('task-${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(MeRadius.sm),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) =>
          deleteTaskWithUndo(ScaffoldMessenger.of(context), store, t.id),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: MeSpacing.sm),
        onTap: () => showTaskSheet(context, store, task: t),
        leading: Checkbox(
          value: t.done,
          onChanged: (_) => toggleTaskWithUndo(context, store, t),
        ),
        title: Text(
          t.title,
          style: t.done
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: scheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyLarge,
        ),
        subtitle: tags.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: MeSpacing.sm,
                  runSpacing: MeSpacing.xs,
                  children: tags,
                ),
              ),
        trailing: flag == null
            ? null
            : Tooltip(
                message: 'Prioridade ${t.priority.label.toLowerCase()}',
                child: Icon(Icons.flag, color: flag),
              ),
      ),
    );
  }
}

/// Section header plus a card with the tasks. Renders nothing when empty.
/// With [onToggle] the header collapses and expands the card.
class TaskSection extends StatelessWidget {
  const TaskSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.store,
    this.color,
    this.showDue = true,
    this.showList = true,
    this.collapsed = false,
    this.onToggle,
  });

  final String title;
  final List<Task> tasks;
  final AppStore store;
  final Color? color;
  final bool showDue;
  final bool showList;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final header = MeSectionHeader(
      title,
      color: color,
      trailing: onToggle == null
          ? null
          : Icon(collapsed ? Icons.expand_more : Icons.expand_less),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onToggle == null)
          header
        else
          InkWell(
            borderRadius: BorderRadius.circular(MeRadius.sm),
            onTap: onToggle,
            child: header,
          ),
        if (!collapsed)
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [
                for (final t in tasks)
                  TaskTile(
                    task: t,
                    store: store,
                    showDue: showDue,
                    showList: showList,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
