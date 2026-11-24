import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/habit.dart';

/// One week (Monday first) of selectable days with previous/next week
/// navigation. Days after [today] cannot be picked. Stateless: the host owns
/// the [selected] day, and the visible week is the one containing it.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.today,
    this.progress,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final DateTime? today;

  /// Share (0-1) of the day's goals met, shown as a dot under the day;
  /// null or 0 shows nothing.
  final double? Function(DateTime day)? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = dateOnly(today ?? DateTime.now());
    final start = weekStart(selected);
    final thisWeek = weekStart(now);
    final weeksBack = daysBetween(start, thisWeek) ~/ 7;

    void shift(int weeks) {
      final day = addDays(selected, 7 * weeks);
      onSelected(day.isAfter(now) ? now : day);
    }

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: MeSpacing.sm),
            Expanded(
              child: Text(switch (weeksBack) {
                0 => 'Esta semana',
                1 => 'Semana passada',
                _ => _range(start, addDays(start, 6)),
              }, style: theme.textTheme.titleMedium),
            ),
            if (!isSameDay(selected, now))
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                onPressed: () => onSelected(now),
                child: const Text('Hoje'),
              ),
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: () => shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Semana seguinte',
              onPressed: weeksBack > 0 ? () => shift(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: MeSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: _day(context, addDays(start, i), now)),
          ],
        ),
      ],
    );
  }

  static String _range(DateTime a, DateTime b) => a.month == b.month
      ? '${a.day}–${b.day} ${ptMonthsShort[b.month - 1]}'
      : '${a.day} ${ptMonthsShort[a.month - 1]} – '
            '${b.day} ${ptMonthsShort[b.month - 1]}';

  Widget _day(BuildContext context, DateTime day, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final future = day.isAfter(now);
    final isSelected = isSameDay(day, selected);
    final isToday = isSameDay(day, now);
    final p = future ? null : progress?.call(day);
    final fg = isSelected
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: future ? 0.38 : 1);

    return InkResponse(
      onTap: future ? null : () => onSelected(day),
      radius: 26,
      child: Column(
        children: [
          Text(
            ptWeekdaysShort[day.weekday - 1],
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MeSpacing.xs),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? scheme.primary : null,
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p == null || p <= 0
                  ? Colors.transparent
                  : scheme.tertiary.withValues(alpha: p >= 1 ? 1 : 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
