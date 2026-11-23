import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final notes = widget.store.notes
        .where((n) => _tag == null || n.tag == _tag)
        .toList();
    final tags = {
      for (final n in widget.store.notes)
        if (n.tag != null) n.tag!,
    };
    final pinned = notes.where((n) => n.pinned).toList();
    final others = notes.where((n) => !n.pinned).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(MeSpacing.md, 0, MeSpacing.md, 96),
      children: [
        const TextField(
          decoration: InputDecoration(
            hintText: 'Pesquisar notas',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: MeSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _tag == null,
                onSelected: (_) => setState(() => _tag = null),
              ),
              for (final t in tags) ...[
                const SizedBox(width: MeSpacing.sm),
                ChoiceChip(
                  label: Text(t),
                  selected: _tag == t,
                  onSelected: (_) => setState(() => _tag = t),
                ),
              ],
            ],
          ),
        ),
        if (notes.isEmpty)
          const MeEmptyState(
            icon: Icons.sticky_note_2_outlined,
            title: 'Sem notas',
            message: 'Toque em "Nova nota" para começar.',
          ),
        if (pinned.isNotEmpty) ...[
          const MeSectionHeader('FIXADAS'),
          _Masonry(notes: pinned, store: widget.store),
        ],
        if (others.isNotEmpty) ...[
          if (pinned.isNotEmpty) const MeSectionHeader('OUTRAS'),
          if (pinned.isEmpty) const SizedBox(height: MeSpacing.md),
          _Masonry(notes: others, store: widget.store),
        ],
      ],
    );
  }
}

/// Two-column staggered layout without extra dependencies.
class _Masonry extends StatelessWidget {
  const _Masonry({required this.notes, required this.store});

  final List<Note> notes;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    Widget column(int start) => Expanded(
      child: Column(
        children: [
          for (var i = start; i < notes.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: MeSpacing.sm + 2),
              child: NoteCard(note: notes[i], store: store),
            ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(0),
        const SizedBox(width: MeSpacing.sm + 2),
        column(1),
      ],
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.store});

  final Note note;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = note.tone.foreground(scheme).withValues(alpha: 0.7);

    return MeCard(
      tone: note.tone,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NoteEditorScreen(store: store, note: note),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(note.title, style: theme.textTheme.titleMedium),
              ),
              if (note.pinned) Icon(Icons.push_pin, size: 16, color: muted),
            ],
          ),
          if (note.body.isNotEmpty) ...[
            const SizedBox(height: MeSpacing.sm),
            Text(
              note.body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (note.checklist.isNotEmpty) ...[
            const SizedBox(height: MeSpacing.sm),
            for (final item in note.checklist.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      item.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: MeSpacing.sm + 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (note.tag != null) MeTag(label: note.tag!, color: muted),
              if (note.reminder != null)
                MeTag(
                  label:
                      '${formatDayLabel(note.reminder!)} ${formatTime(note.reminder!)}',
                  icon: Icons.notifications_active_outlined,
                  color: scheme.tertiary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
