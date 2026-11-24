import 'package:flutter/material.dart';

/// Replaces the current snackbar with [text] and a "Desfazer" action.
/// Takes the messenger (not a context) so it still works after the widget
/// that triggered the change has been popped or removed.
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
