import 'package:flutter/material.dart';

import '../tokens.dart';
import 'me_card.dart';

/// Row of round swatches, one per [MeTone], with the selected one ticked.
/// Every app uses it to colour notes, lists, categories and habits.
class MeTonePicker extends StatelessWidget {
  const MeTonePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.icon,
  });

  final MeTone selected;
  final ValueChanged<MeTone> onChanged;

  /// Optional preview drawn on the unselected swatches (e.g. a habit's
  /// icon), so the user sees the item in each colour.
  final IconData? icon;

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: MeSpacing.md,
      runSpacing: MeSpacing.sm,
      children: [
        for (final t in MeTone.values)
          Tooltip(
            message: t.label,
            child: Semantics(
              button: true,
              selected: t == selected,
              label: 'Cor ${t.label}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onChanged(t),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: t.swatch(scheme),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t == selected
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: t == selected ? 3 : 1,
                    ),
                  ),
                  child: t == selected
                      ? Icon(Icons.check, color: t.onSwatch(scheme))
                      : icon == null
                      ? null
                      : Icon(icon, size: 22, color: t.onSwatch(scheme)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
