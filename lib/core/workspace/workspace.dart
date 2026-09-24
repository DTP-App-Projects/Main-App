import 'package:flutter/material.dart';

import '../network/coerce.dart';

/// The two sides of the same business flow. Which one is active is
/// **client-side state** — there is no workspace-switch endpoint.
enum Workspace {
  trader,
  supplier;

  /// The literal the server expects in `?role=` and `?workspace=`.
  String get api => name;

  static Workspace? tryParse(dynamic raw) {
    switch (asStr(raw)) {
      case 'trader':
        return Workspace.trader;
      case 'supplier':
        return Workspace.supplier;
      default:
        return null;
    }
  }
}

/// `business_mode` from `/v2/bootstrap`, which decides the shell.
class BusinessMode {
  BusinessMode._();

  static const trader = 'trader';
  static const supplier = 'supplier';
  static const hybrid = 'hybrid';
}

/// The palette `/ops/panel` and `/ops/quick_actions` ship per workspace.
/// Recolouring on switch is the product's own signal for "you are now the
/// supplier" — so these are never hardcoded in a widget.
@immutable
class ThemeTokens {
  final Color primary;
  final Color primaryOn;
  final Color secondary;
  final Color accent;
  final Color surface;

  const ThemeTokens({
    required this.primary,
    required this.primaryOn,
    required this.secondary,
    required this.accent,
    required this.surface,
  });

  /// Compile-time fallbacks for cold start and offline, straight from the
  /// contract. The server is still the source of truth once it answers.
  static const traderFallback = ThemeTokens(
    primary: Color(0xFFF26A1F),
    primaryOn: Color(0xFFFFFFFF),
    secondary: Color(0xFF1E56A0),
    accent: Color(0xFFB24A0F),
    surface: Color(0xFFFFF8F2),
  );

  static const supplierFallback = ThemeTokens(
    primary: Color(0xFF1E56A0),
    primaryOn: Color(0xFFFFFFFF),
    secondary: Color(0xFFF26A1F),
    accent: Color(0xFF0C2D57),
    surface: Color(0xFFF5F8FB),
  );

  static ThemeTokens fallbackFor(Workspace workspace) =>
      workspace == Workspace.trader ? traderFallback : supplierFallback;

  factory ThemeTokens.fromJson(Map<String, dynamic> json, {required Workspace workspace}) {
    final base = fallbackFor(workspace);
    return ThemeTokens(
      primary: _color(json['primary_color'], base.primary),
      primaryOn: _color(json['primary_on'], base.primaryOn),
      secondary: _color(json['secondary_color'], base.secondary),
      accent: _color(json['accent_color'], base.accent),
      surface: _color(json['surface_color'], base.surface),
    );
  }

  /// Round-trips through the cache, so a cold start repaints in the palette
  /// the server last sent instead of the compile-time fallback.
  Map<String, dynamic> toJson() => {
        'primary_color': _hex(primary),
        'primary_on': _hex(primaryOn),
        'secondary_color': _hex(secondary),
        'accent_color': _hex(accent),
        'surface_color': _hex(surface),
      };

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// `#1E56A0`, `1E56A0` and `#FF1E56A0` all parse; anything else keeps the
  /// fallback rather than throwing on a theme value.
  static Color _color(dynamic raw, Color fallback) {
    var hex = asStr(raw).trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeTokens &&
      other.primary == primary &&
      other.primaryOn == primaryOn &&
      other.secondary == secondary &&
      other.accent == accent &&
      other.surface == surface;

  @override
  int get hashCode => Object.hash(primary, primaryOn, secondary, accent, surface);
}
