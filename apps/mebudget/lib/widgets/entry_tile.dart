import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/money.dart';
import '../screens/entry_sheet.dart';
import 'category_avatar.dart';
import 'money_colors.dart';

/// Deletes a movement and offers to put it back. Takes the messenger (not a
/// context) so callers can grab it before closing a sheet.
Future<void> deleteEntryWithUndo(
  ScaffoldMessengerState messenger,
  AppStore store,
  Entry e,
) async {
  final removed = await store.deleteEntry(e.id);
  if (removed == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: const Text('Movimento apagado'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => store.restoreEntry(removed),
        ),
      ),
    );
}

/// A movement row: tap to edit, swipe to delete.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.store});

  final Entry entry;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;
    final category =
        store.categoryById(e.categoryId) ??
        Category(id: e.categoryId, name: 'Outros', kind: e.kind);

    return Dismissible(
      key: ValueKey('entry-${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(MeRadius.sm),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) =>
          deleteEntryWithUndo(ScaffoldMessenger.of(context), store, e),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: MeSpacing.md),
        onTap: () => showEntrySheet(context, store, entry: e),
        leading: CategoryAvatar.of(category),
        title: Text(
          e.note.isEmpty ? category.name : e.note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: e.note.isEmpty ? null : Text(category.name),
        trailing: Text(
          formatMoney(e.signedCents, signed: true),
          style: theme.textTheme.titleSmall?.copyWith(
            color: e.kind == EntryKind.income ? incomeColor(scheme) : null,
          ),
        ),
      ),
    );
  }
}
