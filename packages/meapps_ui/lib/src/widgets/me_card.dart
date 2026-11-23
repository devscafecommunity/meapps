import 'package:flutter/material.dart';

import '../tokens.dart';

/// Tonal colour roles a card can take, resolved against the active scheme so
/// every app theme gets matching colours for free.
enum MeTone {
  plain,
  primary,
  secondary,
  tertiary;

  Color background(ColorScheme s) => switch (this) {
        plain => s.surfaceContainerLow,
        primary => s.primaryContainer,
        secondary => s.secondaryContainer,
        tertiary => s.tertiaryContainer,
      };

  Color foreground(ColorScheme s) => switch (this) {
        plain => s.onSurface,
        primary => s.onPrimaryContainer,
        secondary => s.onSecondaryContainer,
        tertiary => s.onTertiaryContainer,
      };
}

class MeCard extends StatelessWidget {
  const MeCard({
    super.key,
    required this.child,
    this.tone = MeTone.plain,
    this.onTap,
    this.padding = const EdgeInsets.all(MeSpacing.md),
  });

  final Widget child;
  final MeTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: tone.background(scheme),
      child: InkWell(
        onTap: onTap,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: tone.foreground(scheme)),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
