import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';

/// How the editor was closed, so the caller can offer "undo".
enum NoteEditorExit { deleted, archived, unarchived }

/// Opens the editor for [note] (or a new note) and shows the matching
/// snackbar when it is deleted or (un)archived from inside.
Future<void> openNoteEditor(
  BuildContext context,
  AppStore store, {
  Note? note,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final exit = await Navigator.of(context).push<NoteEditorExit>(
    MaterialPageRoute(
      builder: (_) => NoteEditorScreen(store: store, note: note),
    ),
  );
  if (exit == null || note == null) return;

  switch (exit) {
    case NoteEditorExit.deleted:
      final deleted = await store.deleteNote(note.id);
      if (deleted != null) {
        showUndoSnackBar(
          messenger,
          'Nota apagada',
          () => store.restoreNote(deleted),
        );
      }
    case NoteEditorExit.archived || NoteEditorExit.unarchived:
      final archived = exit == NoteEditorExit.archived;
      showUndoSnackBar(
        messenger,
        archived ? 'Nota arquivada' : 'Nota restaurada',
        () {
          final current = store.noteById(note.id);
          if (current != null) {
            store.saveNote(current.copyWith(archived: !archived));
          }
        },
      );
  }
}

class _Item {
  _Item(String text, {this.done = false})
    : controller = TextEditingController(text: text);
  final TextEditingController controller;
  final focus = FocusNode();
  bool done;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.store, this.note});

  final AppStore store;
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final String _id = widget.note?.id ?? newId('n');
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late final List<_Item> _items = [
    for (final i in widget.note?.checklist ?? const <ChecklistItem>[])
      _Item(i.text, done: i.done),
  ];
  late bool _checklist = widget.note?.isChecklist ?? false;
  late String? _tag = widget.note?.tag;
  late bool _pinned = widget.note?.pinned ?? false;
  late bool _archived = widget.note?.archived ?? false;
  late MeTone _tone = widget.note?.tone ?? MeTone.plain;
  late DateTime? _reminder = widget.store.reminderFor(_id)?.when;
  bool _reminderChanged = false;

  /// Set when leaving without saving (note deleted).
  bool _discard = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Note _draft() {
    final title = _title.text.trim();
    return Note(
      id: _id,
      title: title.isEmpty ? 'Sem título' : title,
      body: _checklist ? '' : _body.text.trim(),
      checklist: _checklist
          ? [
              for (final i in _items)
                if (i.controller.text.trim().isNotEmpty)
                  ChecklistItem(i.controller.text.trim(), done: i.done),
            ]
          : const [],
      tag: _tag,
      pinned: _pinned,
      archived: _archived,
      tone: _tone,
      updatedAt: widget.note?.updatedAt,
    );
  }

  static bool _sameContent(Note a, Note b) =>
      a.title == b.title &&
      a.body == b.body &&
      a.tag == b.tag &&
      a.pinned == b.pinned &&
      a.archived == b.archived &&
      a.tone == b.tone &&
      a.checklist.length == b.checklist.length &&
      [
        for (var i = 0; i < a.checklist.length; i++)
          a.checklist[i].text == b.checklist[i].text &&
              a.checklist[i].done == b.checklist[i].done,
      ].every((same) => same);

  /// Auto-saves on leaving, like most note apps. Empty new notes are dropped
  /// and untouched notes keep their "edited" time.
  Future<void> _save() async {
    if (_discard) return;
    final note = _draft();
    final existing = widget.note;
    if (existing == null &&
        _title.text.trim().isEmpty &&
        note.body.isEmpty &&
        note.checklist.isEmpty &&
        _reminder == null) {
      return;
    }
    final store = widget.store;
    if (existing == null || !_sameContent(existing, note)) {
      await store.saveNote(note);
    }
    if (_reminderChanged) await store.setNoteReminder(note, _reminder);
  }

  // --- Checklist -------------------------------------------------------

  void _setChecklist(bool on) {
    if (on == _checklist) return;
    setState(() {
      if (on) {
        final lines = _body.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty);
        _items.addAll(lines.map(_Item.new));
        if (_items.isEmpty) _items.add(_Item(''));
        _body.clear();
      } else {
        _body.text = _items
            .map((i) => i.controller.text.trim())
            .where((t) => t.isNotEmpty)
            .join('\n');
        for (final i in _items) {
          i.dispose();
        }
        _items.clear();
      }
      _checklist = on;
    });
  }

  void _addItem({int? after}) {
    final item = _Item('');
    setState(
      () => _items.insert(after == null ? _items.length : after + 1, item),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) item.focus.requestFocus();
    });
  }

  void _removeItem(_Item item) {
    setState(() => _items.remove(item));
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  // --- Metadata --------------------------------------------------------

  Future<void> _pickReminder() async {
    final n = DateTime.now();
    final picked = await pickDateTime(
      context,
      _reminder ?? DateTime(n.year, n.month, n.day + 1, 9),
    );
    if (picked == null) return;
    setState(() {
      _reminder = picked;
      _reminderChanged = true;
    });
  }

  void _clearReminder() => setState(() {
    _reminder = null;
    _reminderChanged = true;
  });

  Future<void> _pickTag() async {
    final result = await showDialog<({String? tag})>(
      context: context,
      builder: (_) => _TagDialog(tags: widget.store.tags, current: _tag),
    );
    if (result != null) setState(() => _tag = result.tag);
  }

  Future<void> _pickTone() async {
    final tone = await showModalBottomSheet<MeTone>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          MeSpacing.md,
          0,
          MeSpacing.md,
          MeSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cor', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MeSpacing.md),
            MeTonePicker(
              selected: _tone,
              onChanged: (t) => Navigator.pop(context, t),
            ),
          ],
        ),
      ),
    );
    if (tone != null) setState(() => _tone = tone);
  }

  Future<void> _confirmDelete() async {
    final ok = await confirmDelete(
      context,
      title: 'Apagar nota?',
      message: 'Os lembretes desta nota também são apagados.',
    );
    if (!ok || !mounted) return;
    _discard = true;
    Navigator.pop(context, NoteEditorExit.deleted);
  }

  void _toggleArchive() {
    setState(() => _archived = !_archived);
    Navigator.pop(
      context,
      _archived ? NoteEditorExit.archived : NoteEditorExit.unarchived,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = widget.note;
    final background = _tone == MeTone.plain ? null : _tone.background(scheme);

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
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          actions: [
            IconButton(
              tooltip: _pinned ? 'Desafixar' : 'Fixar',
              onPressed: () => setState(() => _pinned = !_pinned),
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            ),
            if (n != null)
              IconButton(
                tooltip: _archived ? 'Desarquivar' : 'Arquivar',
                onPressed: _toggleArchive,
                icon: Icon(
                  _archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
              ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (v) => switch (v) {
                'checklist' => _setChecklist(!_checklist),
                'delete' => _confirmDelete(),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'checklist',
                  child: Text(
                    _checklist ? 'Converter em texto' : 'Converter em lista',
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Apagar nota'),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
          children: [
            TextField(
              controller: _title,
              autofocus: n == null,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.headlineMedium,
              decoration: bare('Título'),
            ),
            const SizedBox(height: MeSpacing.sm),
            Wrap(
              spacing: MeSpacing.sm,
              runSpacing: MeSpacing.sm,
              children: [
                if (_reminder == null)
                  ActionChip(
                    avatar: const Icon(Icons.add_alert_outlined, size: 18),
                    label: const Text('Adicionar lembrete'),
                    onPressed: _pickReminder,
                  )
                else
                  InputChip(
                    avatar: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                    ),
                    label: Text(
                      '${formatDayLabel(_reminder!)} às ${formatTime(_reminder!)}',
                    ),
                    onPressed: _pickReminder,
                    onDeleted: _clearReminder,
                    deleteButtonTooltipMessage: 'Remover lembrete',
                  ),
                ActionChip(
                  avatar: const Icon(Icons.sell_outlined, size: 18),
                  label: Text(_tag ?? 'Etiqueta'),
                  onPressed: _pickTag,
                ),
              ],
            ),
            const SizedBox(height: MeSpacing.md),
            if (_checklist) ...[
              for (var i = 0; i < _items.length; i++)
                _ChecklistRow(
                  key: ObjectKey(_items[i]),
                  item: _items[i],
                  onToggle: (v) => setState(() => _items[i].done = v),
                  onSubmitted: () => _addItem(after: i),
                  onRemove: () => _removeItem(_items[i]),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar item'),
                ),
              ),
            ] else
              TextField(
                controller: _body,
                minLines: 8,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge,
                decoration: bare('Escreva aqui…'),
              ),
            const SizedBox(height: MeSpacing.xl),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          color: background ?? scheme.surfaceContainer,
          child: Row(
            children: [
              IconButton(
                tooltip: _checklist
                    ? 'Converter em texto'
                    : 'Converter em lista',
                onPressed: () => _setChecklist(!_checklist),
                icon: Icon(_checklist ? Icons.notes : Icons.check_box_outlined),
              ),
              IconButton(
                tooltip: 'Cor',
                onPressed: _pickTone,
                icon: const Icon(Icons.palette_outlined),
              ),
              const Spacer(),
              Text(
                n == null
                    ? 'Nova nota'
                    : n.updatedAt == null
                    ? ''
                    : 'Editado ${formatAgo(n.updatedAt!)}',
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

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onSubmitted,
    required this.onRemove,
  });

  final _Item item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSubmitted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Checkbox(value: item.done, onChanged: (v) => onToggle(v ?? false)),
        Expanded(
          child: TextField(
            controller: item.controller,
            focusNode: item.focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onSubmitted(),
            style: item.done
                ? theme.textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Item',
              filled: false,
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Remover item',
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}

/// Pick an existing tag, type a new one, or remove it.
/// Pops `(tag: ...)`; `null` means cancelled.
class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.tags, required this.current});

  final List<String> tags;
  final String? current;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final _new = TextEditingController();

  @override
  void dispose() {
    _new.dispose();
    super.dispose();
  }

  void _submitNew() {
    final t = _new.text.trim();
    if (t.isNotEmpty) Navigator.pop(context, (tag: t));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Etiqueta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.tags.isNotEmpty) ...[
            Wrap(
              spacing: MeSpacing.sm,
              runSpacing: MeSpacing.sm,
              children: [
                for (final t in widget.tags)
                  ChoiceChip(
                    label: Text(t),
                    selected: t == widget.current,
                    onSelected: (_) => Navigator.pop(context, (tag: t)),
                  ),
              ],
            ),
            const SizedBox(height: MeSpacing.md),
          ],
          TextField(
            controller: _new,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submitNew(),
            decoration: const InputDecoration(hintText: 'Nova etiqueta'),
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, (tag: null)),
            child: const Text('Remover'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submitNew, child: const Text('Criar')),
      ],
    );
  }
}
