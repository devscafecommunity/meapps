import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import '../data/app_store.dart';
import '../data/category_icon.dart';

/// Round icon of a category in its colour.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.icon,
    required this.tone,
    this.radius = 20,
  });

  CategoryAvatar.of(Category category, {Key? key, double radius = 20})
    : this(key: key, icon: category.icon, tone: category.tone, radius: radius);

  final CategoryIcon icon;
  final MeTone tone;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: tone.swatch(scheme),
      child: Icon(icon.icon, size: radius, color: tone.onSwatch(scheme)),
    );
  }
}
