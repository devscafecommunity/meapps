import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

/// Habit icon inside a progress ring that fills up to the daily target;
/// a check replaces the icon once it is reached.
class HabitRing extends StatelessWidget {
  const HabitRing({
    super.key,
    required this.habit,
    required this.count,
    this.color,
    this.size = 48,
  });

  final Habit habit;
  final int count;

  /// Defaults to the foreground of the habit's tone.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? habit.tone.foreground(Theme.of(context).colorScheme);
    final done = count >= habit.dailyTarget;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: (count / habit.dailyTarget).clamp(0, 1).toDouble(),
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              color: fg,
              backgroundColor: fg.withValues(alpha: 0.15),
            ),
          ),
          Icon(
            done ? Icons.check_rounded : habit.icon.icon,
            size: size * 0.46,
            color: fg,
          ),
        ],
      ),
    );
  }
}

/// Round icon in the habit's colours, for lists.
class HabitAvatar extends StatelessWidget {
  const HabitAvatar({super.key, required this.habit, this.radius = 22});

  final Habit habit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = habit.tone == MeTone.plain ? MeTone.primary : habit.tone;
    return CircleAvatar(
      radius: radius,
      backgroundColor: tone.background(scheme),
      child: Icon(
        habit.icon.icon,
        size: radius,
        color: tone.foreground(scheme),
      ),
    );
  }
}

/// "Todos os dias · 8 por dia".
String habitSummary(Habit h) => [
  Weekdays.label(h.weekdays),
  if (h.dailyTarget > 1) '${h.dailyTarget} por dia',
].join(' · ');

String daysLabel(int n) => n == 1 ? '1 dia' : '$n dias';

String rateLabel(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';

/// A habit on the "Hoje" tab: tap (or "+") adds a check-in, long-press (or
/// "−") removes one. [muted] is for habits not scheduled that day.
class HabitCheckCard extends StatelessWidget {
  const HabitCheckCard({
    super.key,
    required this.habit,
    required this.store,
    required this.day,
    this.muted = false,
    this.showStreak = false,
  });

  final Habit habit;
  final AppStore store;
  final DateTime day;
  final bool muted;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = muted ? MeTone.plain : habit.tone;
    final fg = tone.foreground(scheme);
    final count = store.countOn(habit, day);
    final target = habit.dailyTarget;
    final done = count >= target;
    final streak = showStreak ? store.currentStreak(habit) : 0;
    final status = target > 1
        ? '$count/$target${done ? ' · Concluído' : ''}'
        : done
        ? 'Concluído'
        : 'Toque para registar';

    void add() => store.checkIn(habit, day);
    void remove() => store.checkIn(habit, day, delta: -1);

    return Opacity(
      opacity: muted ? 0.7 : 1,
      child: GestureDetector(
        onLongPress: count > 0 ? remove : null,
        child: MeCard(
          tone: tone,
          onTap: done ? null : add,
          padding: const EdgeInsets.fromLTRB(
            MeSpacing.md,
            MeSpacing.sm + 4,
            MeSpacing.xs,
            MeSpacing.sm + 4,
          ),
          child: Row(
            children: [
              HabitRing(habit: habit, count: count, color: fg, size: 44),
              const SizedBox(width: MeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: MeSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.75),
                          ),
                        ),
                        if (streak > 0)
                          MeTag(
                            label: daysLabel(streak),
                            icon: Icons.local_fire_department,
                            color: fg,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (count > 0)
                IconButton(
                  tooltip: 'Remover registo',
                  color: fg,
                  onPressed: remove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              IconButton(
                tooltip: 'Registar',
                color: fg,
                onPressed: done ? null : add,
                icon: Icon(done ? Icons.check_circle : Icons.add_circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Current streak, best streak and 30-day completion rate.
class HabitStatsRow extends StatelessWidget {
  const HabitStatsRow({super.key, required this.habit, required this.store});

  final Habit habit;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            icon: Icons.local_fire_department,
            value: daysLabel(store.currentStreak(habit)),
            label: 'Sequência',
          ),
        ),
        Expanded(
          child: _Stat(
            icon: Icons.emoji_events_outlined,
            value: daysLabel(store.bestStreak(habit)),
            label: 'Melhor',
          ),
        ),
        Expanded(
          child: _Stat(
            icon: Icons.percent,
            value: rateLabel(store.completionRate(habit)),
            label: '30 dias',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.tertiary),
            const SizedBox(width: MeSpacing.xs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

// --- Actions with undo --------------------------------------------------

Future<void> setArchivedWithUndo(
  BuildContext context,
  AppStore store,
  Habit h,
  bool archived,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await store.setArchived(h.id, archived);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(archived ? 'Hábito arquivado' : 'Hábito desarquivado'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => store.setArchived(h.id, !archived),
        ),
      ),
    );
}

/// Asks for confirmation, deletes the habit with its check-ins and offers
/// "Desfazer" (which brings the check-ins back too).
Future<void> confirmDeleteHabit(
  BuildContext context,
  AppStore store,
  Habit h,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Apagar hábito?'),
      content: Text('Os registos de "${h.name}" também são apagados.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final removed = await store.deleteHabit(h.id);
  if (removed == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: const Text('Hábito apagado'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => store.restoreHabit(removed),
        ),
      ),
    );
}
