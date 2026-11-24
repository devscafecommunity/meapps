import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/habit_widgets.dart';
import 'habit_detail_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final habits = store.activeHabits;
    if (habits.isEmpty) {
      return const Center(
        child: MeEmptyState(
          icon: Icons.insights_outlined,
          title: 'Sem progresso ainda',
          message: 'Crie um hábito para acompanhar sequências e taxas.',
        ),
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      itemCount: habits.length,
      separatorBuilder: (_, _) => const SizedBox(height: MeSpacing.sm),
      itemBuilder: (context, i) {
        final h = habits[i];
        return MeCard(
          key: ValueKey('progress-${h.id}'),
          onTap: () => openHabitDetail(context, store, h),
          child: Column(
            children: [
              Row(
                children: [
                  HabitAvatar(habit: h),
                  const SizedBox(width: MeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name, style: theme.textTheme.titleMedium),
                        Text(
                          habitSummary(h),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: MeSpacing.md),
              HabitStatsRow(habit: h, store: store),
            ],
          ),
        );
      },
    );
  }
}
