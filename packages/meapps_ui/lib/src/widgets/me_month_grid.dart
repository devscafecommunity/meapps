import 'package:flutter/material.dart';

import '../tokens.dart';
import '../util/me_dates.dart';

/// Month grid (weeks start on Monday). Stateless: the host owns the visible
/// [month] and the [selected] day.
class MeMonthGrid extends StatelessWidget {
  const MeMonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.onSelected,
    this.markerCount,
    this.today,
  });

  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Number of dots (0-3 shown) below a day.
  final int Function(DateTime day)? markerCount;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today ?? DateTime.now();
    final lead = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final w in ptWeekdaysShort)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: MeSpacing.sm),
                    child: Text(
                      w,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(context, r * 7 + c - lead + 1, days, now)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int days, DateTime now) {
    if (day < 1 || day > days) return const SizedBox(height: 52);
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime(month.year, month.month, day);
    final isSelected = isSameDay(date, selected);
    final isToday = isSameDay(date, now);
    final markers = (markerCount?.call(date) ?? 0).clamp(0, 3);

    return SizedBox(
      height: 52,
      child: InkResponse(
        onTap: () => onSelected(date),
        radius: 26,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                '$day',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < markers; i++)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.tertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
