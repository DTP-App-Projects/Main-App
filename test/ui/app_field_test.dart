import 'package:digital_trade_portal/core/ui/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A multi-line AppField with `TextInputAction.newline` used to trip
/// Flutter's assertion (newline action + single-line `text` keyboard).
void main() {
  Future<TextField> pump(WidgetTester tester, AppField field) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field)));
    expect(tester.takeException(), isNull);
    return tester.widget<TextField>(find.byType(TextField));
  }

  testWidgets('multi-line + newline gets the multi-line keyboard', (tester) async {
    final field = await pump(
      tester,
      AppField(
        controller: TextEditingController(),
        label: 'notes',
        maxLines: 3,
        textInputAction: TextInputAction.newline,
      ),
    );
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
  });

  testWidgets('a multi-line field left at the defaults breaks lines on Enter', (tester) async {
    final field = await pump(
      tester,
      AppField(controller: TextEditingController(), label: 'notes', maxLines: 3),
    );
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
  });

  testWidgets('single-line fields keep their keyboard and action', (tester) async {
    final field = await pump(
      tester,
      AppField(
        controller: TextEditingController(),
        label: 'phone',
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
      ),
    );
    expect(field.keyboardType, TextInputType.phone);
    expect(field.textInputAction, TextInputAction.done);
  });
}
