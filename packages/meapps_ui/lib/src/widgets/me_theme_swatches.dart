import 'package:flutter/material.dart';

import '../theme/me_app_theme.dart';
import '../tokens.dart';

/// Row of selectable app palettes. Used by every app's appearance settings
/// (and handy to preview how the suite looks with each identity).
class MeThemeSwatches extends StatelessWidget {
  const MeThemeSwatches({
    super.key,
    required this.selected,
    required this.onChanged,
    this.themes = MeAppTheme.all,
  });

  final MeAppTheme selected;
  final ValueChanged<MeAppTheme> onChanged;
  final List<MeAppTheme> themes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: MeSpacing.md,
      runSpacing: MeSpacing.md,
      children: [
        for (final t in themes)
          InkWell(
            borderRadius: BorderRadius.circular(MeRadius.sm),
            onTap: () => onChanged(t),
            child: Padding(
              padding: const EdgeInsets.all(MeSpacing.xs),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.seed, t.accent ?? t.seed],
                      ),
                      border: Border.all(
                        width: 3,
                        color: t.id == selected.id
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                      ),
                    ),
                    child: t.id == selected.id
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: MeSpacing.xs),
                  Text(t.name, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
