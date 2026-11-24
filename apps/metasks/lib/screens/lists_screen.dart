import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import 'list_screen.dart';
import 'list_sheet.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        MeSectionHeader(
          'AS MINHAS LISTAS',
          trailing: TextButton.icon(
            onPressed: () => showListSheet(context, store),
            icon: const Icon(Icons.add),
            label: const Text('Nova lista'),
          ),
        ),
        for (final l in store.lists)
          Padding(
            padding: const EdgeInsets.only(bottom: MeSpacing.sm),
            child: ListCard(
              list: l,
              pending: store.pendingCount(l.id),
              onTap: () => openList(context, store, l),
            ),
          ),
      ],
    );
  }
}

class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.list,
    required this.pending,
    required this.onTap,
  });

  final TaskList list;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = list.tone
        .foreground(theme.colorScheme)
        .withValues(alpha: 0.7);
    final summary = switch (pending) {
      0 => 'Nada por fazer',
      1 => '1 tarefa por fazer',
      _ => '$pending tarefas por fazer',
    };
    return MeCard(
      tone: list.tone,
      onTap: onTap,
      child: Row(
        children: [
          Icon(list.isInbox ? Icons.inbox_outlined : Icons.list_alt),
          const SizedBox(width: MeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(list.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}
