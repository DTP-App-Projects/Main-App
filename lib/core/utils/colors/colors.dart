import 'package:flutter/material.dart';

/// Brand constants shared with the Driver app. Everything else colour-related
/// lives in `AppTokens` (theme/tokens.dart), which also carries dark mode.
class AppColors {
  AppColors._();

  static const Color brandBlue = Color(0xFF0350A8);
  static const Color brandTeal = Color(0xFF037460);

  /// The one gradient: blue on the physical left, teal on the right, in both
  /// reading directions — it is a brand mark, not a direction.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandBlue, brandTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// The logo tile's diagonal variant (teal top-right, blue bottom-left).
  static const LinearGradient brandGradientDiagonal = LinearGradient(
    colors: [brandBlue, brandTeal],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // ---- legacy names (pre-Driver), kept until the Phase 7 cleanup ----------

  static const Color primarySwatchColor = brandTeal;
  static const Color secondaryColor = brandBlue;
  static const Color greyFont = Color(0xff76757A);
  static const Color grey46 = Color(0xff464646);
  static const Color red = Color(0xffE84442);

  static MaterialColor primaryColor = const MaterialColor(0xFF037460, <int, Color>{
    50: Color(0x1A037460),
    100: Color(0x33037460),
    200: Color(0x4D037460),
    300: Color(0x66037460),
    400: Color(0x80037460),
    500: Color(0x99037460),
    600: Color(0xB3037460),
    700: Color(0xCC037460),
    800: Color(0xE6037460),
    900: Color(0xFF037460),
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
