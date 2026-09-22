import 'package:flutter/services.dart';

class SaudiPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // 1) حوّل الأرقام العربية لإنجليزية
    String text = newValue.text.replaceAllMapped(RegExp(r'[\u0660-\u0669]'), (m) {
      return (m.group(0)!.codeUnitAt(0) - 0x0660).toString();
    });

    // 2) احذف أي شيء غير أرقام
    text = text.replaceAll(RegExp(r'[^0-9]'), '');

    // 3) شيل مقدّمات السعودية لو موجودة: 00966 أو 966
    text = text.replaceFirst(RegExp(r'^(?:00966|966)'), '');

    // 4) شيل أي صفر/أصفار في البداية (عشان 05XXXXXXXX -> 5XXXXXXXX)
    text = text.replaceFirst(RegExp(r'^0+'), '');

    // 5) أول رقم لازم يكون 5، وإلا نرفض التعديل
    if (text.isNotEmpty && text[0] != '5') {
      return oldValue;
    }

    // 6) ثبّت الطول على 9 أرقام (5XXXXXXXX)
    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
