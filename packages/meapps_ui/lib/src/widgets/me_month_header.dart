import 'package:flutter/material.dart';

import '../util/me_dates.dart';

/// "Novembro 2026  [Hoje]  ‹ ›": the month title and navigation shown
/// above a [MeMonthGrid] or a monthly list. Stateless: the host owns the
/// visible [month] and gets the new one (its first day) in [onChanged].
class MeMonthHeader extends StatelessWidget {
  const MeMonthHeader({
    super.key,
    required this.month,
    required this.onChanged,
    this.onToday,
    this.todayLabel = 'Hoje',
    this.lastMonth,
  });

  /// Any day of the visible month.
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  /// Shows a [todayLabel] button that calls this. Pass null to hide it
  /// (e.g. while the current month is already visible).
  final VoidCallback? onToday;
  final String todayLabel;

  /// Last month that can be reached; "Mês seguinte" is disabled on it.
  final DateTime? lastMonth;

  @override
  Widget build(BuildContext context) {
    final atEnd =
        lastMonth != null && !monthOf(month).isBefore(monthOf(lastMonth!));
    return Row(
      children: [
        Expanded(
          child: Text(
            capitalize(formatMonth(month)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (onToday != null)
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
            onPressed: onToday,
            child: Text(todayLabel),
          ),
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: () => onChanged(addMonths(month, -1)),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Mês seguinte',
          onPressed: atEnd ? null : () => onChanged(addMonths(month, 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
