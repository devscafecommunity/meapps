import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mebudget/data/database.dart';
import 'package:mebudget/data/money.dart';
import 'package:mebudget/data/months.dart';
import 'package:mebudget/main.dart';

void main() {
  late AppDatabase db;
  final thisMonth = monthOf(DateTime.now());

  Future<void> boot(WidgetTester tester, {AppDatabase? database}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    db = database ?? AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MeBudgetApp(database: db));
    // Real SQLite I/O does not advance in fake-async time.
    await settleIo(tester);
  }

  Future<void> shutdown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  int amountOf(WidgetTester tester, String key) =>
      parseMoney(textOf(tester, key))!;

  /// Taps a filter chip, scrolling the chip row first if needed.
  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab).last);
    await tester.pumpAndSettle();
  }

  /// Opens "Novo movimento", fills it in and saves.
  Future<void> addEntry(
    WidgetTester tester, {
    required String amount,
    String? category,
    String? note,
    String? day,
    bool income = false,
  }) async {
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Novo movimento'),
    );
    await tester.pumpAndSettle();
    if (income) {
      await tester.tap(find.text('Receita'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('amount')), amount);
    if (category != null) {
      await tester.tap(find.widgetWithText(ChoiceChip, category));
      await tester.pump();
    }
    if (day != null) {
      await tester.tap(find.widgetWithText(ChoiceChip, day));
      await tester.pump();
    }
    if (note != null) {
      await tester.enterText(find.byKey(const Key('note')), note);
    }
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);
  }

  testWidgets('navigates between the three tabs', (tester) async {
    await boot(tester);
    expect(find.text('Saldo do mês'), findsOneWidget);
    expect(find.text(formatMonth(thisMonth)), findsOneWidget);
    expect(find.text('DESPESAS POR CATEGORIA'), findsOneWidget);
    expect(find.text('Novo movimento'), findsOneWidget);

    await goTo(tester, 'Movimentos');
    expect(find.widgetWithText(ChoiceChip, 'Todas'), findsOneWidget);
    expect(find.text(formatMonth(thisMonth)), findsOneWidget);

    await goTo(tester, 'Categorias');
    expect(find.text('DESPESAS'), findsOneWidget);
    expect(find.text('RECEITAS'), findsOneWidget);
    expect(find.text('Supermercado'), findsOneWidget);
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Nova categoria'), findsOneWidget);
    expect(find.byTooltip('Mês anterior'), findsNothing);

    await goTo(tester, 'Resumo');
    expect(find.text('Saldo do mês'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('adding an expense updates the month totals', (tester) async {
    await boot(tester);
    final expenses = amountOf(tester, 'total-expense');
    final income = amountOf(tester, 'total-income');
    expect(textOf(tester, 'balance'), formatMoney(income - expenses));

    await addEntry(
      tester,
      amount: '12,50',
      category: 'Supermercado',
      note: 'Pão',
    );

    expect(amountOf(tester, 'total-expense'), expenses + 1250);
    expect(amountOf(tester, 'total-income'), income);
    expect(textOf(tester, 'balance'), formatMoney(income - expenses - 1250));

    await goTo(tester, 'Movimentos');
    expect(find.text('Pão'), findsOneWidget);
    // On the tile (and on the day header when it is today's only one).
    expect(find.text(formatMoney(-1250, signed: true)), findsWidgets);
    await shutdown(tester);
  });

  testWidgets('an invalid amount shows an error', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Novo movimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Indique um valor válido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amount')), '0');
    await tester.pump();
    expect(find.text('Indique um valor válido'), findsNothing);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Indique um valor válido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amount')), '12,345');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Indique um valor válido'), findsOneWidget);
    expect(find.text('Novo movimento'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('amount')), '5');
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('Novo movimento'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('changes month on Resumo and Movimentos', (tester) async {
    await boot(tester);
    final previous = addMonths(thisMonth, -1);
    final next = addMonths(thisMonth, 1);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    expect(find.text(formatMonth(previous)), findsOneWidget);
    expect(find.text('Saldo do mês'), findsOneWidget);

    // Back to this month, then one ahead: nothing there yet.
    await tester.tap(find.byTooltip('Este mês'));
    await tester.pumpAndSettle();
    expect(find.text(formatMonth(thisMonth)), findsOneWidget);
    expect(find.byTooltip('Este mês'), findsNothing);
    await tester.tap(find.byTooltip('Mês seguinte'));
    await tester.pumpAndSettle();
    expect(find.text(formatMonth(next)), findsOneWidget);
    expect(find.text('Sem movimentos'), findsOneWidget);
    expect(find.text('Saldo do mês'), findsNothing);

    // The month is shared with Movimentos.
    await goTo(tester, 'Movimentos');
    expect(find.text(formatMonth(next)), findsOneWidget);
    expect(find.text('Sem movimentos'), findsOneWidget);
    expect(
      find.text('Nenhum movimento em ${formatMonth(next)}.'),
      findsOneWidget,
    );

    // A movement dated today brings the view back to this month.
    await addEntry(tester, amount: '3', note: 'Café', day: 'Hoje');
    expect(find.text(formatMonth(thisMonth)), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('shows budget overrun per category', (tester) async {
    await boot(tester);
    expect(
      find.text(
        'Excedido em ${formatMoney(1470)} (orçamento ${formatMoney(15000)})',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Restam '), findsWidgets);
    expect(find.text('RECEITAS POR CATEGORIA'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('edits a movement, swipes it away and undoes', (tester) async {
    await boot(tester);
    await addEntry(tester, amount: '12,50', note: 'Bolo');
    await goTo(tester, 'Movimentos');

    await tester.tap(find.text('Bolo'));
    await tester.pumpAndSettle();
    expect(find.text('Editar movimento'), findsOneWidget);
    expect(find.text('12,50'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount')), '20');
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);
    expect(find.text(formatMoney(-2000, signed: true)), findsWidgets);

    await tester.drag(find.text('Bolo'), const Offset(-600, 0));
    await settleIo(tester);
    expect(find.text('Bolo'), findsNothing);
    expect(find.text('Movimento apagado'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Bolo'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('records an income for yesterday and deletes it from the sheet', (
    tester,
  ) async {
    await boot(tester);
    // On the 1st, yesterday is last month: the view follows the movement.
    await addEntry(
      tester,
      amount: '1 000',
      income: true,
      category: 'Extras',
      note: 'Prémio',
      day: 'Ontem',
    );
    await goTo(tester, 'Movimentos');
    // Filter so the movement is on screen whatever the day of the month.
    await tapChip(tester, 'Extras');
    expect(find.text('Prémio'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text(formatMoney(100000, signed: true)), findsWidgets);

    // Picking a date and confirming the dialog keeps the sheet open.
    await tester.tap(find.text('Prémio'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Escolher…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Editar movimento'), findsOneWidget);

    await tester.tap(find.byTooltip('Apagar'));
    await settleIo(tester);
    expect(find.text('Prémio'), findsNothing);
    expect(find.text('Movimento apagado'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('toggling the kind switches the category chips', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Novo movimento'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Supermercado'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Salário'), findsNothing);

    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Salário'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Supermercado'), findsNothing);
    await shutdown(tester);
  });

  testWidgets('filters movements by category', (tester) async {
    await boot(tester);
    await addEntry(tester, amount: '7', income: true, category: 'Outros');
    await goTo(tester, 'Movimentos');
    await tapChip(tester, 'Supermercado');
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Renda'), findsNothing);
    expect(find.text('Cinema'), findsNothing);

    // Both kinds have an "Outros" in use; the chips say which is which.
    expect(find.widgetWithText(ChoiceChip, 'Outros (despesa)'), findsOneWidget);
    await tapChip(tester, 'Outros (receita)');
    expect(find.text(formatMoney(700, signed: true)), findsWidgets);
    expect(find.text('Mercado'), findsNothing);

    await tapChip(tester, 'Todas');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todas'))
          .selected,
      isTrue,
    );
    await shutdown(tester);
  });

  testWidgets('creates a category with a budget, validating the form', (
    tester,
  ) async {
    await boot(tester);
    await goTo(tester, 'Categorias');
    await tester.tap(find.text('Nova categoria'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escreva um nome'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('category-name')), 'Animais');
    await tester.tap(find.byIcon(Icons.pets_outlined));
    await tester.tap(find.byTooltip('Destaque'));
    await tester.enterText(find.byKey(const Key('category-budget')), '1,2,3');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escreva um nome'), findsNothing);
    expect(find.text('Indique um valor válido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('category-budget')), '40');
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('Animais'), findsOneWidget);
    expect(
      find.text('Orçamento ${formatMoney(4000)}/mês · 0 movimentos'),
      findsOneWidget,
    );

    // A new income category has no budget field.
    await tester.tap(find.byTooltip('Nova categoria de receita'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-budget')), findsNothing);
    await tester.tap(find.text('Despesa'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-budget')), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('edits a category; "Outros" cannot be deleted', (tester) async {
    await boot(tester);
    await goTo(tester, 'Categorias');
    await tester.tap(find.text('Transportes'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoria'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('category-name')), 'Carro');
    await tester.enterText(find.byKey(const Key('category-budget')), '');
    await tester.tap(find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('Transportes'), findsNothing);
    expect(find.text('Carro'), findsOneWidget);

    await tester.tap(find.text('Outros').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Categoria fixa'), findsOneWidget);
    expect(find.byTooltip('Apagar'), findsNothing);
    await shutdown(tester);
  });

  testWidgets('deleting a category asks first, moves its movements to '
      '"Outros" and can be undone', (tester) async {
    await boot(tester);
    await goTo(tester, 'Categorias');
    expect(find.text('Sem orçamento · 1 movimento'), findsOneWidget);

    await tester.tap(find.text('Lazer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar categoria?'), findsOneWidget);
    expect(
      find.text('Os 3 movimentos desta categoria passam para "Outros".'),
      findsOneWidget,
    );

    // Cancelling keeps everything.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoria'), findsOneWidget);

    await tester.tap(find.byTooltip('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await settleIo(tester);
    expect(find.text('Lazer'), findsNothing);
    expect(find.text('Categoria apagada'), findsOneWidget);
    expect(find.text('Sem orçamento · 4 movimentos'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Lazer'), findsOneWidget);
    expect(find.text('Sem orçamento · 1 movimento'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('every screen and sheet fits a small phone', (tester) async {
    await boot(tester);
    // 320 x 569 logical pixels; any overflow fails the test.
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.25;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    for (final tab in ['Movimentos', 'Categorias', 'Resumo']) {
      await goTo(tester, tab);
    }
    await tester.tap(find.text('Novo movimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    // Tall enough to cover the screen: close it through its navigator.
    Navigator.of(tester.element(find.text('Guardar'))).pop();
    await tester.pumpAndSettle();
    await goTo(tester, 'Categorias');
    await tester.tap(find.text('Supermercado'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoria'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('appearance choice survives a restart', (tester) async {
    final dir = Directory.systemTemp.createTempSync('mebudget_app');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await settleIo(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await shutdown(tester);

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.text('Saldo do mês'), findsOneWidget);
    await shutdown(tester);
  });
}

Future<void> settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}
