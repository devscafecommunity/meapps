import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../screens/new_reminder_sheet.dart';

/// Toggles a reminder and, for repeating ones, tells the user when the next
/// occurrence is, with an undo action.
Future<void> toggleReminder(
  BuildContext context,
  AppStore store,
  Reminder r,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final previous = await store.toggle(r);
  final now = store.reminders.where((e) => e.id == r.id).firstOrNull;
  if (now == null || now.done || previous.repeat == Repeat.never) return;
  showUndoSnackBar(
    messenger,
    'Próximo: ${formatDayLabel(now.when)} · ${formatTime(now.when)}',
    () => store.saveReminder(previous),
  );
}

Future<void> deleteReminderWithUndo(
  BuildContext context,
  AppStore store,
  Reminder r,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final removed = await store.deleteReminder(r.id);
  if (removed == null) return;
  showUndoSnackBar(
    messenger,
    'Lembrete apagado',
    () => store.saveReminder(removed),
  );
}

/// A reminder row that can be toggled, tapped to edit and swiped to delete.
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    required this.store,
    this.showDay = false,
    this.overdue = false,
  });

  final Reminder reminder;
  final AppStore store;
  final bool showDay;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = reminder;
    final when = showDay
        ? '${formatDayLabel(r.when)} · ${formatTime(r.when)}'
        : formatTime(r.when);

    return Dismissible(
      key: ValueKey('reminder-${r.id}'),
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
      onDismissed: (_) => deleteReminderWithUndo(context, store, r),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: MeSpacing.sm),
        onTap: () => showReminderSheet(context, store, reminder: r),
        leading: Checkbox(
          value: r.done,
          onChanged: (_) => toggleReminder(context, store, r),
        ),
        title: Text(
          r.title,
          style: r.done
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: scheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.xs,
            children: [
              MeTag(
                label: when,
                icon: Icons.schedule,
                color: overdue ? scheme.error : null,
              ),
              if (r.repeat != Repeat.never)
                MeTag(label: r.repeat.label, icon: Icons.repeat),
              if (r.noteId != null)
                const MeTag(label: 'Nota', icon: Icons.sticky_note_2_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
