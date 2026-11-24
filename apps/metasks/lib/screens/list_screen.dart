import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/task_tile.dart';
import 'list_sheet.dart';
import 'task_sheet.dart';

Future<void> openList(BuildContext context, AppStore store, TaskList list) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ListScreen(store: store, listId: list.id),
    ),
  );
}

/// Pending tasks of one list plus a collapsible "Concluídas" section.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.store, required this.listId});

  final AppStore store;
  final String listId;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _showDone = false;

  Future<void> _confirmDelete(TaskList list) async {
    final store = widget.store;
    final ok = await confirmDelete(
      context,
      title: 'Apagar lista?',
      message:
          'As tarefas de "${list.name}" passam para '
          '"${store.inbox.name}".',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final deleted = await store.deleteList(list.id);
    if (deleted == null) return;
    showUndoSnackBar(
      messenger,
      'Lista apagada',
      () => store.restoreList(deleted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.listById(widget.listId);
        // Just deleted: the route is on its way out.
        if (list == null) return const Scaffold();
        final pending = store.pendingIn(list.id);
        final done = store.doneIn(list.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(list.name),
            actions: [
              IconButton(
                tooltip: 'Editar lista',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showListSheet(context, store, list: list),
              ),
              if (!list.isInbox)
                IconButton(
                  tooltip: 'Apagar lista',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(list),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              MeSpacing.md,
              0,
              MeSpacing.md,
              96,
            ),
            children: [
              if (pending.isEmpty)
                MeEmptyState(
                  icon: Icons.task_alt,
                  title: done.isEmpty ? 'Lista vazia' : 'Tudo feito',
                  message: 'Toque em "Nova tarefa" para acrescentar.',
                ),
              TaskSection(
                title: 'POR FAZER',
                tasks: pending,
                store: store,
                showList: false,
              ),
              TaskSection(
                title: 'CONCLUÍDAS · ${done.length}',
                tasks: done,
                store: store,
                showList: false,
                collapsed: !_showDone,
                onToggle: () => setState(() => _showDone = !_showDone),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                showTaskSheet(context, store, initialListId: list.id),
            icon: const Icon(Icons.add_task),
            label: const Text('Nova tarefa'),
          ),
        );
      },
    );
  }
}
