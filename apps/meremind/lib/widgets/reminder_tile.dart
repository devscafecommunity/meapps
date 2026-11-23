import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    required this.onToggle,
    this.showDay = false,
    this.overdue = false,
  });

  final Reminder reminder;
  final VoidCallback onToggle;
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: MeSpacing.sm),
      leading: Checkbox(value: r.done, onChanged: (_) => onToggle()),
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
    );
  }
}
