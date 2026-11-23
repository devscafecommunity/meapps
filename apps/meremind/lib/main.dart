import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/appearance.dart';
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
  final _appearance = AppearanceController();
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
    return ListenableBuilder(
      listenable: _appearance,
      builder: (context, _) => MaterialApp(
        title: 'MeRemind',
        debugShowCheckedModeBanner: false,
        theme: _appearance.theme.light(),
        darkTheme: _appearance.theme.dark(),
        themeMode: _appearance.mode,
        locale: const Locale('pt', 'PT'),
        supportedLocales: const [Locale('pt', 'PT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: FutureBuilder<void>(
          future: _ready,
          builder: (context, snap) =>
              snap.connectionState == ConnectionState.done
              ? HomeShell(store: _store, appearance: _appearance)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    );
  }
}
