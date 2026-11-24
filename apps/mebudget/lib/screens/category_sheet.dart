import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/category_icon.dart';
import '../data/money.dart';
import '../widgets/category_avatar.dart';

/// Names of the colours a category can take, in [MeTone] order.
const toneLabels = {
  MeTone.plain: 'Neutra',
  MeTone.primary: 'Principal',
  MeTone.secondary: 'Secundária',
  MeTone.tertiary: 'Destaque',
};

/// Creates a category of [kind], or edits [category] when given.
Future<void> showCategorySheet(
  BuildContext context,
  AppStore store, {
  Category? category,
  EntryKind kind = EntryKind.expense,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _CategorySheet(store: store, existing: category, initialKind: kind),
  );
}

/// Asks before deleting; the movements of the category go to "Outros".
Future<bool> confirmDeleteCategory(
  BuildContext context,
  AppStore store,
  Category c,
) async {
  final count = store.entryCount(c.id);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Apagar categoria?'),
      content: Text(switch (count) {
        0 => 'Esta categoria não tem movimentos.',
        1 => 'O movimento desta categoria passa para "Outros".',
        _ => 'Os $count movimentos desta categoria passam para "Outros".',
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.store,
    required this.initialKind,
    this.existing,
  });

  final AppStore store;
  final EntryKind initialKind;
  final Category? existing;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _budget = TextEditingController(
    text: switch (widget.existing?.monthlyBudgetCents) {
      final int cents => formatMoneyInput(cents),
      null => '',
    },
  );
  late EntryKind _kind = widget.existing?.kind ?? widget.initialKind;
  late CategoryIcon _icon = widget.existing?.icon ?? CategoryIcon.other;
  late MeTone _tone = widget.existing?.tone ?? MeTone.primary;
  bool _emptyName = false;
  bool _invalidBudget = false;

  bool get _editing => widget.existing != null;

  Future<void> _save() async {
    final name = _name.text.trim();
    final budgetText = _budget.text.trim();
    final budget = budgetText.isEmpty ? null : parseMoney(budgetText);
    final invalidBudget =
        _kind == EntryKind.expense && budgetText.isNotEmpty && budget == null;
    if (name.isEmpty || invalidBudget) {
      setState(() {
        _emptyName = name.isEmpty;
        _invalidBudget = invalidBudget;
      });
      return;
    }
    final existing = widget.existing;
    final c = existing == null
        ? Category(
            id: newId('c'),
            name: name,
            kind: _kind,
            icon: _icon,
            tone: _tone,
            monthlyBudgetCents: budget,
          )
        : existing.copyWith(
            name: name,
            icon: _icon,
            tone: _tone,
            monthlyBudgetCents: budget,
          );
    Navigator.pop(context);
    await widget.store.saveCategory(c);
  }

  Future<void> _delete() async {
    final c = widget.existing!;
    final store = widget.store;
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDeleteCategory(context, store, c) || !mounted) return;
    Navigator.pop(context);
    final deleted = await store.deleteCategory(c.id);
    if (deleted == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Categoria apagada'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => store.restoreCategory(deleted),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final existing = widget.existing;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  _editing ? 'Editar categoria' : 'Nova categoria',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (existing != null && !existing.isFixed)
                IconButton(
                  tooltip: 'Apagar',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          if (!_editing) ...[
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<EntryKind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EntryKind.expense,
                    label: Text('Despesa'),
                  ),
                  ButtonSegment(
                    value: EntryKind.income,
                    label: Text('Receita'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
            ),
            const SizedBox(height: MeSpacing.md),
          ],
          Row(
            children: [
              CategoryAvatar(icon: _icon, tone: _tone, radius: 24),
              const SizedBox(width: MeSpacing.md),
              Expanded(
                child: TextField(
                  key: const Key('category-name'),
                  controller: _name,
                  autofocus: !_editing,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_emptyName) setState(() => _emptyName = false);
                  },
                  decoration: InputDecoration(
                    hintText: 'Nome da categoria',
                    errorText: _emptyName ? 'Escreva um nome' : null,
                  ),
                ),
              ),
            ],
          ),
          if (existing != null && existing.isFixed) ...[
            const SizedBox(height: MeSpacing.sm),
            Text(
              'Categoria fixa: recebe os movimentos das categorias apagadas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: MeSpacing.md),
          Text('Ícone', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.sm,
            children: [
              for (final i in CategoryIcon.values)
                _Choice(
                  selected: i == _icon,
                  color: scheme.surfaceContainerHigh,
                  onTap: () => setState(() => _icon = i),
                  child: Icon(i.icon, size: 22),
                ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Cor', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            children: [
              for (final t in MeTone.values)
                Tooltip(
                  message: toneLabels[t],
                  child: _Choice(
                    selected: t == _tone,
                    color: toneBackground(t, scheme),
                    selectedColor: toneBackground(t, scheme),
                    onTap: () => setState(() => _tone = t),
                    child: t == _tone
                        ? Icon(
                            Icons.check,
                            size: 20,
                            color: toneForeground(t, scheme),
                          )
                        : null,
                  ),
                ),
            ],
          ),
          if (_kind == EntryKind.expense) ...[
            const SizedBox(height: MeSpacing.md),
            Text('Orçamento mensal', style: theme.textTheme.labelLarge),
            const SizedBox(height: MeSpacing.sm),
            TextField(
              key: const Key('category-budget'),
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s€]')),
              ],
              onChanged: (_) {
                if (_invalidBudget) setState(() => _invalidBudget = false);
              },
              decoration: InputDecoration(
                hintText: 'Sem orçamento',
                suffixText: '€',
                errorText: _invalidBudget ? 'Indique um valor válido' : null,
              ),
            ),
          ],
          const SizedBox(height: MeSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}

/// Round selectable swatch (icon or colour).
class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.color,
    required this.onTap,
    this.selectedColor,
    this.child,
  });

  final bool selected;
  final Color color;

  /// Defaults to the primary container.
  final Color? selectedColor;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? selectedColor ?? scheme.primaryContainer : color,
      shape: CircleBorder(
        side: BorderSide(
          width: 2,
          color: selected ? scheme.primary : Colors.transparent,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconTheme.merge(
            data: IconThemeData(
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
