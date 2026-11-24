import 'package:flutter/material.dart';

import '../tokens.dart';
import '../widgets/me_theme_swatches.dart';
import 'appearance_controller.dart';

/// Bottom sheet to pick the palette and light/dark mode. Changes apply
/// immediately through [appearance].
Future<void> showAppearanceSheet(
  BuildContext context,
  AppearanceController appearance,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => Padding(
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
            Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MeSpacing.xs),
            Text(
              'Mesmo visual, identidade diferente por app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MeSpacing.md),
            MeThemeSwatches(
              selected: appearance.theme,
              onChanged: (t) => appearance.theme = t,
            ),
            const SizedBox(height: MeSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Escuro'),
                  ),
                ],
                selected: {appearance.mode},
                onSelectionChanged: (s) => appearance.mode = s.first,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
