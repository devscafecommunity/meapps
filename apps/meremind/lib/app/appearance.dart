import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

/// Which palette and brightness the app uses. Mockup-only: lets us preview
/// the same screens with every identity of the suite.
class AppearanceController extends ChangeNotifier {
  MeAppTheme _theme = MeAppTheme.meremind;
  ThemeMode _mode = ThemeMode.system;

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
}
