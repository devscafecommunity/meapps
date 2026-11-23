import 'package:flutter/material.dart';

import 'app/appearance.dart';
import 'data/app_store.dart';
import 'data/database.dart';
import 'screens/home_shell.dart';

void main() => runApp(const MeRemindApp());

class MeRemindApp extends StatefulWidget {
  /// [database] is injectable for tests; defaults to the on-device SQLite.
  const MeRemindApp({super.key, this.database});

  final AppDatabase? database;

  @override
  State<MeRemindApp> createState() => _MeRemindAppState();
}

class _MeRemindAppState extends State<MeRemindApp> {
  final _appearance = AppearanceController();
  late final AppDatabase _db = widget.database ?? AppDatabase.open();
  late final AppStore _store = AppStore(_db);
  late final Future<void> _ready = _store.init();

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
