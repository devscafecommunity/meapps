import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/money.dart';
import '../data/months.dart';
import '../widgets/entry_tile.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key, required this.store, required this.month});

  final AppStore store;
  final DateTime month;

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  String? _categoryId;

  /// Chip label; a name used by both kinds (e.g. "Outros") says which.
  String _chipLabel(Category c, List<Category> used) {
    final clash = used.any((o) => o.id != c.id && o.name == c.name);
    return clash ? '${c.name} (${c.kind.label.toLowerCase()})' : c.name;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final month = widget.month;
    final used = store.categoriesUsedIn(month);
    // The filtered category may have no movements in another month.
    if (_categoryId != null && !used.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }
    final groups = store.entriesByDay(month, categoryId: _categoryId);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        if (used.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                for (final c in used) ...[
                  const SizedBox(width: MeSpacing.sm),
                  ChoiceChip(
                    // No checkmark: it would cover the icon.
                    showCheckmark: false,
                    avatar: Icon(c.icon.icon, size: 18),
                    label: Text(_chipLabel(c, used)),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
                ],
              ],
            ),
          ),
        if (groups.isEmpty)
          MeEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Sem movimentos',
            message: 'Nenhum movimento em ${formatMonth(month)}.',
          ),
        for (final g in groups) ...[
          MeSectionHeader(
            formatDayLabel(g.day),
            trailing: Text(
              formatMoney(g.netCents, signed: true),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [
                for (final e in g.entries) EntryTile(entry: e, store: store),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
