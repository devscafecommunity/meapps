import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/habit_widgets.dart';
import '../widgets/week_strip.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _day = dateOnly(DateTime.now());

  /// Share of the habits scheduled on [day] that were completed.
  double? _progress(DateTime day) {
    final scheduled = widget.store.habitsOn(day).scheduled;
    if (scheduled.isEmpty) return null;
    final done = scheduled.where((h) => widget.store.isComplete(h, day));
    return done.length / scheduled.length;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (store.activeHabits.isEmpty) {
      return const Center(
        child: MeEmptyState(
          icon: Icons.track_changes,
          title: 'Sem hábitos',
          message: 'Toque em "Novo hábito" para começar.',
        ),
      );
    }

    final isToday = isSameDay(_day, DateTime.now());
    final (:scheduled, :unscheduled) = store.habitsOn(_day);
    final done = scheduled.where((h) => store.isComplete(h, _day)).length;
    final total = scheduled.length;
    final label = isToday
        ? 'Hoje, ${_day.day} de ${ptMonths[_day.month - 1]}'
        : '${capitalize(ptWeekdays[_day.weekday - 1])}, '
              '${_day.day} de ${ptMonths[_day.month - 1]}';

    Widget card(Habit h, {bool muted = false}) => Padding(
      padding: const EdgeInsets.only(bottom: MeSpacing.sm),
      child: HabitCheckCard(
        key: ValueKey('check-${h.id}'),
        habit: h,
        store: store,
        day: _day,
        muted: muted,
        showStreak: isToday && !muted,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        MeCard(
          padding: const EdgeInsets.symmetric(
            horizontal: MeSpacing.xs,
            vertical: MeSpacing.sm,
          ),
          child: WeekStrip(
            selected: _day,
            onSelected: (d) => setState(() => _day = d),
            progress: _progress,
          ),
        ),
        const SizedBox(height: MeSpacing.sm),
        MeSectionHeader(
          label,
          trailing: total == 0
              ? null
              : Text(
                  '$done de $total ${total == 1 ? 'concluído' : 'concluídos'}',
                ),
        ),
        if (total == 0)
          MeEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nada previsto',
            message: unscheduled.isEmpty
                ? 'Não havia hábitos neste dia.'
                : 'Pode registar na mesma os hábitos abaixo.',
          ),
        for (final h in scheduled) card(h),
        if (unscheduled.isNotEmpty) ...[
          MeSectionHeader(
            isToday ? 'NÃO PREVISTOS HOJE' : 'NÃO PREVISTOS NESTE DIA',
          ),
          for (final h in unscheduled) card(h, muted: true),
        ],
      ],
    );
  }
}
