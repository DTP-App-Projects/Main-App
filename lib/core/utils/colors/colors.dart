import 'package:flutter/material.dart';

class AppColors {
  static const Color primarySwatchColor = Color(0xff4E028B);
  static const Color greyFont = Color(0xff76757A);
  static const Color grey46 = Color(0xff464646);
  static const Color red = Color(0xffE84442);

  static MaterialColor primaryColor = const MaterialColor(0xFF4E028B, <int, Color>{
    50: Color(0x1A4E028B),
    100: Color(0x334E028B),
    200: Color(0x4D4E028B),
    300: Color(0x664E028B),
    400: Color(0x804E028B),
    500: Color(0x994E028B),
    600: Color(0xB34E028B),
    700: Color(0xCC4E028B),
    800: Color(0xE64E028B),
    900: Color(0xFF4E028B),
  });

  static MaterialColor neutralColor = const MaterialColor(0xff101828, <int, Color>{
    50: Color(0xffF9FAFB),
    100: Color(0xffF2F4F7),
    200: Color(0xffEAECF0),
    300: Color(0xffD0D5DD),
    400: Color(0xff98A2B3),
    500: Color(0xff667085),
    600: Color(0xff344054),
    700: Color(0xff1D2939),
    800: Color(0xff101828),
    900: Color(0xff101828),
  });
}
