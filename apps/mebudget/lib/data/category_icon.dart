import 'package:flutter/material.dart' show IconData, Icons;

/// Icons a category can use. Each value maps to a const [Icons] glyph, so the
/// icon font stays tree-shaken; the database stores the value's [name].
enum CategoryIcon {
  home(Icons.home_outlined),
  groceries(Icons.shopping_cart_outlined),
  transport(Icons.directions_car_outlined),
  restaurant(Icons.restaurant_outlined),
  health(Icons.medical_services_outlined),
  leisure(Icons.theater_comedy_outlined),
  education(Icons.school_outlined),
  bills(Icons.receipt_long_outlined),
  shopping(Icons.shopping_bag_outlined),
  travel(Icons.flight_outlined),
  pets(Icons.pets_outlined),
  kids(Icons.child_friendly_outlined),
  sport(Icons.fitness_center),
  phone(Icons.smartphone),
  gift(Icons.card_giftcard),
  salary(Icons.work_outline),
  extra(Icons.handshake_outlined),
  savings(Icons.savings_outlined),
  investment(Icons.trending_up),
  other(Icons.category_outlined);

  const CategoryIcon(this.icon);
  final IconData icon;

  /// Unknown names (e.g. from a newer app version) fall back to [other].
  static CategoryIcon byName(String name) =>
      values.firstWhere((i) => i.name == name, orElse: () => other);
}
