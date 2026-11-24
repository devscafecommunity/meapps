import 'package:flutter/material.dart';

/// Colour for money coming in. Material 3 has no "success" role, so it is a
/// fixed green tuned for each brightness (readable on every app palette).
Color incomeColor(ColorScheme s) => s.brightness == Brightness.light
    ? const Color(0xFF1E7D45)
    : const Color(0xFF7BD89A);

/// Colour for money going out.
Color expenseColor(ColorScheme s) => s.error;

/// Green for zero or positive balances, error colour for negative ones.
Color balanceColor(int cents, ColorScheme s) =>
    cents < 0 ? expenseColor(s) : incomeColor(s);
