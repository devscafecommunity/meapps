import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/habit_widgets.dart';
import 'habit_sheet.dart';

Future<void> openHabitDetail(BuildContext context, AppStore store, Habit h) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => HabitDetailScreen(store: store, habitId: h.id),
    ),
  );
}

/// Stats and month calendar of one habit. Completed days are marked; picking
/// a past day shows and edits its check-ins.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({
    super.key,
    required this.store,
    required this.habitId,
  });

  final AppStore store;
  final String habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final DateTime _today = dateOnly(DateTime.now());
  late DateTime _selected = _today;
  late DateTime _month = monthOf(_today);

  void _select(DateTime d) {
    if (d.isAfter(_today)) return;
    setState(() {
      _selected = d;
      _month = monthOf(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final h = widget.store.habitById(widget.habitId);
        if (h == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: MeEmptyState(
                icon: Icons.delete_outline,
                title: 'Hábito apagado',
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(h.name),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    showHabitSheet(context, widget.store, habit: h),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _body(context, h),
        );
      },
    );
  }

  Widget _body(BuildContext context, Habit h) {
    final theme = Theme.of(context);
    final store = widget.store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MeSpacing.md,
        0,
        MeSpacing.md,
        MeSpacing.xl,
      ),
      children: [
        MeCard(
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
                        Text(
                          habitSummary(h),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Desde ${h.createdAt.day} de '
                          '${ptMonths[h.createdAt.month - 1]}'
                          '${h.createdAt.year == _today.year ? '' : ' de ${h.createdAt.year}'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (h.archived) const MeTag(label: 'Arquivado'),
                ],
              ),
              const SizedBox(height: MeSpacing.md),
              HabitStatsRow(habit: h, store: store),
            ],
          ),
        ),
        const SizedBox(height: MeSpacing.md),
        MeMonthHeader(
          month: _month,
          onChanged: (m) => setState(() => _month = m),
          lastMonth: _today,
          onToday: isSameMonth(_month, _today)
              ? null
              : () => setState(() => _month = monthOf(_today)),
        ),
        const SizedBox(height: MeSpacing.sm),
        MeCard(
          padding: const EdgeInsets.symmetric(
            horizontal: MeSpacing.sm,
            vertical: MeSpacing.md,
          ),
          child: MeMonthGrid(
            month: _month,
            selected: _selected,
            today: _today,
            onSelected: _select,
            markerCount: (d) => store.isComplete(h, d) ? 1 : 0,
          ),
        ),
        const SizedBox(height: MeSpacing.sm),
        _DayPanel(store: store, habit: h, day: _selected),
      ],
    );
  }
}

/// Check-ins of the selected day, editable.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.store,
    required this.habit,
    required this.day,
  });

  final AppStore store;
  final Habit habit;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = store.countOn(habit, day);
    final target = habit.dailyTarget;
    final String status;
    if (day.isBefore(dateOnly(habit.createdAt))) {
      status = 'Antes de começar';
    } else if (count >= target) {
      status = 'Concluído';
    } else if (!isScheduled(habit, day)) {
      status = 'Não previsto';
    } else {
      status = 'Por fazer';
    }
    return MeCard(
      padding: const EdgeInsets.fromLTRB(
        MeSpacing.md,
        MeSpacing.sm,
        MeSpacing.xs,
        MeSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDayLabel(day), style: theme.textTheme.titleMedium),
                Text(
                  target > 1 ? '$count/$target · $status' : status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover registo',
            onPressed: count > 0
                ? () => store.checkIn(habit, day, delta: -1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: 'Registar',
            onPressed: count < target ? () => store.checkIn(habit, day) : null,
            icon: const Icon(Icons.add_circle),
          ),
        ],
      ),
    );
  }
}
