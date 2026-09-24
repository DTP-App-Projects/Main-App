import 'package:flutter/material.dart';

import '../colors/colors.dart';

/// The design tokens, taken from the Driver app so both apps read as one
/// product (see `DRIVER_DESIGN_SYSTEM.md`).
///
/// The brand is fixed: blue → teal. The per-workspace palette the server
/// sends (`ThemeTokens`) no longer colours the UI — it only tints the role
/// badge (`RoleBadge`), which is how the app now says "you are the supplier".
///
/// The system in one line:
///
/// > **Grey page, white surfaces, one gradient, soft corners, and colour only
/// > as text on its own tint.**
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final bool isDark;

  // ---- surfaces ------------------------------------------------------------

  /// The page. Cards sit on it as white islands.
  final Color background;

  /// Cards, the nav bar, stat tiles.
  final Color surface;

  /// Sheets and dialogs — one step above [surface] in dark mode.
  final Color surfaceRaised;

  /// Text fields. Slightly off the card colour so a field reads as a well.
  final Color inputFill;

  // ---- lines ---------------------------------------------------------------

  /// Card outlines.
  final Color border;

  /// Separators inside a card.
  final Color divider;

  /// Field outlines at rest.
  final Color inputBorder;

  // ---- text ----------------------------------------------------------------

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Chevrons and inline meta icons.
  final Color iconMuted;
  final Color navInactive;

  // ---- brand ---------------------------------------------------------------

  /// Teal. Text, icons and solid fills that carry the brand.
  final Color primary;

  /// Behind icon circles, empty-state discs and "good" pills.
  final Color primaryTint;

  /// Count badges.
  final Color primaryTintSoft;

  // ---- semantic ------------------------------------------------------------

  /// Fills, icons and the destructive CTA (the Driver's exact red).
  final Color danger;

  /// Danger as *text* (pills, destructive titles, error copy). The Driver red
  /// is 3.4–3.9 : 1 on light surfaces, below AA for small text, so words get
  /// this deeper variant; it reads as the same red.
  final Color dangerText;
  final Color dangerTint;
  final Color dangerBorder;

  /// Field validation. Deeper than [danger] on light surfaces, as in the
  /// Driver login.
  final Color fieldError;

  final Color warning;

  /// Warning as text, AA on [warningTint] and on the page.
  final Color warningText;
  final Color warningTint;
  final Color info;
  final Color infoTint;

  /// Neutral pill / skeleton base.
  final Color neutralTint;

  final Color scrim;

  const AppTokens({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.inputFill,
    required this.border,
    required this.divider,
    required this.inputBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconMuted,
    required this.navInactive,
    required this.primary,
    required this.primaryTint,
    required this.primaryTintSoft,
    required this.danger,
    required this.dangerText,
    required this.dangerTint,
    required this.dangerBorder,
    required this.fieldError,
    required this.warning,
    required this.warningText,
    required this.warningTint,
    required this.info,
    required this.infoTint,
    required this.neutralTint,
    required this.scrim,
  });

  static const light = AppTokens(
    isDark: false,
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    inputFill: Color(0xFFFBFBFB),
    border: Color(0xFFEEEFF1),
    divider: Color(0xFFF1F2F4),
    inputBorder: Color(0xFFEAEAEA),
    textPrimary: Color(0xFF12161F),
    textSecondary: Color(0xFF454545),
    textTertiary: Color(0xFF8A8A8A),
    iconMuted: Color(0xFF9AA0AC),
    navInactive: Color(0xFF5C5F66),
    primary: AppColors.brandTeal,
    primaryTint: Color(0xFFE6F0EF),
    primaryTintSoft: Color(0xFFEBF4F3),
    danger: Color(0xFFE84540),
    dangerText: Color(0xFFC8302B),
    dangerTint: Color(0xFFFCECEC),
    dangerBorder: Color(0xFFEBC3C4),
    fieldError: Color(0xFFB3261E),
    warning: Color(0xFFB26A00),
    warningText: Color(0xFF945700),
    warningTint: Color(0xFFFDF3E1),
    info: AppColors.brandBlue,
    infoTint: Color(0xFFE7EEF8),
    neutralTint: Color(0xFFF1F2F4),
    scrim: Color(0x8C000000),
  );

  static const dark = AppTokens(
    isDark: true,
    background: Color(0xFF0E1116),
    surface: Color(0xFF171B22),
    surfaceRaised: Color(0xFF1D222A),
    inputFill: Color(0xFF1A1F27),
    border: Color(0xFF262C36),
    divider: Color(0xFF222832),
    inputBorder: Color(0xFF2B323D),
    textPrimary: Color(0xFFF1F3F6),
    textSecondary: Color(0xFFB3BAC5),
    textTertiary: Color(0xFF7E8794),
    iconMuted: Color(0xFF7E8794),
    navInactive: Color(0xFF8A93A0),
    primary: Color(0xFF3CC0A1),
    primaryTint: Color(0xFF15332E),
    primaryTintSoft: Color(0xFF15332E),
    danger: Color(0xFFF26B66),
    dangerText: Color(0xFFF26B66),
    dangerTint: Color(0xFF3A1E21),
    dangerBorder: Color(0xFF5A2A2D),
    fieldError: Color(0xFFF2837D),
    warning: Color(0xFFF2B340),
    warningText: Color(0xFFF2B340),
    warningTint: Color(0xFF3A2E17),
    info: Color(0xFF6FA3EE),
    infoTint: Color(0xFF19263A),
    neutralTint: Color(0xFF222832),
    scrim: Color(0xA6000000),
  );

  factory AppTokens.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  // ---- legacy names --------------------------------------------------------
  // The pre-Driver "ledger" vocabulary, kept as aliases so existing call
  // sites keep compiling while screens migrate.

  Color get paper => background;
  Color get paperRaised => surface;
  Color get write => inputFill;
  Color get ink => textPrimary;
  Color get inkMuted => textSecondary;
  Color get inkFaint => textTertiary;
  Color get rule => border;
  Color get good => primary;
  Color get warn => warningText;
  Color get inFlight => info;

  // ---- gradient ------------------------------------------------------------

  /// The one gradient. Physical left → right (blue on the left) in both
  /// directions: it is a brand mark, not a reading direction.
  static const LinearGradient brandGradient = AppColors.brandGradient;

  // ---- shape ---------------------------------------------------------------

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusSheet = 24;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius fullRadius = BorderRadius.all(Radius.circular(999));

  /// Legacy names, now pointing at the Driver radii.
  static const BorderRadius recordRadius = lgRadius;
  static const BorderRadius controlRadius = mdRadius;

  /// Width of a status mark on a reading-start edge (legacy ledger rows).
  static const markWidth = 3.0;

  /// The hairline weight.
  static const ruleWidth = 1.0;

  // ---- space ---------------------------------------------------------------

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  /// Screen edge → content.
  static const gutter = 20.0;
  static const cardPadding = 20.0;
  static const sectionGap = 24.0;
  static const rowHeight = 72.0;

  /// The floor for anything tappable.
  static const touchTarget = 48.0;

  static const EdgeInsetsDirectional pagePadding =
      EdgeInsetsDirectional.fromSTEB(gutter, space4, gutter, space8);

  // ---- elevation -----------------------------------------------------------

  /// The only card shadow — a faint halo, dropped in dark mode.
  List<BoxShadow> get shadowSoft => isDark
      ? const []
      : const [BoxShadow(color: Color(0x0D101828), blurRadius: 16, offset: Offset(0, 4))];

  /// The bottom nav's top edge.
  List<BoxShadow> get shadowNav => isDark
      ? const []
      : const [BoxShadow(color: Color(0x0A101828), blurRadius: 12, offset: Offset(0, -2))];

  // ---- status --------------------------------------------------------------

  /// Text / icon colour for a status tone (AA on its [toneTint]).
  Color toneColor(StatusTone tone) => switch (tone) {
        StatusTone.good => primary,
        StatusTone.inFlight => info,
        StatusTone.warn => warningText,
        StatusTone.danger => dangerText,
        StatusTone.unknown => textSecondary,
      };

  /// The tint behind [toneColor] in a pill.
  Color toneTint(StatusTone tone) => switch (tone) {
        StatusTone.good => primaryTint,
        StatusTone.inFlight => infoTint,
        StatusTone.warn => warningTint,
        StatusTone.danger => dangerTint,
        StatusTone.unknown => neutralTint,
      };

  /// Legacy: the colour of a ledger margin mark. Unknown gets none.
  Color? markFor(StatusTone tone) => tone == StatusTone.unknown ? null : toneColor(tone);

  /// Legacy: the colour of a status word.
  Color textFor(StatusTone tone) => toneColor(tone);

  @override
  AppTokens copyWith({Color? background, Color? surface, Color? primary}) => AppTokens(
        isDark: isDark,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised,
        inputFill: inputFill,
        border: border,
        divider: divider,
        inputBorder: inputBorder,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        iconMuted: iconMuted,
        navInactive: navInactive,
        primary: primary ?? this.primary,
        primaryTint: primaryTint,
        primaryTintSoft: primaryTintSoft,
        danger: danger,
        dangerText: dangerText,
        dangerTint: dangerTint,
        dangerBorder: dangerBorder,
        fieldError: fieldError,
        warning: warning,
        warningText: warningText,
        warningTint: warningTint,
        info: info,
        infoTint: infoTint,
        neutralTint: neutralTint,
        scrim: scrim,
      );

  /// The theme only ever switches between the two fixed sets, so a snap at
  /// the midpoint is indistinguishable from a per-colour lerp.
  @override
  AppTokens lerp(AppTokens? other, double t) => (other == null || t < 0.5) ? this : other;
}

/// What a document's status means, independent of the words it arrives in.
///
/// The status *values* come from the server; only the tone is decided here,
/// and an unrecognised one stays [unknown] rather than disappearing.
enum StatusTone { unknown, inFlight, good, warn, danger }

extension AppTokensOf on BuildContext {
  /// The design tokens for the current brightness.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
