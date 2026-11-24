import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

/// Creates a habit, or edits [habit] when given.
Future<void> showHabitSheet(
  BuildContext context,
  AppStore store, {
  Habit? habit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HabitSheet(store: store, existing: habit),
  );
}

const _toneLabels = {
  MeTone.plain: 'Neutra',
  MeTone.primary: 'Principal',
  MeTone.secondary: 'Suave',
  MeTone.tertiary: 'Destaque',
};

class _HabitSheet extends StatefulWidget {
  const _HabitSheet({required this.store, this.existing});

  final AppStore store;
  final Habit? existing;

  @override
  State<_HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<_HabitSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late HabitIcon _icon = widget.existing?.icon ?? HabitIcon.other;
  late MeTone _tone = widget.existing?.tone ?? MeTone.primary;
  late int _weekdays = widget.existing?.weekdays ?? Weekdays.all;
  late int _target = widget.existing?.dailyTarget ?? 1;
  bool _emptyName = false;

  static const _maxTarget = 99;

  bool get _editing => widget.existing != null;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _emptyName = true);
      return;
    }
    if (_weekdays == 0) return;
    final existing = widget.existing;
    final h = existing == null
        ? Habit(
            id: newId('h'),
            name: name,
            icon: _icon,
            tone: _tone,
            weekdays: _weekdays,
            dailyTarget: _target,
            createdAt: dateOnly(DateTime.now()),
          )
        : existing.copyWith(
            name: name,
            icon: _icon,
            tone: _tone,
            weekdays: _weekdays,
            dailyTarget: _target,
          );
    Navigator.pop(context);
    await widget.store.saveHabit(h);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: MeSpacing.md, bottom: MeSpacing.sm),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    return SingleChildScrollView(
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
          Text(
            _editing ? 'Editar hábito' : 'Novo hábito',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: MeSpacing.md),
          TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_emptyName) setState(() => _emptyName = false);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'Ex.: Beber água',
              errorText: _emptyName ? 'Escreva um nome' : null,
            ),
          ),
          label('Ícone'),
          Wrap(
            spacing: MeSpacing.xs,
            runSpacing: MeSpacing.xs,
            children: [
              for (final i in HabitIcon.values)
                IconButton(
                  tooltip: i.label,
                  isSelected: i == _icon,
                  onPressed: () => setState(() => _icon = i),
                  style: IconButton.styleFrom(
                    backgroundColor: i == _icon
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    foregroundColor: i == _icon
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  icon: Icon(i.icon),
                ),
            ],
          ),
          label('Cor'),
          Wrap(
            spacing: MeSpacing.sm,
            children: [
              for (final t in MeTone.values)
                IconButton(
                  tooltip: 'Cor ${_toneLabels[t]}',
                  onPressed: () => setState(() => _tone = t),
                  style: IconButton.styleFrom(
                    backgroundColor: t.background(scheme),
                    foregroundColor: t.foreground(scheme),
                    side: BorderSide(
                      color: t == _tone ? scheme.onSurface : scheme.outline,
                      width: t == _tone ? 2 : 1,
                    ),
                  ),
                  icon: Icon(t == _tone ? Icons.check : _icon.icon),
                ),
            ],
          ),
          label('Dias'),
          Wrap(
            spacing: MeSpacing.xs,
            runSpacing: MeSpacing.xs,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(ptWeekdaysShort[d - 1]),
                  showCheckmark: false,
                  // Compact so the whole week fits on one line.
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  selected: Weekdays.has(_weekdays, d),
                  onSelected: (_) =>
                      setState(() => _weekdays = Weekdays.toggle(_weekdays, d)),
                ),
            ],
          ),
          if (_weekdays == 0)
            Padding(
              padding: const EdgeInsets.only(top: MeSpacing.xs),
              child: Text(
                'Escolha pelo menos um dia',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          label('Meta diária'),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Menos',
                onPressed: _target > 1 ? () => setState(() => _target--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_target',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Mais',
                onPressed: _target < _maxTarget
                    ? () => setState(() => _target++)
                    : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: MeSpacing.md),
              Expanded(
                child: Text(
                  _target == 1 ? 'vez por dia' : 'vezes por dia',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MeSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _weekdays == 0 ? null : _save,
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
