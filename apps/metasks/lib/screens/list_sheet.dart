import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

/// Names shown as tooltips on the colour swatches.
const toneNames = {
  MeTone.plain: 'Neutra',
  MeTone.primary: 'Principal',
  MeTone.secondary: 'Secundária',
  MeTone.tertiary: 'Destaque',
};

/// Creates a list, or renames / recolours [list] when given.
Future<void> showListSheet(
  BuildContext context,
  AppStore store, {
  TaskList? list,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ListSheet(store: store, existing: list),
  );
}

class _ListSheet extends StatefulWidget {
  const _ListSheet({required this.store, this.existing});

  final AppStore store;
  final TaskList? existing;

  @override
  State<_ListSheet> createState() => _ListSheetState();
}

class _ListSheetState extends State<_ListSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late MeTone _tone = widget.existing?.tone ?? MeTone.primary;
  bool _emptyName = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _emptyName = true);
      return;
    }
    final store = widget.store;
    final list =
        widget.existing?.copyWith(name: name, tone: _tone) ??
        TaskList(
          id: newId('l'),
          name: name,
          tone: _tone,
          position: store.nextListPosition,
        );
    Navigator.pop(context);
    await store.saveList(list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            widget.existing == null ? 'Nova lista' : 'Editar lista',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: MeSpacing.md),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_emptyName) setState(() => _emptyName = false);
            },
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'Nome da lista',
              errorText: _emptyName ? 'Escreva um nome' : null,
            ),
          ),
          const SizedBox(height: MeSpacing.md),
          Text('Cor', style: theme.textTheme.labelLarge),
          const SizedBox(height: MeSpacing.sm),
          Row(
            children: [
              for (final t in MeTone.values)
                Padding(
                  padding: const EdgeInsets.only(right: MeSpacing.md),
                  child: Tooltip(
                    message: toneNames[t],
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _tone = t),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.background(scheme),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: t == _tone
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: t == _tone ? 3 : 1,
                          ),
                        ),
                        child: t == _tone
                            ? Icon(Icons.check, color: t.foreground(scheme))
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
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
