import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/money.dart';
import '../widgets/category_avatar.dart';
import 'category_sheet.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.store});

  final AppStore store;

  String _subtitle(Category c) {
    final count = store.entryCount(c.id);
    final budget = c.monthlyBudgetCents;
    return [
      if (budget != null) 'Orçamento ${formatMoney(budget)}/mês',
      if (budget == null && c.kind == EntryKind.expense) 'Sem orçamento',
      count == 1 ? '1 movimento' : '$count movimentos',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        for (final kind in EntryKind.values) ...[
          MeSectionHeader(
            kind.plural.toUpperCase(),
            trailing: IconButton(
              tooltip: 'Nova categoria de ${kind.label.toLowerCase()}',
              visualDensity: VisualDensity.compact,
              onPressed: () => showCategorySheet(context, store, kind: kind),
              icon: const Icon(Icons.add),
            ),
          ),
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [
                for (final c in store.categoriesOf(kind))
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MeSpacing.md,
                    ),
                    leading: CategoryAvatar.of(c),
                    title: Text(c.name),
                    subtitle: Text(_subtitle(c)),
                    trailing: c.isFixed
                        ? const Icon(Icons.lock_outline, size: 18)
                        : null,
                    onTap: () => showCategorySheet(context, store, category: c),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
