import 'package:flutter/material.dart';
import 'package:meapps_ui/meapps_ui.dart';

import 'data/app_store.dart';
import 'data/database.dart';
import 'screens/home_shell.dart';
import 'services/reminder_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeRemindApp());
}

class MeRemindApp extends StatefulWidget {
  /// [database] and [notifier] are injectable for tests; they default to the
  /// on-device SQLite and the platform's notification service.
  const MeRemindApp({super.key, this.database, this.notifier});

  final AppDatabase? database;
  final ReminderNotifier? notifier;

  @override
  State<MeRemindApp> createState() => _MeRemindAppState();
}

class _MeRemindAppState extends State<MeRemindApp> {
  final _appearance = AppearanceController(defaultTheme: MeAppTheme.meremind);
  late final AppDatabase _db = widget.database ?? AppDatabase.open();
  late final AppStore _store = AppStore(
    _db,
    notifier: widget.notifier ?? ReminderNotifier.platform(),
  );
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
      title: 'MeRemind',
      appearance: _appearance,
      ready: _ready,
      home: (_) => HomeShell(store: _store, appearance: _appearance),
    );
  }
}
