import 'package:flutter/material.dart';

/// Replaces the current snackbar with [text] and a "Desfazer" action.
///
/// Takes the messenger (not a context) so it still works after the widget
/// that triggered the change has been popped: grab it with
/// `ScaffoldMessenger.of(context)` before awaiting or closing anything.
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String text,
  VoidCallback onUndo,
) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: 'Desfazer', onPressed: onUndo),
      ),
    );
}

/// "Cancelar" / "Apagar" dialog. Resolves to true only when the user
/// confirms; dismissing it counts as cancel.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Apagar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
