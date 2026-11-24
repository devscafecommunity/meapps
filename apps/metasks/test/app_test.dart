import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';
import 'package:metasks/data/database.dart';
import 'package:metasks/main.dart';

void main() {
  late AppDatabase db;

  Future<void> boot(WidgetTester tester, {AppDatabase? database}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    db = database ?? AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MeTasksApp(database: db));
    // Real SQLite I/O does not advance in fake-async time.
    await settleIo(tester);
  }

  Future<void> shutdown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder tile(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));
  Finder checkboxOf(String title) =>
      find.descendant(of: tile(title), matching: find.byType(Checkbox));
  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  Future<List<TaskRow>> taskRows(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.tasks).get()))!;

  testWidgets('navigates between the three tabs', (tester) async {
    await boot(tester);
    expect(find.text('EM ATRASO'), findsOneWidget);
    expect(find.text('Pagar a conta da luz'), findsOneWidget);
    expect(find.text('HOJE'), findsOneWidget);
    expect(find.text('Enviar proposta ao cliente'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('CONCLUÍDAS HOJE'), findsOneWidget);
    expect(find.text('Ir ao ginásio'), findsOneWidget);
    expect(find.byTooltip('Prioridade alta'), findsNWidgets(2));
    expect(find.text('Nova tarefa'), findsOneWidget);

    await tester.tap(find.text('Próximas').last);
    await tester.pumpAndSettle();
    expect(find.text('AMANHÃ'), findsOneWidget);
    expect(find.text('Preparar apresentação'), findsOneWidget);
    expect(find.text('SEM DATA'), findsOneWidget);
    expect(find.text('Ideias para o blogue'), findsOneWidget);
    expect(find.text('Pagar a conta da luz'), findsNothing);

    await tester.tap(find.text('Listas').last);
    await tester.pumpAndSettle();
    expect(find.text('Caixa de entrada'), findsOneWidget);
    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('2 tarefas por fazer'), findsWidgets);

    await shutdown(tester);
  });

  testWidgets('creates a task from the sheet', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chip('Hoje')).selected, isTrue);
    expect(
      tester.widget<ChoiceChip>(chip('Caixa de entrada')).selected,
      isTrue,
    );

    await tester.enterText(find.byType(TextField).first, 'Comprar pilhas');
    await tester.enterText(find.byType(TextField).at(1), 'Pilhas AA');
    await tap(tester, chip('Casa'));
    await tap(tester, chip('Alta'));
    await tap(tester, find.text('Adicionar subtarefa'));
    await tester.enterText(find.byType(TextField).last, 'Ver o tamanho');
    await tap(tester, find.text('Adicionar subtarefa'));
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);

    expect(find.text('Comprar pilhas'), findsOneWidget);
    expect(find.byTooltip('Prioridade alta'), findsNWidgets(3));
    expect(find.text('0/1'), findsOneWidget);
    final row = (await taskRows(tester))
        .singleWhere((r) => r.title == 'Comprar pilhas');
    expect(row.listId, 'casa');
    expect(row.notes, 'Pilhas AA');
    expect(row.dueDate, dateOnly(DateTime.now()));
    await shutdown(tester);
  });

  testWidgets('saving without a title shows an error', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Guardar'));
    expect(find.text('Escreva um título'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.pumpAndSettle();
    expect(find.text('Escreva um título'), findsNothing);
    await shutdown(tester);
  });

  testWidgets('completes a task and undoes it', (tester) async {
    await boot(tester);
    await tester.tap(checkboxOf('Comprar pão'));
    await settleIo(tester);
    expect(find.text('Tarefa concluída'), findsOneWidget);
    expect(tester.widget<Checkbox>(checkboxOf('Comprar pão')).value, isTrue);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(tester.widget<Checkbox>(checkboxOf('Comprar pão')).value, isFalse);

    await tester.tap(checkboxOf('Ir ao ginásio'));
    await settleIo(tester);
    expect(find.text('Tarefa reaberta'), findsOneWidget);
    expect(tester.widget<Checkbox>(checkboxOf('Ir ao ginásio')).value, isFalse);
    await shutdown(tester);
  });

  testWidgets('swipes a task away and undoes it', (tester) async {
    await boot(tester);
    await tester.drag(find.text('Comprar pão'), const Offset(-600, 0));
    await settleIo(tester);
    expect(find.text('Comprar pão'), findsNothing);
    expect(find.text('Tarefa apagada'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Comprar pão'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('edits subtasks, date and priority of a task', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Enviar proposta ao cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Editar tarefa'), findsOneWidget);

    // Tick "Anexar portefólio", remove "Enviar email".
    await tap(tester, inSheet(find.byType(Checkbox)).at(1));
    await tap(tester, find.byTooltip('Remover subtarefa').last);
    await tap(tester, chip('Sem data'));
    await tap(tester, chip('Média'));
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('Enviar proposta ao cliente'), findsNothing);

    await tester.tap(find.text('Próximas').last);
    await tester.pumpAndSettle();
    expect(find.text('Enviar proposta ao cliente'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    final row = (await taskRows(tester))
        .singleWhere((r) => r.title == 'Enviar proposta ao cliente');
    expect(row.dueDate, isNull);
    expect(row.priority, 2);
    await shutdown(tester);
  });

  testWidgets('quick and custom due dates', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Listas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chip('Sem data')).selected, isTrue);

    await tap(tester, chip('Amanhã'));
    expect(tester.widget<ChoiceChip>(chip('Amanhã')).selected, isTrue);
    await tap(tester, chip('Próxima semana'));
    expect(tester.widget<ChoiceChip>(chip('Próxima semana')).selected, isTrue);
    await tap(tester, chip('Sem data'));

    // A day of tomorrow's month that no quick chip covers.
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final quickDays = {
      now.day,
      tomorrow.day,
      DateTime(now.year, now.month, now.day + 7).day,
    };
    final day = [10, 11, 12, 13].firstWhere((d) => !quickDays.contains(d));
    final target = DateTime(tomorrow.year, tomorrow.month, day);

    await tap(tester, chip('Personalizada'));
    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('$day'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(chip(formatDayLabel(target))).selected,
      isTrue,
    );

    await tester.enterText(find.byType(TextField).first, 'Data escolhida');
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);
    final row = (await taskRows(tester))
        .singleWhere((r) => r.title == 'Data escolhida');
    expect(row.dueDate, target);
    expect(row.listId, 'inbox');
    await shutdown(tester);
  });

  testWidgets('deletes a task from the sheet and undoes it', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Comprar pão'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Apagar'));
    await settleIo(tester);
    expect(find.text('Comprar pão'), findsNothing);
    expect(find.text('Tarefa apagada'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Comprar pão'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('creates, fills, renames and deletes a list', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Listas').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova lista'));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Guardar'));
    expect(find.text('Escreva um nome'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Viagem');
    await tester.pumpAndSettle();
    expect(find.text('Escreva um nome'), findsNothing);
    await tap(tester, find.byTooltip('Destaque'));
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('Viagem'), findsOneWidget);
    expect(find.text('Nada por fazer'), findsOneWidget);

    await tester.tap(find.text('Viagem'));
    await tester.pumpAndSettle();
    expect(find.text('Lista vazia'), findsOneWidget);

    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chip('Viagem')).selected, isTrue);
    await tester.enterText(find.byType(TextField).first, 'Fazer a mala');
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('POR FAZER'), findsOneWidget);

    await tester.tap(checkboxOf('Fazer a mala'));
    await settleIo(tester);
    expect(find.text('Tudo feito'), findsOneWidget);
    expect(find.text('Fazer a mala'), findsNothing);
    await tester.tap(find.text('CONCLUÍDAS · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Fazer a mala'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Férias');
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('Férias'), findsOneWidget);

    await tester.tap(find.byTooltip('Apagar lista'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar lista?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await settleIo(tester);
    expect(find.text('Lista apagada'), findsOneWidget);
    expect(find.text('Férias'), findsNothing);
    final moved = (await taskRows(tester))
        .singleWhere((r) => r.title == 'Fazer a mala');
    expect(moved.listId, 'inbox');

    await tester.tap(find.text('Desfazer'));
    await settleIo(tester);
    expect(find.text('Férias'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('cancelling the delete keeps the list; the inbox has no '
      'delete', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Listas').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar a conta da luz'), findsOneWidget);
    expect(find.text('CONCLUÍDAS · 1'), findsNothing);
    await tester.tap(find.byTooltip('Apagar lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caixa de entrada'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Apagar lista'), findsNothing);
    expect(find.byTooltip('Editar lista'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('searches titles, notes and subtasks', (tester) async {
    await boot(tester);
    await tester.tap(find.byTooltip('Pesquisar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Procure por título, notas ou subtarefas.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'portefólio');
    await tester.pumpAndSettle();
    expect(find.text('1 RESULTADO'), findsOneWidget);
    expect(find.text('Enviar proposta ao cliente'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nada disto');
    await tester.pumpAndSettle();
    expect(find.text('Nada encontrado'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Procure por título, notas ou subtarefas.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(find.textContaining('RESULTADOS'), findsOneWidget);

    // Back closes the search instead of leaving the app.
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('EM ATRASO'), findsOneWidget);

    await tester.tap(find.byTooltip('Pesquisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar pesquisa'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pesquisar'), findsOneWidget);

    await tester.tap(find.byTooltip('Pesquisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listas').last);
    await tester.pumpAndSettle();
    expect(find.text('AS MINHAS LISTAS'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('empty states without demo data', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    // Not a brand new database, so no demo data is added.
    await tester.runAsync(
      () => database
          .into(database.taskLists)
          .insert(TaskListsCompanion.insert(id: 'inbox', name: 'Entrada')),
    );
    await boot(tester, database: database);
    expect(find.text('Nada para hoje'), findsOneWidget);

    await tester.tap(find.text('Próximas').last);
    await tester.pumpAndSettle();
    expect(find.text('Nada pela frente'), findsOneWidget);
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chip('Amanhã')).selected, isTrue);
    await tester.enterText(find.byType(TextField).first, 'Amanhã cedo');
    await tap(tester, find.text('Guardar'));
    await settleIo(tester);
    expect(find.text('AMANHÃ'), findsOneWidget);

    await tester.tap(find.text('Hoje').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Só hoje');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleIo(tester);
    await tester.tap(checkboxOf('Só hoje'));
    await settleIo(tester);
    expect(find.text('Tudo feito por hoje'), findsOneWidget);

    await tester.tap(find.text('Listas').last);
    await tester.pumpAndSettle();
    expect(find.text('1 tarefa por fazer'), findsOneWidget);
    await tester.tap(find.text('Entrada'));
    await tester.pumpAndSettle();
    expect(find.text('Amanhã cedo'), findsOneWidget);
    expect(find.text('Amanhã'), findsOneWidget);
    await shutdown(tester);
  });

  testWidgets('appearance choice survives a restart', (tester) async {
    final dir = Directory.systemTemp.createTempSync('metasks_widget');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.tap(find.text('MeRemind'));
    await settleIo(tester);
    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.dark);
    await shutdown(tester);

    await boot(tester, database: AppDatabase(NativeDatabase(file)));
    expect(app().themeMode, ThemeMode.dark);
    expect(
      app().theme!.colorScheme.primary,
      MeAppTheme.meremind.light().colorScheme.primary,
    );
    // Demo data was only added on the first start.
    expect(find.text('Comprar pão'), findsOneWidget);
    await shutdown(tester);
  });
}

Future<void> settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}
