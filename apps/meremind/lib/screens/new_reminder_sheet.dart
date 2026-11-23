import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

Future<void> showNewReminderSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NewReminderSheet(store: store),
  );
}

class _NewReminderSheet extends StatefulWidget {
  const _NewReminderSheet({required this.store});

  final AppStore store;

  @override
  State<_NewReminderSheet> createState() => _NewReminderSheetState();
}

class _NewReminderSheetState extends State<_NewReminderSheet> {
  final _title = TextEditingController();
  int _when = 0;
  Repeat _repeat = Repeat.never;

  static const _options = [
    'Hoje 18:00',
    'Amanhã 09:00',
    'Próx. semana',
    'Escolher…',
  ];

  DateTime _resolve() {
    final n = DateTime.now();
    return switch (_when) {
      0 => DateTime(n.year, n.month, n.day, 18),
      1 => DateTime(n.year, n.month, n.day + 1, 9),
      _ => DateTime(n.year, n.month, n.day + 7, 9),
    };
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MeSpacing.md,
        0,
        MeSpacing.md,
        MeSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Novo lembrete', style: theme.textTheme.titleLarge),
          const SizedBox(height: MeSpacing.md),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'O que quer lembrar?'),
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Quando', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            children: [
              for (var i = 0; i < _options.length; i++)
                ChoiceChip(
                  label: Text(_options[i]),
                  selected: _when == i,
                  onSelected: (_) => setState(() => _when = i),
                ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Repetir', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          SegmentedButton<Repeat>(
            showSelectedIcon: false,
            segments: [
              for (final r in Repeat.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_repeat},
            onSelectionChanged: (s) => setState(() => _repeat = s.first),
          ),
          const SizedBox(height: MeSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = _title.text.trim();
                if (title.isEmpty) return;
                widget.store.add(
                  Reminder(
                    id: 'r${DateTime.now().microsecondsSinceEpoch}',
                    title: title,
                    when: _resolve(),
                    repeat: _repeat,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
