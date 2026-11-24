import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:mehabits/data/app_store.dart';
import 'package:mehabits/data/database.dart';
import 'package:mehabits/main.dart';

void main() {
  late AppDatabase db;

  /// Boots the app on [database] (default: a fresh in-memory database,
  /// which gets the demo data).
  Future<void> boot(WidgetTester tester, {AppDatabase? database}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    db = database ?? AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MeHabitsApp(database: db));
    // Real SQLite I/O does not advance in fake-async time.
    await settleIo(tester);
  }

  Future<void> shutdown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  /// "3 de 5 concluídos" -> 3.
  int doneToday(WidgetTester tester) {
    final text = tester
        .widget<Text>(find.textContaining(RegExp(r'^\d+ de \d+ conclu')))
        .data!;
    return int.parse(text.split(' ').first);
  }

  Finder card(String habitId) => find.byKey(ValueKey('check-$habitId'));

  testWidgets('navigates between the three tabs', (tester) async {
    await boot(tester);
    expect(find.widgetWithText(AppBar, 'Hoje'), findsOneWidget);
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('Beber água'), findsOneWidget);
    expect(find.text('Novo hábito'), findsOneWidget);

    await openTab(tester, 'Progresso');
    expect(find.widgetWithText(AppBar, 'Progresso'), findsOneWidget);
    expect(find.text('Sequência'), findsWidgets);
    expect(find.text('30 dias'), findsWidgets);

    await openTab(tester, 'Hábitos');
    expect(find.widgetWithText(AppBar, 'Hábitos'), findsOneWidget);
    expect(find.byTooltip('Mais opções'), findsNWidgets(5));
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(5));

    await shutdown(tester);
  });

  testWidgets('creates a habit through the sheet', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Novo hábito'));
    await tester.pumpAndSettle();
    expect(find.text('Novo hábito'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'Correr 5 km');
    for (final tip in ['Corrida', 'Destaque', 'Mais', 'Mais', 'Menos']) {
      await tester.tap(find.byTooltip(tip));
      await tester.pump();
    }
    expect(find.text('vezes por dia'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);

    // Scheduled every day by default, so it shows up today.
    expect(find.text('Correr 5 km'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
    expect(find.byIcon(Icons.directions_run), findsWidgets);

    await openTab(tester, 'Hábitos');
    expect(find.text('Correr 5 km'), findsOneWidget);
    expect(find.text('Todos os dias · 2 por dia'), findsWidgets);
    await shutdown(tester);
  });

  testWidgets('weekdays need at least one day', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Novo hábito'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nunca');
    for (final d in ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom']) {
      await tester.tap(find.widgetWithText(FilterChip, d));
    }
    await tester.pump();
    expect(find.text('Escolha pelo menos um dia'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(FilterChip, 'sáb'));
    await tester.pump();
    expect(find.text('Escolha pelo menos um dia'), findsNothing);
    await shutdown(tester);
  });

  testWidgets('saving without a name shows an error', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Novo hábito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escreva um nome'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();
    expect(find.text('Escreva um nome'), findsNothing);
    await shutdown(tester);
  });

  testWidgets('checking in on "Hoje" updates the progress', (tester) async {
    await boot(tester);
    // Demo: "Beber água" (8 per day) has 3 today; "Caminhar" none yet.
    expect(
      find.descendant(of: card('h1'), matching: find.text('3/8')),
      findsOneWidget,
    );
    final before = doneToday(tester);

    await tester.tap(card('h1'));
    await settleIo(tester);
    expect(
      find.descendant(of: card('h1'), matching: find.text('4/8')),
      findsOneWidget,
    );

    // Long-press removes one, so does "−".
    await tester.longPress(card('h1'));
    await settleIo(tester);
    expect(
      find.descendant(of: card('h1'), matching: find.text('3/8')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: card('h1'),
        matching: find.byTooltip('Remover registo'),
      ),
    );
    await settleIo(tester);
    expect(
      find.descendant(of: card('h1'), matching: find.text('2/8')),
      findsOneWidget,
    );

    // Completing a habit counts in the header.
    await tester.tap(
      find.descendant(of: card('h3'), matching: find.byTooltip('Registar')),
    );
    await settleIo(tester);
    expect(
      find.descendant(of: card('h3'), matching: find.text('Concluído')),
      findsOneWidget,
    );
    expect(doneToday(tester), before + 1);

    // Persisted.
    final rows = await tester.runAsync(() => db.select(db.checkins).get());
    final today = dayKey(DateTime.now());
    expect(
      rows!.where((r) => r.habitId == 'h1' && r.day == today).single.count,
      2,
    );
    await shutdown(tester);
  });

  testWidgets('the week strip picks past days only', (tester) async {
    await boot(tester);
    expect(find.text('Hoje'), findsNWidgets(2)); // App bar + tab.
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Semana passada'), findsOneWidget);
    expect(find.textContaining(RegExp(r'-feira|Sábado|Domingo')), findsWidgets);

    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pumpAndSettle();
    expect(find.textContaining('–'), findsWidgets);

    await tester.tap(find.byTooltip('Semana seguinte'));
    await tester.pumpAndSettle();
    expect(find.text('Semana passada'), findsOneWidget);

    // Back to today with the "Hoje" button.
    await tester.tap(find.widgetWithText(FilledButton, 'Hoje'));
    await tester.pumpAndSettle();
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Hoje, ')), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('habits not scheduled on a day are listed apart', (tester) async {
    await boot(tester);
    // On Sundays neither "Meditar" (workdays) nor "Ginásio" (Tue/Thu/Sat)
    // is scheduled. Go to the latest Sunday.
    final now = DateTime.now();
    final sunday = addDays(dateOnly(now), -(now.weekday % 7));
    if (!isSameDay(sunday, now)) {
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${sunday.day}'));
      await tester.pumpAndSettle();
      expect(find.text('NÃO PREVISTOS NESTE DIA'), findsOneWidget);
    } else {
      expect(find.text('NÃO PREVISTOS HOJE'), findsOneWidget);
    }
    expect(find.textContaining(RegExp('^(Domingo|Hoje), ')), findsOneWidget);

    // They can still be checked.
    await tester.ensureVisible(card('h4'));
    await tester.tap(card('h4'));
    await settleIo(tester);
    expect(
      find.descendant(of: card('h4'), matching: find.text('Concluído')),
      findsOneWidget,
    );
    await shutdown(tester);
  });

  testWidgets('progress detail shows stats and edits a past day', (
    tester,
  ) async {
    await boot(tester);
    await openTab(tester, 'Progresso');
    await tester.tap(find.byKey(const ValueKey('progress-h2')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Ler 20 min'), findsOneWidget);
    expect(find.text('Melhor'), findsOneWidget);
    expect(find.textContaining('Desde '), findsOneWidget);
    // Demo: "Ler 20 min" is done today.
    expect(find.text('Concluído'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover registo'));
    await settleIo(tester);
    expect(find.text('Por fazer'), findsOneWidget);
    await tester.tap(find.byTooltip('Registar'));
    await settleIo(tester);
    expect(find.text('Concluído'), findsOneWidget);

    // Previous month: pick its first day (before or after createdAt).
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp('Concluído|Por fazer|Antes de começar|Não previsto'),
      ),
      findsOneWidget,
    );
    final backToday = find.widgetWithText(FilledButton, 'Hoje');
    expect(backToday, findsOneWidget);
    await tester.tap(find.byTooltip('Mês seguinte'));
    await tester.pumpAndSettle();
    expect(backToday, findsNothing);

    // Two months back, "Hoje" returns to the current month.
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pump();
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    await tester.tap(backToday);
    await tester.pumpAndSettle();
    expect(backToday, findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar hábito'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ler 30 min');
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);
    expect(find.widgetWithText(AppBar, 'Ler 30 min'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ler 30 min'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('archives and unarchives a habit', (tester) async {
    await boot(tester);
    await openTab(tester, 'Hábitos');

    await tester.tap(find.byTooltip('Mais opções').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await settleIo(tester);
    expect(find.text('Hábito arquivado'), findsOneWidget);
    expect(find.text('Arquivados (1)'), findsOneWidget);

    // Hidden from "Hoje" and "Progresso".
    await openTab(tester, 'Hoje');
    expect(find.text('Beber água'), findsNothing);
    await openTab(tester, 'Progresso');
    expect(find.text('Beber água'), findsNothing);

    await openTab(tester, 'Hábitos');
    await tester.tap(find.text('Arquivados (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Beber água'), findsOneWidget);
    await tester.tap(find.byTooltip('Mais opções').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desarquivar'));
    await settleIo(tester);
    expect(find.text('Hábito desarquivado'), findsOneWidget);
    expect(find.textContaining('Arquivados'), findsNothing);

    await openTab(tester, 'Hoje');
    expect(find.text('Beber água'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('deletes a habit after confirming, then undoes it', (
    tester,
  ) async {
    await boot(tester);
    await openTab(tester, 'Hábitos');

    await tester.tap(find.byTooltip('Mais opções').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar hábito?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Beber água'), findsOneWidget);

    await tester.tap(find.byTooltip('Mais opções').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await settleIo(tester);
    expect(find.text('Beber água'), findsNothing);
    expect(find.text('Hábito apagado'), findsOneWidget);
    final left = await tester.runAsync(() => db.select(db.checkins).get());
    expect(left!.where((r) => r.habitId == 'h1'), isEmpty);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Beber água'), findsOneWidget);
    final back = await tester.runAsync(() => db.select(db.checkins).get());
    expect(back!.where((r) => r.habitId == 'h1'), isNotEmpty);

    // Edit from the list.
    await tester.tap(find.text('Beber água'));
    await tester.pumpAndSettle();
    expect(find.text('Editar hábito'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('shows empty states without habits', (tester) async {
    final dir = Directory.systemTemp.createTempSync('mehabits_empty');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    // An existing (not brand new) database gets no demo data.
    await tester.runAsync(() async {
      final first = AppDatabase(NativeDatabase(file));
      await AppStore(first).init(seedDemo: false);
      await first.close();
    });

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    expect(find.text('Sem hábitos'), findsOneWidget);
    await openTab(tester, 'Progresso');
    expect(find.text('Sem progresso ainda'), findsOneWidget);
    await openTab(tester, 'Hábitos');
    expect(find.text('Sem hábitos'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('appearance choice survives a restart', (tester) async {
    final dir = Directory.systemTemp.createTempSync('mehabits_appearance');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.tap(find.text('MeRemind'));
    await settleIo(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await shutdown(tester);

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      app.darkTheme?.colorScheme.primary,
      MeAppTheme.meremind.dark().colorScheme.primary,
    );
    await shutdown(tester);
  });
}

Future<void> settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}
