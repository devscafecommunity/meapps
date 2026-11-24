import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/task_tile.dart';

class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final groups = store.upcoming();
    if (groups.isEmpty) {
      return const MeEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nada pela frente',
        message: 'As tarefas a partir de amanhã e sem data aparecem aqui.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        for (final g in groups)
          TaskSection(
            title: g.day == null
                ? 'SEM DATA'
                : formatDayLabel(g.day!).toUpperCase(),
            tasks: g.tasks,
            store: store,
            showDue: false,
          ),
      ],
    );
  }
}
