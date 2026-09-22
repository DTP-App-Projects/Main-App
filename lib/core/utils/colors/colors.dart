import 'package:flutter/material.dart';

class AppColors {
  static const Color primarySwatchColor = Color(0xff03745f);
  static const Color secondaryColor = Color(0xff014eaf);
  static const Color greyFont = Color(0xff76757A);
  static const Color grey46 = Color(0xff464646);
  static const Color red = Color(0xffE84442);

  /// Green -> blue gradient taken from the app logo.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [secondaryColor, primarySwatchColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static MaterialColor primaryColor = const MaterialColor(0xFF03745f, <int, Color>{
    50: Color(0x1A03745f),
    100: Color(0x3303745f),
    200: Color(0x4D03745f),
    300: Color(0x6603745f),
    400: Color(0x8003745f),
    500: Color(0x9903745f),
    600: Color(0xB303745f),
    700: Color(0xCC03745f),
    800: Color(0xE603745f),
    900: Color(0xFF03745f),
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
