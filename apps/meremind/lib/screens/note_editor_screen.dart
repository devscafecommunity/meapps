import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../mock/mock_store.dart';

class NoteEditorScreen extends StatelessWidget {
  const NoteEditorScreen({super.key, this.note});

  final MockNote? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = note;

    InputDecoration bare(String hint) => InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(n?.pinned == true ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.archive_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
        children: [
          TextFormField(
            initialValue: n?.title,
            style: theme.textTheme.headlineMedium,
            decoration: bare('Título'),
          ),
          const SizedBox(height: MeSpacing.sm),
          Wrap(
            spacing: MeSpacing.sm,
            runSpacing: MeSpacing.sm,
            children: [
              ActionChip(
                avatar: const Icon(Icons.notifications_active_outlined, size: 18),
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
          if (n != null && n.checklist.isNotEmpty) ...[
            for (final item in n.checklist)
              Row(
                children: [
                  Checkbox(value: item.done, onChanged: (_) {}),
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
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Adicionar item'),
            ),
          ] else
            TextFormField(
              initialValue: n?.body,
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
            IconButton(onPressed: () {}, icon: const Icon(Icons.check_box_outlined)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.format_bold)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.palette_outlined)),
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
    );
  }
}
