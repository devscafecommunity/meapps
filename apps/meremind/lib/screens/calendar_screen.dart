import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/reminder_tile.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = dateOnly(DateTime.now());

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _today() => setState(() {
    _selected = dateOnly(DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.store.remindersOn(_selected);
    final label =
        '${capitalize(ptWeekdays[_selected.weekday - 1])}, '
        '${_selected.day} de ${ptMonths[_selected.month - 1]}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${capitalize(ptMonths[_month.month - 1])} ${_month.year}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
              onPressed: _today,
              child: const Text('Hoje'),
            ),
            IconButton(
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
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
            onSelected: (d) => setState(() => _selected = d),
            markerCount: (d) => widget.store.remindersOn(d).length,
          ),
        ),
        const SizedBox(height: MeSpacing.sm),
        MeSectionHeader(label, trailing: Text('${items.length} lembretes')),
        if (items.isEmpty)
          const MeEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Dia livre',
            message: 'Sem lembretes para este dia.',
          )
        else
          for (final r in items)
            ReminderTile(reminder: r, onToggle: () => widget.store.toggle(r)),
      ],
    );
  }
}
