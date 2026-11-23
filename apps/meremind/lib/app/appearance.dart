import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

/// Which palette and brightness the app uses. Persisted through [restore]
/// and [toSettings] (see `AppStore.settings`).
class AppearanceController extends ChangeNotifier {
  MeAppTheme _theme = MeAppTheme.meremind;
  ThemeMode _mode = ThemeMode.system;

  static const themeKey = 'appearance.theme';
  static const modeKey = 'appearance.mode';

  MeAppTheme get theme => _theme;
  ThemeMode get mode => _mode;

  set theme(MeAppTheme v) {
    _theme = v;
    notifyListeners();
  }

  set mode(ThemeMode v) {
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
