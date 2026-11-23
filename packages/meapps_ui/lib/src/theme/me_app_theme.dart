import 'package:flutter/material.dart';

import '../tokens.dart';

/// Identity of one app of the suite. The look & feel (shapes, typography,
/// component themes) is identical for every app; only these values differ.
@immutable
class MeAppTheme {
  const MeAppTheme({
    required this.id,
    required this.name,
    required this.seed,
    this.accent,
  });

  final String id;
  final String name;
  final Color seed;

  /// Optional override for the tertiary colour (dots, highlights).
  final Color? accent;

  static const meremind = MeAppTheme(
    id: 'meremind',
    name: 'MeRemind',
    seed: Color(0xFF5B5BD6),
    accent: Color(0xFFE5733F),
  );
  static const metasks = MeAppTheme(
    id: 'metasks',
    name: 'MeTasks',
    seed: Color(0xFF2E9E6B),
    accent: Color(0xFFD9A400),
  );
  static const mebudget = MeAppTheme(
    id: 'mebudget',
    name: 'MeBudget',
    seed: Color(0xFFE0952B),
    accent: Color(0xFF2F7FD1),
  );
  static const mehabits = MeAppTheme(
    id: 'mehabits',
    name: 'MeHabits',
    seed: Color(0xFFD6457A),
    accent: Color(0xFF2EA3A0),
  );

  /// Palettes available for previews / the appearance picker.
  static const all = [meremind, metasks, mebudget, mehabits];

  ThemeData light() => _build(Brightness.light);
  ThemeData dark() => _build(Brightness.dark);

  ThemeData _build(Brightness brightness) {
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (accent != null) {
      final tertiary = ColorScheme.fromSeed(
        seedColor: accent!,
        brightness: brightness,
      );
      scheme = scheme.copyWith(
        tertiary: tertiary.primary,
        onTertiary: tertiary.onPrimary,
        tertiaryContainer: tertiary.primaryContainer,
        onTertiaryContainer: tertiary.onPrimaryContainer,
      );
    }

    // Only weight overrides: the factory merges them with the default sizes.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
    RoundedRectangleBorder rounded(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // Explicit size: theme text styles are only localised (sizes added)
        // by MaterialApp, so they are still size-less here.
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: rounded(MeRadius.md),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MeSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 72,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: rounded(MeRadius.md),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MeRadius.lg),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(shape: const CircleBorder()),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded(MeRadius.sm),
          minimumSize: const Size(64, 48),
        ),
      ),
    );
  }
}
