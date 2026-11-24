import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../widgets/me_empty_state.dart';
import 'appearance_controller.dart';

/// Root widget shared by every app of the suite: theme and brightness from
/// [appearance], pt_PT Material localisations, and a spinner until [ready]
/// (loading the local database) completes.
class MeApp extends StatelessWidget {
  const MeApp({
    super.key,
    required this.title,
    required this.appearance,
    required this.ready,
    required this.home,
  });

  final String title;
  final AppearanceController appearance;

  /// Created once by the caller (e.g. a `late final` field), not per build.
  final Future<void> ready;
  final WidgetBuilder home;

  static const locale = Locale('pt', 'PT');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => MaterialApp(
        title: title,
        debugShowCheckedModeBanner: false,
        theme: appearance.theme.light(),
        darkTheme: appearance.theme.dark(),
        themeMode: appearance.mode,
        locale: locale,
        supportedLocales: const [locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: FutureBuilder<void>(
          future: ready,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Scaffold(
                body: Center(
                  child: MeEmptyState(
                    icon: Icons.error_outline,
                    title: 'Não foi possível abrir os dados',
                    message: '${snap.error}',
                  ),
                ),
              );
            }
            return home(context);
          },
        ),
      ),
    );
  }
}
