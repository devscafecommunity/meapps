import 'package:flutter/material.dart';

import '../theme/me_app_theme.dart';

/// Which palette and brightness an app uses. Every app starts on its own
/// [defaultTheme] and persists the user's choice through [restore] and
/// [toSettings] (a plain key/value map the app stores however it likes).
class AppearanceController extends ChangeNotifier {
  AppearanceController({required this.defaultTheme}) : _theme = defaultTheme;

  final MeAppTheme defaultTheme;
  MeAppTheme _theme;
  ThemeMode _mode = ThemeMode.system;

  static const themeKey = 'appearance.theme';
  static const modeKey = 'appearance.mode';

  MeAppTheme get theme => _theme;
  ThemeMode get mode => _mode;

  set theme(MeAppTheme v) {
    if (v == _theme) return;
    _theme = v;
    notifyListeners();
  }

  set mode(ThemeMode v) {
    if (v == _mode) return;
    _mode = v;
    notifyListeners();
  }

  /// Applies saved values; unknown or missing ones keep the defaults.
  void restore(Map<String, String> settings) {
    for (final t in MeAppTheme.all) {
      if (t.id == settings[themeKey]) _theme = t;
    }
    for (final m in ThemeMode.values) {
      if (m.name == settings[modeKey]) _mode = m;
    }
    notifyListeners();
  }

  Map<String, String> toSettings() => {
    themeKey: _theme.id,
    modeKey: _mode.name,
  };
}
