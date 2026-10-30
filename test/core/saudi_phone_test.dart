import 'package:digital_trade_portal/core/ui/form_fields.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone rule lives in the formatter: the field can only ever hold a
/// prefix of `05XXXXXXXX`.
void main() {
  final formatter = SaudiPhone.formatters.single;

  /// Types [text] onto a field currently holding [from].
  String type(String from, String text) => formatter
      .formatEditUpdate(
        TextEditingValue(text: from, selection: TextSelection.collapsed(offset: from.length)),
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
      )
      .text;

  test('a local mobile number types through unchanged', () {
    expect(type('', '0'), '0');
    expect(type('0', '05'), '05');
    expect(type('050123456', '0501234567'), '0501234567');
  });

  test('the first digit must be 0 and the second 5', () {
    expect(type('', '1'), '', reason: 'refused');
    expect(type('0', '01'), '0', reason: 'landline prefix refused');
    expect(type('0', '00'), '0');
  });

  test('a number started without the zero gets it', () {
    expect(type('', '5'), '05');
  });

  test('stops at ten digits and drops non-digits', () {
    expect(type('0501234567', '05012345678'), '0501234567');
    expect(type('050', '050-'), '050');
  });

  test('pasted international forms become 05…', () {
    expect(type('', '+966 50 123 4567'), '0501234567');
    expect(type('', '00966501234567'), '0501234567');
    expect(type('', '966501234567'), '0501234567');
  });

  test('a paste that cannot become a Saudi mobile is refused', () {
    expect(type('05', '0112345678'), '05');
    expect(type('', '+1 202 555 0100'), '');
  });

  test('the cursor lands at the end', () {
    final out = formatter.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '0501'));
    expect(out.selection.baseOffset, 4);
  });
}
