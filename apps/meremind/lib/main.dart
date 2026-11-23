import 'package:flutter/material.dart';

import 'app/appearance.dart';
import 'mock/mock_store.dart';
import 'screens/home_shell.dart';

void main() => runApp(const MeRemindApp());

class MeRemindApp extends StatefulWidget {
  const MeRemindApp({super.key});

  @override
  State<MeRemindApp> createState() => _MeRemindAppState();
}

class _MeRemindAppState extends State<MeRemindApp> {
  final _appearance = AppearanceController();
  final _store = MockStore();

  @override
  void dispose() {
    _appearance.dispose();
    _store.dispose();
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
        home: HomeShell(store: _store, appearance: _appearance),
      ),
    );
  }
}
