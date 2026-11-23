import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/reminder_tile.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final all = [...store.reminders]..sort((a, b) => a.when.compareTo(b.when));

    final overdue = all
        .where((r) => !r.done && r.when.isBefore(today))
        .toList();
    final todayItems = all.where((r) => isSameDay(r.when, today)).toList();
    final upcoming = all
        .where(
          (r) => !r.done && r.when.isAfter(today.add(const Duration(days: 1))),
        )
        .toList();
    final done = all.where((r) => r.done && !isSameDay(r.when, today)).toList();

    Widget group(
      String title,
      List<Reminder> items, {
      bool showDay = false,
      bool overdue = false,
      Color? color,
    }) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeSectionHeader(title, color: color),
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [
                for (final r in items)
                  ReminderTile(
                    reminder: r,
                    showDay: showDay,
                    overdue: overdue,
                    onToggle: () => store.toggle(r),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        group(
          'ATRASADOS',
          overdue,
          showDay: true,
          overdue: true,
          color: Theme.of(context).colorScheme.error,
        ),
        group('HOJE', todayItems),
        group('PRÓXIMOS', upcoming, showDay: true),
        group('CONCLUÍDOS', done, showDay: true),
      ],
    );
  }
}
