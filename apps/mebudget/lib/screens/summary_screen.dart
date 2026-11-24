import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/money.dart';
import '../data/months.dart';
import '../widgets/category_avatar.dart';
import '../widgets/money_colors.dart';

/// "35%", or "<1%" for tiny non-zero shares.
String formatShare(double share) {
  final pct = (share * 100).round();
  return pct == 0 && share > 0 ? '<1%' : '$pct%';
}

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.store, required this.month});

  final AppStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final totals = store.totals(month);
    if (totals.isEmpty) {
      return ListView(
        children: [
          MeEmptyState(
            icon: Icons.savings_outlined,
            title: 'Sem movimentos',
            message:
                'Ainda não há receitas nem despesas em ${formatMonth(month)}. '
                'Toque em "Novo movimento" para registar.',
          ),
        ],
      );
    }
    final expenses = store.categoryTotals(month, EntryKind.expense);
    final incomes = store.categoryTotals(month, EntryKind.income);

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        _BalanceCard(totals: totals),
        if (expenses.isNotEmpty) ...[
          MeSectionHeader(
            'DESPESAS POR CATEGORIA',
            trailing: Text(formatMoney(totals.expenseCents)),
          ),
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [for (final t in expenses) _CategoryRow(total: t)],
            ),
          ),
        ],
        if (incomes.isNotEmpty) ...[
          MeSectionHeader(
            'RECEITAS POR CATEGORIA',
            trailing: Text(formatMoney(totals.incomeCents)),
          ),
          MeCard(
            padding: const EdgeInsets.symmetric(vertical: MeSpacing.xs),
            child: Column(
              children: [for (final t in incomes) _CategoryRow(total: t)],
            ),
          ),
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.totals});

  final MonthTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo do mês',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MeSpacing.xs),
          Text(
            formatMoney(totals.balanceCents),
            key: const Key('balance'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: balanceColor(totals.balanceCents, scheme),
            ),
          ),
          const SizedBox(height: MeSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Receitas',
                  valueKey: const Key('total-income'),
                  cents: totals.incomeCents,
                  icon: Icons.arrow_downward,
                  color: incomeColor(scheme),
                ),
              ),
              const SizedBox(width: MeSpacing.md),
              Expanded(
                child: _Stat(
                  label: 'Despesas',
                  valueKey: const Key('total-expense'),
                  cents: totals.expenseCents,
                  icon: Icons.arrow_upward,
                  color: expenseColor(scheme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.valueKey,
    required this.cents,
    required this.icon,
    required this.color,
  });

  final String label;
  final Key valueKey;
  final int cents;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: MeSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoney(cents),
                  key: valueKey,
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Amount and share of one category, with a bar against its monthly budget.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.total});

  final CategoryTotal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = total;
    final c = t.category;
    final budget = t.budgetCents;
    final over = t.isOverBudget;
    final barColor = over ? scheme.error : scheme.primary;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MeSpacing.md,
        vertical: MeSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar.of(c, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: theme.textTheme.titleSmall),
                    Text(
                      '${formatShare(t.share)} das '
                      '${c.kind.plural.toLowerCase()}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              Text(formatMoney(t.cents), style: theme.textTheme.titleSmall),
            ],
          ),
          if (budget != null) ...[
            const SizedBox(height: MeSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (t.budgetUsage ?? 0).clamp(0, 1).toDouble(),
                minHeight: 6,
                color: barColor,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: MeSpacing.xs),
            Text(
              over
                  ? 'Excedido em ${formatMoney(t.overBudgetCents)} '
                        '(orçamento ${formatMoney(budget)})'
                  : 'Restam ${formatMoney(budget - t.cents)} '
                        'de ${formatMoney(budget)}',
              style: over
                  ? theme.textTheme.bodySmall?.copyWith(color: scheme.error)
                  : muted,
            ),
          ],
        ],
      ),
    );
  }
}
