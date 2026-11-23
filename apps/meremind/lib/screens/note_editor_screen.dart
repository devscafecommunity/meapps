import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.store, this.note});

  final AppStore store;
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late final List<ChecklistItem> _items = [
    for (final i in widget.note?.checklist ?? const <ChecklistItem>[])
      ChecklistItem(i.text, done: i.done),
  ];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Auto-saves on leaving, like most note apps. Empty new notes are dropped.
  void _save() {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final existing = widget.note;
    if (existing == null && title.isEmpty && body.isEmpty && _items.isEmpty) {
      return;
    }
    final base =
        existing ??
        Note(id: 'n${DateTime.now().microsecondsSinceEpoch}', title: '');
    widget.store.saveNote(
      base.copyWith(
        title: title.isEmpty ? 'Sem título' : title,
        body: body,
        checklist: _items,
      ),
    );
  }

  Future<void> _addItem() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo item'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    c.dispose();
    if (text != null && text.isNotEmpty) {
      setState(() => _items.add(ChecklistItem(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = widget.note;

    InputDecoration bare(String hint) => InputDecoration(
      hintText: hint,
      filled: false,
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                n?.pinned == true ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.archive_outlined),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
          children: [
            TextField(
              controller: _title,
              style: theme.textTheme.headlineMedium,
              decoration: bare('Título'),
            ),
            const SizedBox(height: MeSpacing.sm),
            Wrap(
              spacing: MeSpacing.sm,
              runSpacing: MeSpacing.sm,
              children: [
                ActionChip(
                  avatar: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: Text(
                    n?.reminder != null
                        ? '${formatDayLabel(n!.reminder!)} às ${formatTime(n.reminder!)}'
                        : 'Adicionar lembrete',
                  ),
                  onPressed: () {},
                ),
                ActionChip(
                  avatar: const Icon(Icons.sell_outlined, size: 18),
                  label: Text(n?.tag ?? 'Etiqueta'),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: MeSpacing.md),
            if (_items.isNotEmpty) ...[
              for (final item in _items)
                Row(
                  children: [
                    Checkbox(
                      value: item.done,
                      onChanged: (v) => setState(() => item.done = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        item.text,
                        style: item.done
                            ? theme.textTheme.bodyLarge?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: scheme.onSurfaceVariant,
                              )
                            : theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar item'),
              ),
            ] else
              TextField(
                controller: _body,
                minLines: 8,
                maxLines: null,
                style: theme.textTheme.bodyLarge,
                decoration: bare('Escreva aqui…'),
              ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          color: scheme.surfaceContainer,
          child: Row(
            children: [
              IconButton(
                onPressed: _addItem,
                icon: const Icon(Icons.check_box_outlined),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.format_bold)),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.palette_outlined),
              ),
              const Spacer(),
              Text(
                n == null ? 'Nova nota' : 'Editado há 2 min',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: MeSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
