import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meremind/data/database.dart';
import 'package:meremind/main.dart';

import 'fakes.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    notifier = FakeNotifier();
    await tester.pumpWidget(MeRemindApp(database: db, notifier: notifier));
    // Real SQLite I/O does not advance in fake-async time.
    await settleIo(tester);
  }

  Future<void> shutdown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  testWidgets('navigates between the three tabs', (tester) async {
    await boot(tester);
    expect(find.text('Novo lembrete'), findsOneWidget);

    await tester.tap(find.text('Notas').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova nota'), findsOneWidget);
    expect(find.text('Lista de compras'), findsOneWidget);

    await tester.tap(find.text('Lembretes').last);
    await tester.pumpAndSettle();
    expect(find.text('HOJE'), findsOneWidget);
    expect(notifier.initialized, isTrue);

    await shutdown(tester);
  });

  testWidgets('creates a reminder from the sheet', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Lembretes').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo lembrete'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Comprar pilhas');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Amanhã 09:00'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Semanal'));
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);

    expect(find.text('Comprar pilhas'), findsOneWidget);
    expect(notifier.titles.values, contains('Comprar pilhas'));
    await shutdown(tester);
  });

  testWidgets('saving without a title shows an error', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Novo lembrete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escreva um título'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('writes a new note and finds it with search', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Notas').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova nota'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ideia nova');
    await tester.enterText(find.byType(TextField).last, 'Aprender Flutter');
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await settleIo(tester);
    expect(find.text('Ideia nova'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'flutter');
    await tester.pumpAndSettle();
    expect(find.text('Ideia nova'), findsOneWidget);
    expect(find.text('Lista de compras'), findsNothing);

    await shutdown(tester);
  });

  testWidgets('archives a note and undoes it', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Notas').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Receita de bolo de cenoura'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Arquivar'));
    await settleIo(tester);
    expect(find.text('Receita de bolo de cenoura'), findsNothing);
    expect(find.text('Nota arquivada'), findsOneWidget);

    await tester.ensureVisible(find.text('Arquivo'));
    await tester.tap(find.text('Arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Receita de bolo de cenoura'), findsOneWidget);

    await shutdown(tester);
  });

  testWidgets('deletes a note after confirming', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Notas').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ideias para o fim de semana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar nota'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await settleIo(tester);

    expect(find.text('Ideias para o fim de semana'), findsNothing);
    expect(find.text('Nota apagada'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Ideias para o fim de semana'), findsOneWidget);

    await shutdown(tester);
  });

  testWidgets('appearance choice survives a restart', (tester) async {
    await boot(tester);
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await settleIo(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    final settings = await tester.runAsync(() => db.select(db.settings).get());
    expect(
      settings!.map((s) => (s.key, s.value)),
      contains(('appearance.mode', 'dark')),
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
