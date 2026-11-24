import 'package:flutter/material.dart';

/// Date picker followed by a time picker. Returns null if either is cancelled.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final date = await pickDate(context, initial);
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Date picker from last year up to ten years ahead. Returns the chosen day
/// at midnight, or null if cancelled.
Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  final now = DateTime.now();
  final first = DateTime(now.year - 1);
  final last = DateTime(now.year + 10);
  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(first) || initial.isAfter(last)
        ? now
        : initial,
    firstDate: first,
    lastDate: last,
  );
}
