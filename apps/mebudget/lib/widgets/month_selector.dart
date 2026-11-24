import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/months.dart';

/// `‹ novembro 2026 ›`. Stateless: the host owns the visible [month]. Away
/// from the current month a button brings it back.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
    this.today,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final current = monthOf(today ?? DateTime.now());
    final isCurrent = isSameMonth(month, current);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MeSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: () => onChanged(addMonths(month, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    formatMonth(month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!isCurrent)
                  IconButton(
                    tooltip: 'Este mês',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onChanged(current),
                    icon: const Icon(Icons.today_outlined, size: 20),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Mês seguinte',
            onPressed: () => onChanged(addMonths(month, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
