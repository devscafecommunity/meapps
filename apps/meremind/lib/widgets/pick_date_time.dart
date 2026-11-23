import 'package:flutter/material.dart';

/// Date picker followed by a time picker. Returns null if either is cancelled.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final first = DateTime(now.year - 1);
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(first) ? now : initial,
    firstDate: first,
    lastDate: DateTime(now.year + 10),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
