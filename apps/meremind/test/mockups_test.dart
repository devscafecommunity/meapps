import 'package:flutter/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meremind/data/database.dart';
import 'package:meremind/main.dart';

void main() {
  testWidgets('navigates between the three tabs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MeRemindApp(database: db));
    // Real SQLite I/O does not advance in fake-async time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Novo lembrete'), findsOneWidget);

    await tester.tap(find.text('Notas').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova nota'), findsOneWidget);
    expect(find.text('Lista de compras'), findsOneWidget);

    await tester.tap(find.text('Lembretes').last);
    await tester.pumpAndSettle();
    expect(find.text('HOJE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
