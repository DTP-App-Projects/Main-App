import 'package:flutter/material.dart';

/// One family, both scripts.
///
/// IBM Plex Sans Arabic ships a Latin set drawn against its Arabic, so the app
/// keeps a single voice when the locale flips — and it is the Driver app's
/// face too.
const _family = 'IBMPlex';

/// Arabic sits lower and its ascenders collide across lines, so it gets more
/// leading. Sizes are *not* scaled: the Driver scale was measured on Arabic
/// screens already.
const _arabicLeading = 1.1;

/// The type scale, from the Driver app (`DRIVER_DESIGN_SYSTEM.md` ›
/// Typography). Hierarchy is weight + size + ink, never colour alone: one bold
/// anchor per screen, then 16/600 titles and quiet 14–15 text.
abstract final class AppType {
  static const family = _family;

  static const _figures = <FontFeature>[
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  /// An amount on a row. Tabular, so a column of them lines up.
  static TextStyle ledger(Color color, {double size = 16}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: _figures,
      );

  /// A figure that carries a screen on its own — a balance, a net payable.
  static TextStyle ledgerLarge(Color color) => ledger(color, size: 28);

  /// A stat tile value (Driver: 24/700 in a semantic colour).
  static TextStyle stat(Color color) => ledger(color, size: 24);

  /// A document's own serial (`PO-…`, `RT-…`). Latin, so it keeps a touch of
  /// tracking to stay countable.
  static TextStyle code(Color color, {double size = 16}) => TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: color,
        fontFeatures: _figures,
      );

  /// Builds the text theme for a locale and ink ramp.
  static TextTheme themeFor({
    required String locale,
    required Color ink,
    required Color muted,
  }) {
    final arabic = !locale.startsWith('en');
    double leading(double value) => arabic ? value * _arabicLeading : value;

    TextStyle style(
      double fontSize,
      double height,
      FontWeight weight, {
      double tracking = 0,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: _family,
          fontSize: fontSize,
          height: leading(height),
          fontWeight: weight,
          // Arabic is connected; tracking pulls the joins apart.
          letterSpacing: arabic ? 0 : tracking,
          color: color ?? ink,
        );

    return TextTheme(
      // Home greeting name.
      displaySmall: style(30, 1.2, FontWeight.w700, tracking: -0.4),
      // Auth screen title.
      headlineMedium: style(24, 1.25, FontWeight.w700, tracking: -0.3),
      // Tab page title.
      headlineSmall: style(22, 1.3, FontWeight.w600, tracking: -0.2),
      // Sheet / header name.
      titleLarge: style(20, 1.3, FontWeight.w700, tracking: -0.2),
      // Card title, app bar title.
      titleMedium: style(18, 1.35, FontWeight.w600),
      // Row title.
      titleSmall: style(16, 1.4, FontWeight.w600),
      bodyLarge: style(16, 1.5, FontWeight.w400),
      bodyMedium: style(15, 1.5, FontWeight.w400),
      // Meta lines, subtitles.
      bodySmall: style(14, 1.45, FontWeight.w400, color: muted),
      // Buttons.
      labelLarge: style(16, 1.2, FontWeight.w700),
      // Field labels, section labels.
      labelMedium: style(14, 1.3, FontWeight.w500),
      // Nav labels, badges, captions.
      labelSmall: style(13, 1.35, FontWeight.w500, color: muted),
    );
  }
}
