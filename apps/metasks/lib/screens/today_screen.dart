import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/task_tile.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final overdue = store.overdue();
    final today = store.dueToday();
    final done = store.doneToday();

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        if (overdue.isEmpty && today.isEmpty)
          MeEmptyState(
            icon: Icons.task_alt,
            title: done.isEmpty ? 'Nada para hoje' : 'Tudo feito por hoje',
            message: done.isEmpty
                ? 'Toque em "Nova tarefa" para planear o dia.'
                : 'Não há mais tarefas para hoje.',
          ),
        TaskSection(
          title: 'EM ATRASO',
          tasks: overdue,
          store: store,
          color: Theme.of(context).colorScheme.error,
        ),
        TaskSection(title: 'HOJE', tasks: today, store: store, showDue: false),
        TaskSection(
          title: 'CONCLUÍDAS HOJE',
          tasks: done,
          store: store,
          showDue: false,
        ),
      ],
    );
  }
}
