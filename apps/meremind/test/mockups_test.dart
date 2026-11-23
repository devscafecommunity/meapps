import 'package:flutter_test/flutter_test.dart';
import 'package:meremind/main.dart';

void main() {
  testWidgets('navigates between the three mockup tabs', (tester) async {
    await tester.pumpWidget(const MeRemindApp());

    expect(find.text('Novo lembrete'), findsOneWidget);

    await tester.tap(find.text('Notas').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova nota'), findsOneWidget);
    expect(find.text('Lista de compras'), findsOneWidget);

    await tester.tap(find.text('Lembretes').last);
    await tester.pumpAndSettle();
    expect(find.text('HOJE'), findsOneWidget);
  });
}
