import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../widgets/habit_widgets.dart';
import 'habit_sheet.dart';

/// Manage habits: edit, reorder (drag handle), archive and delete. Archived
/// habits live in a collapsible section at the end.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.activeHabits;
    final archived = store.archivedHabits;
    if (active.isEmpty && archived.isEmpty) {
      return const Center(
        child: MeEmptyState(
          icon: Icons.checklist,
          title: 'Sem hábitos',
          message: 'Toque em "Novo hábito" para criar o primeiro.',
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
          sliver: SliverReorderableList(
            itemCount: active.length,
            onReorderItem: store.moveHabit,
            proxyDecorator: (child, _, animation) => Material(
              type: MaterialType.transparency,
              elevation: 6 * animation.value,
              child: child,
            ),
            itemBuilder: (context, i) => Padding(
              key: ValueKey('habit-${active[i].id}'),
              padding: const EdgeInsets.only(bottom: MeSpacing.sm),
              child: _HabitTile(habit: active[i], store: store, index: i),
            ),
          ),
        ),
        if (active.isEmpty)
          const SliverToBoxAdapter(
            child: MeEmptyState(
              icon: Icons.archive_outlined,
              title: 'Tudo arquivado',
              message: 'Desarquive um hábito para voltar a registá-lo.',
            ),
          ),
        if (archived.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              MeSpacing.md,
              MeSpacing.sm,
              MeSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: MeCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: const PageStorageKey('archived'),
                  leading: const Icon(Icons.archive_outlined),
                  title: Text('Arquivados (${archived.length})'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  childrenPadding: const EdgeInsets.only(bottom: MeSpacing.sm),
                  children: [
                    for (final h in archived)
                      _HabitTile(
                        key: ValueKey('archived-${h.id}'),
                        habit: h,
                        store: store,
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

enum _Action { edit, archive, unarchive, delete }

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    super.key,
    required this.habit,
    required this.store,
    this.index,
  });

  final Habit habit;
  final AppStore store;

  /// Position in the reorderable list; null for archived habits.
  final int? index;

  void _run(BuildContext context, _Action action) {
    switch (action) {
      case _Action.edit:
        showHabitSheet(context, store, habit: habit);
      case _Action.archive:
        setArchivedWithUndo(context, store, habit, true);
      case _Action.unarchive:
        setArchivedWithUndo(context, store, habit, false);
      case _Action.delete:
        confirmDeleteHabit(context, store, habit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = index;
    final tile = ListTile(
      contentPadding: const EdgeInsets.only(left: MeSpacing.md),
      onTap: () => _run(context, _Action.edit),
      leading: HabitAvatar(habit: habit, radius: 20),
      title: Text(habit.name),
      subtitle: Text(habitSummary(habit)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<_Action>(
            tooltip: 'Mais opções',
            onSelected: (a) => _run(context, a),
            itemBuilder: (_) => [
              const PopupMenuItem(value: _Action.edit, child: Text('Editar')),
              if (habit.archived)
                const PopupMenuItem(
                  value: _Action.unarchive,
                  child: Text('Desarquivar'),
                )
              else
                const PopupMenuItem(
                  value: _Action.archive,
                  child: Text('Arquivar'),
                ),
              const PopupMenuItem(value: _Action.delete, child: Text('Apagar')),
            ],
          ),
          if (i != null)
            ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(
                  MeSpacing.xs,
                  MeSpacing.sm,
                  MeSpacing.md,
                  MeSpacing.sm,
                ),
                child: Icon(Icons.drag_handle),
              ),
            )
          else
            const SizedBox(width: MeSpacing.sm),
        ],
      ),
    );
    return i == null ? tile : MeCard(padding: EdgeInsets.zero, child: tile);
  }
}
