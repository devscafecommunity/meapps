import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meapps_ui/meapps_ui.dart';

void main() {
  test('every app theme builds light and dark with its own seed', () {
    for (final t in MeAppTheme.all) {
      expect(t.light().brightness, Brightness.light);
      expect(t.dark().brightness, Brightness.dark);
    }
    expect(
      MeAppTheme.meremind.light().colorScheme.primary,
      isNot(MeAppTheme.metasks.light().colorScheme.primary),
    );
  });

  testWidgets('MeMonthGrid reports taps', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MeMonthGrid(
          month: DateTime(2026, 2),
          selected: DateTime(2026, 2, 1),
          onSelected: (d) => tapped = d,
        ),
      ),
    ));
    await tester.tap(find.text('14'));
    expect(tapped, DateTime(2026, 2, 14));
  });
}
