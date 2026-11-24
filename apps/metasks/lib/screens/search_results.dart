import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/task_tile.dart';

/// Tasks matching [query] in title, notes or subtasks, pending first.
class SearchResults extends StatelessWidget {
  const SearchResults({super.key, required this.store, required this.query});

  final AppStore store;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return const MeEmptyState(
        icon: Icons.search,
        title: 'Pesquisar tarefas',
        message: 'Procure por título, notas ou subtarefas.',
      );
    }
    final found = store.search(query);
    if (found.isEmpty) {
      return const MeEmptyState(
        icon: Icons.search_off,
        title: 'Nada encontrado',
        message: 'Nenhuma tarefa corresponde à pesquisa.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        TaskSection(
          title: found.length == 1
              ? '1 RESULTADO'
              : '${found.length} RESULTADOS',
          tasks: found,
          store: store,
        ),
      ],
    );
  }
}
