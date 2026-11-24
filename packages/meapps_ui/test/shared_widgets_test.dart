import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('date helpers', () {
    test('addDays rolls over months and years and returns midnight', () {
      expect(addDays(DateTime(2026, 1, 31, 15, 30), 1), DateTime(2026, 2, 1));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
      // Across the March DST change in Europe.
      expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
    });

    test('daysBetween counts calendar days, ignoring the time', () {
      expect(daysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 30)), 2);
      expect(daysBetween(DateTime(2026, 11, 24), DateTime(2026, 11, 20)), -4);
      expect(daysBetween(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
    });

    test('weekStart is the Monday of the week', () {
      expect(weekStart(DateTime(2026, 11, 24, 18)), DateTime(2026, 11, 23));
      expect(weekStart(DateTime(2026, 11, 23)), DateTime(2026, 11, 23));
      // Sunday belongs to the week that started on Monday before it.
      expect(weekStart(DateTime(2026, 11, 29)), DateTime(2026, 11, 23));
      expect(weekStart(DateTime(2027, 1, 2)), DateTime(2026, 12, 28));
    });

    test('month helpers', () {
      expect(monthOf(DateTime(2026, 11, 24, 9)), DateTime(2026, 11));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(isSameMonth(DateTime(2026, 11, 1), DateTime(2026, 11, 30)), true);
      expect(isSameMonth(DateTime(2026, 11), DateTime(2025, 11)), false);
      expect(formatMonth(DateTime(2026, 3, 9)), 'março 2026');
    });
  });

  group('MeTone', () {
    test('has a pt label per tone', () {
      expect(MeTone.values.map((t) => t.label), [
        'Neutra',
        'Principal',
        'Secundária',
        'Destaque',
      ]);
    });

    test('swatch tints the plain tone so it shows on a card', () {
      final s = MeAppTheme.metasks.light().colorScheme;
      expect(MeTone.plain.swatch(s), s.surfaceContainerHighest);
      expect(MeTone.plain.swatch(s), isNot(MeTone.plain.background(s)));
      expect(MeTone.plain.onSwatch(s), s.onSurfaceVariant);
      expect(MeTone.primary.swatch(s), MeTone.primary.background(s));
      expect(MeTone.primary.onSwatch(s), MeTone.primary.foreground(s));
    });
  });

  testWidgets('MeTonePicker ticks the selection and reports taps', (
    tester,
  ) async {
    MeTone? picked;
    await tester.pumpWidget(
      _host(
        MeTonePicker(
          selected: MeTone.secondary,
          icon: Icons.water_drop,
          onChanged: (t) => picked = t,
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    // The preview icon is drawn on the other three swatches.
    expect(find.byIcon(Icons.water_drop), findsNWidgets(3));

    await tester.tap(find.byTooltip('Destaque'));
    expect(picked, MeTone.tertiary);
  });

  group('MeMonthHeader', () {
    testWidgets('navigates months and shows the today button on demand', (
      tester,
    ) async {
      DateTime? changed;
      var todayTaps = 0;
      await tester.pumpWidget(
        _host(
          MeMonthHeader(
            month: DateTime(2026, 11, 24),
            onChanged: (m) => changed = m,
            onToday: () => todayTaps++,
          ),
        ),
      );
      expect(find.text('Novembro 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Mês anterior'));
      expect(changed, DateTime(2026, 10));
      await tester.tap(find.byTooltip('Mês seguinte'));
      expect(changed, DateTime(2026, 12));
      await tester.tap(find.text('Hoje'));
      expect(todayTaps, 1);
    });

    testWidgets('hides today and stops at lastMonth', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(
        _host(
          MeMonthHeader(
            month: DateTime(2026, 11),
            lastMonth: DateTime(2026, 11, 30),
            onChanged: (m) => changed = m,
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
      await tester.tap(find.byTooltip('Mês seguinte'));
      expect(changed, isNull);
      await tester.tap(find.byTooltip('Mês anterior'));
      expect(changed, DateTime(2026, 10));
    });
  });

  testWidgets('showUndoSnackBar replaces the previous one and undoes', (
    tester,
  ) async {
    var undone = '';
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showUndoSnackBar(
                  ScaffoldMessenger.of(context),
                  'Nota apagada',
                  () => undone = 'nota',
                ),
                child: const Text('a'),
              ),
              TextButton(
                onPressed: () => showUndoSnackBar(
                  ScaffoldMessenger.of(context),
                  'Lista apagada',
                  () => undone = 'lista',
                ),
                child: const Text('b'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(find.text('Nota apagada'), findsNothing);
    expect(find.text('Lista apagada'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    expect(undone, 'lista');
  });

  testWidgets('confirmDelete is true only when confirmed', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await confirmDelete(
                context,
                title: 'Apagar lista?',
                message: 'As tarefas passam para a caixa de entrada.',
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    Future<void> open() async {
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Apagar lista?'), findsOneWidget);
    expect(
      find.text('As tarefas passam para a caixa de entrada.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    await open();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await open();
    await tester.tapAt(const Offset(5, 5)); // outside the dialog
    await tester.pumpAndSettle();

    expect(results, [true, false, false]);
  });
}
