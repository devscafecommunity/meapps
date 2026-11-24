import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import 'data/app_store.dart';
import 'data/database.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeHabitsApp());
}

class MeHabitsApp extends StatefulWidget {
  /// [database] is injectable for tests; it defaults to the on-device SQLite.
  const MeHabitsApp({super.key, this.database});

  final AppDatabase? database;

  @override
  State<MeHabitsApp> createState() => _MeHabitsAppState();
}

class _MeHabitsAppState extends State<MeHabitsApp> {
  final _appearance = AppearanceController(defaultTheme: MeAppTheme.mehabits);
  late final AppDatabase _db = widget.database ?? AppDatabase.open();
  late final AppStore _store = AppStore(_db);
  late final Future<void> _ready = _store.init().then((_) {
    _appearance
      ..restore(_store.settings)
      ..addListener(_saveAppearance);
  });

  void _saveAppearance() {
    for (final e in _appearance.toSettings().entries) {
      _store.setSetting(e.key, e.value);
    }
  }

  @override
  void dispose() {
    _appearance.dispose();
    _store.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MeApp(
      title: 'MeHabits',
      appearance: _appearance,
      ready: _ready,
      home: (_) => HomeShell(store: _store, appearance: _appearance),
    );
  }
}
