import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/reminder_tile.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.store,
    required this.selected,
    required this.onSelected,
  });

  final AppStore store;

  /// Owned by the shell so "Novo lembrete" can default to this day.
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  DateTime get _selected => widget.selected;

  void _today() {
    final today = dateOnly(DateTime.now());
    setState(() => _month = DateTime(today.year, today.month));
    widget.onSelected(today);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.store.remindersOn(_selected);
    final label =
        '${capitalize(ptWeekdays[_selected.weekday - 1])}, '
        '${_selected.day} de ${ptMonths[_selected.month - 1]}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        MeMonthHeader(
          month: _month,
          onChanged: (m) => setState(() => _month = m),
          onToday: _today,
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
            onSelected: (d) {
              if (d.month != _month.month || d.year != _month.year) {
                setState(() => _month = DateTime(d.year, d.month));
              }
              widget.onSelected(d);
            },
            markerCount: (d) => widget.store.remindersOn(d).length,
          ),
        ),
        const SizedBox(height: MeSpacing.sm),
        MeSectionHeader(
          label,
          trailing: Text(
            items.length == 1 ? '1 lembrete' : '${items.length} lembretes',
          ),
        ),
        if (items.isEmpty)
          const MeEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Dia livre',
            message: 'Sem lembretes para este dia.',
          )
        else
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [
                for (final r in items)
                  ReminderTile(
                    reminder: r,
                    store: widget.store,
                    overdue: !r.done && r.when.isBefore(DateTime.now()),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
