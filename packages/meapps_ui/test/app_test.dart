import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';

void main() {
  group('AppearanceController', () {
    test('starts on the app default and system brightness', () {
      final c = AppearanceController(defaultTheme: MeAppTheme.mebudget);
      expect(c.theme, MeAppTheme.mebudget);
      expect(c.mode, ThemeMode.system);
    });

    test('round-trips through settings', () {
      final a = AppearanceController(defaultTheme: MeAppTheme.metasks)
        ..theme = MeAppTheme.mehabits
        ..mode = ThemeMode.dark;
      final b = AppearanceController(defaultTheme: MeAppTheme.metasks)
        ..restore(a.toSettings());
      expect(b.theme, MeAppTheme.mehabits);
      expect(b.mode, ThemeMode.dark);
    });

    test('ignores unknown saved values', () {
      final c = AppearanceController(defaultTheme: MeAppTheme.metasks)
        ..restore({
          AppearanceController.themeKey: 'nope',
          AppearanceController.modeKey: 'nope',
        });
      expect(c.theme, MeAppTheme.metasks);
      expect(c.mode, ThemeMode.system);
    });

    test('notifies only on real changes', () {
      var calls = 0;
      final c = AppearanceController(defaultTheme: MeAppTheme.metasks)
        ..addListener(() => calls++);
      c.theme = MeAppTheme.metasks;
      c.mode = ThemeMode.system;
      expect(calls, 0);
      c.theme = MeAppTheme.mebudget;
      c.mode = ThemeMode.light;
      expect(calls, 2);
    });
  });

  group('MeApp', () {
    testWidgets('shows a spinner until ready, then home in pt_PT', (
      tester,
    ) async {
      final ready = Completer<void>();
      final appearance = AppearanceController(defaultTheme: MeAppTheme.metasks);
      await tester.pumpWidget(
        MeApp(
          title: 'Teste',
          appearance: appearance,
          ready: ready.future,
          home: (context) => Scaffold(
            body: Text(
              MaterialLocalizations.of(context).okButtonLabel,
              key: const Key('ok'),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      ready.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ok')), findsOneWidget);
      // pt_PT localisations are active.
      expect(find.text('OK'), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, MeApp.locale);
    });

    testWidgets('shows an error when loading fails', (tester) async {
      final ready = Completer<void>();
      await tester.pumpWidget(
        MeApp(
          title: 'Teste',
          appearance: AppearanceController(defaultTheme: MeAppTheme.metasks),
          ready: ready.future,
          home: (_) => const Text('home'),
        ),
      );
      ready.completeError(StateError('disco cheio'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível abrir os dados'), findsOneWidget);
      expect(find.textContaining('disco cheio'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });
  });

  testWidgets('appearance sheet changes palette and brightness', (
    tester,
  ) async {
    final appearance = AppearanceController(defaultTheme: MeAppTheme.meremind);
    await tester.pumpWidget(
      MeApp(
        title: 'Teste',
        appearance: appearance,
        ready: Future<void>.value(),
        home: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAppearanceSheet(context, appearance),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(MeAppTheme.mehabits.name));
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(appearance.theme, MeAppTheme.mehabits);
    expect(appearance.mode, ThemeMode.dark);
  });

  testWidgets('pickDateTime combines both pickers and handles cancel', (
    tester,
  ) async {
    DateTime? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await pickDateTime(
                context,
                DateTime(DateTime.now().year, 3, 14, 9, 30),
              );
              done = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, DateTime(DateTime.now().year, 3, 20, 9, 30));

    done = false;
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, isNull);
  });
}
