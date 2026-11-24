import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/money.dart';
import '../widgets/entry_tile.dart';

/// The day a new movement starts on while [month] is on screen: today in the
/// current month, otherwise the last day of a past month or the first day of
/// a future one.
DateTime defaultEntryDate(DateTime month, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  if (isSameMonth(month, today)) return today;
  return month.isBefore(today)
      ? DateTime(month.year, month.month + 1, 0)
      : DateTime(month.year, month.month);
}

/// Creates a movement, or edits [entry] when given. New movements start on
/// [initialDate] (default today). Completes with the saved movement, or null
/// when the sheet is dismissed or the movement deleted.
Future<Entry?> showEntrySheet(
  BuildContext context,
  AppStore store, {
  Entry? entry,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<Entry>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _EntrySheet(store: store, existing: entry, initialDate: initialDate),
  );
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.store, this.existing, this.initialDate});

  final AppStore store;
  final Entry? existing;
  final DateTime? initialDate;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late EntryKind _kind = widget.existing?.kind ?? EntryKind.expense;
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatMoneyInput(widget.existing!.amountCents),
  );
  late final _note = TextEditingController(text: widget.existing?.note);

  /// Last category picked per kind, so toggling back keeps the choice.
  late final Map<EntryKind, String> _categoryByKind = {
    if (widget.existing != null) _kind: widget.existing!.categoryId,
  };
  late DateTime _date = dateOnly(
    widget.existing?.date ?? widget.initialDate ?? DateTime.now(),
  );
  final DateTime _today = dateOnly(DateTime.now());
  bool _invalidAmount = false;

  bool get _editing => widget.existing != null;
  DateTime get _yesterday =>
      DateTime(_today.year, _today.month, _today.day - 1);

  String get _categoryId {
    final options = widget.store.categoriesOf(_kind);
    final chosen = _categoryByKind[_kind];
    if (options.any((c) => c.id == chosen)) return chosen!;
    return options.isEmpty ? _kind.otherCategoryId : options.first.id;
  }

  bool get _isCustomDate =>
      !isSameDay(_date, _today) && !isSameDay(_date, _yesterday);

  Future<void> _pickDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final cents = parseMoney(_amount.text);
    if (cents == null) {
      setState(() => _invalidAmount = true);
      return;
    }
    final existing = widget.existing;
    final e = existing == null
        ? Entry(
            id: newId('e'),
            kind: _kind,
            amountCents: cents,
            categoryId: _categoryId,
            date: _date,
            note: _note.text.trim(),
            createdAt: DateTime.now(),
          )
        : existing.copyWith(
            kind: _kind,
            amountCents: cents,
            categoryId: _categoryId,
            date: _date,
            note: _note.text.trim(),
          );
    Navigator.pop(context, e);
    await widget.store.saveEntry(e);
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await deleteEntryWithUndo(messenger, widget.store, existing);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = widget.store.categoriesOf(_kind);
    final selectedCategory = _categoryId;

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
                  _editing ? 'Editar movimento' : 'Novo movimento',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (_editing)
                IconButton(
                  tooltip: 'Apagar',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<EntryKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: EntryKind.expense,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('Despesa'),
                ),
                ButtonSegment(
                  value: EntryKind.income,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('Receita'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _categoryByKind[_kind] = selectedCategory;
                _kind = s.first;
              }),
            ),
          ),
          const SizedBox(height: MeSpacing.md),
          TextField(
            key: const Key('amount'),
            controller: _amount,
            autofocus: !_editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s€]')),
            ],
            style: theme.textTheme.headlineSmall,
            onChanged: (_) {
              if (_invalidAmount) setState(() => _invalidAmount = false);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: '0,00',
              suffixText: '€',
              errorText: _invalidAmount ? 'Indique um valor válido' : null,
            ),
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Categoria', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.sm,
            children: [
              for (final c in categories)
                ChoiceChip(
                  // No checkmark: it would cover the icon.
                  showCheckmark: false,
                  avatar: Icon(c.icon.icon, size: 18),
                  label: Text(c.name),
                  selected: c.id == selectedCategory,
                  onSelected: (_) =>
                      setState(() => _categoryByKind[_kind] = c.id),
                ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Data', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Hoje'),
                selected: isSameDay(_date, _today),
                onSelected: (_) => setState(() => _date = _today),
              ),
              ChoiceChip(
                label: const Text('Ontem'),
                selected: isSameDay(_date, _yesterday),
                onSelected: (_) => setState(() => _date = _yesterday),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _isCustomDate
                      ? '${formatDayLabel(_date)}'
                            '${_date.year == _today.year ? '' : ' ${_date.year}'}'
                      : 'Escolher…',
                ),
                selected: _isCustomDate,
                onSelected: (_) => _pickDate(),
              ),
            ],
          ),
          const SizedBox(height: MeSpacing.md),
          TextField(
            key: const Key('note'),
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nota (opcional)'),
          ),
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
