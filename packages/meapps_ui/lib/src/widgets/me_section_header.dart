import 'package:flutter/material.dart';

import '../tokens.dart';

class MeSectionHeader extends StatelessWidget {
  const MeSectionHeader(this.title, {super.key, this.trailing, this.color});

  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MeSpacing.md, MeSpacing.md, MeSpacing.md, MeSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
