import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/app_header.dart';
import '../../workspace/workspace.dart';
import 'tokens.dart';
import 'typography.dart';

/// The app theme, built on the Driver app's design system.
///
/// [workspacePalette] is the per-workspace palette the server sends. It is
/// accepted so the theme still rebuilds on a workspace switch, but it does
/// **not** colour the UI any more: the brand is fixed (blue → teal) and the
/// active role is shown by `RoleBadge`, which reads the palette itself.
ThemeData buildAppTheme(
  ThemeTokens workspacePalette,
  String locale, {
  Brightness brightness = Brightness.light,
}) {
  final t = AppTokens.of(brightness);
  final text = AppType.themeFor(
    locale: locale,
    ink: t.textPrimary,
    muted: t.textSecondary,
  );
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.primary,
    onPrimary: Colors.white,
    primaryContainer: t.primaryTint,
    onPrimaryContainer: t.primary,
    secondary: t.info,
    onSecondary: Colors.white,
    secondaryContainer: t.infoTint,
    onSecondaryContainer: t.info,
    tertiary: t.warning,
    onTertiary: Colors.white,
    tertiaryContainer: t.warningTint,
    onTertiaryContainer: t.warning,
    error: t.danger,
    onError: Colors.white,
    errorContainer: t.dangerTint,
    onErrorContainer: t.danger,
    surface: t.surface,
    onSurface: t.textPrimary,
    onSurfaceVariant: t.textSecondary,
    surfaceContainerLowest: t.surface,
    surfaceContainerLow: t.surface,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.surfaceRaised,
    surfaceContainerHighest: t.neutralTint,
    outline: t.inputBorder,
    outlineVariant: t.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: t.textPrimary,
    onInverseSurface: t.background,
    inversePrimary: t.primaryTint,
    surfaceTint: Colors.transparent,
  );

  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: AppTokens.mdRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  const buttonShape = RoundedRectangleBorder(borderRadius: AppTokens.lgRadius);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [t],
    fontFamily: AppType.family,
    textTheme: text,
    scaffoldBackgroundColor: t.background,
    canvasColor: t.background,
    cardColor: t.surface,
    dividerColor: t.divider,
    hintColor: t.textSecondary,
    disabledColor: t.textTertiary,
    splashColor: t.primary.withValues(alpha: 0.08),
    highlightColor: Colors.transparent,
    shadowColor: Colors.black,

    dividerTheme: DividerThemeData(
      color: t.divider,
      space: AppTokens.ruleWidth,
      thickness: AppTokens.ruleWidth,
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.primary,
      linearTrackColor: t.primaryTint,
      circularTrackColor: Colors.transparent,
      linearMinHeight: 3,
    ),

    // Driver pushed screens: the bar is the page — no fill, no rule, no
    // shadow — with an 18/600 start-aligned title.
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      foregroundColor: t.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: AppTokens.space2,
      titleTextStyle: text.titleMedium,
      iconTheme: IconThemeData(color: t.textPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: t.textPrimary, size: 22),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),

    // Solid teal: the Driver dialog's "safe" button. The gradient primary
    // CTA is `AppButton.primary` / `SubmitButton`.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: t.neutralTint,
        disabledForegroundColor: t.textTertiary,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space5),
        textStyle: text.labelLarge,
        elevation: 0,
        shape: buttonShape,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        textStyle: text.labelLarge,
        elevation: 0,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.textPrimary,
        backgroundColor: t.surface,
        disabledForegroundColor: t.textTertiary,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space5),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        side: BorderSide(color: t.inputBorder, width: AppTokens.ruleWidth),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.primary,
        textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        minimumSize: const Size(0, AppTokens.touchTarget),
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.mdRadius),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: t.textPrimary),
    ),
    iconTheme: IconThemeData(color: t.textSecondary, size: 22),

    // Every BackButton / CloseButton in an AppBar becomes the Driver circle.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const AppBackIcon(),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.primary,
      foregroundColor: Colors.white,
      elevation: 1,
      focusElevation: 1,
      hoverElevation: 2,
      highlightElevation: 2,
      extendedTextStyle: text.labelLarge,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.lgRadius),
    ),

    // Driver field: off-white well, hairline border, r12; deep-red 1.5dp on
    // error. Labels sit *above* the field (see `AppFieldShell`); a raw
    // TextField that still passes `labelText` gets the same quiet label.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.inputFill,
      isDense: false,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppTokens.space4,
        vertical: AppTokens.space4,
      ),
      border: field(t.inputBorder),
      enabledBorder: field(t.inputBorder),
      disabledBorder: field(t.border),
      focusedBorder: field(t.primary, 1.5),
      errorBorder: field(t.fieldError, 1.5),
      focusedErrorBorder: field(t.fieldError, 1.5),
      labelStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
      floatingLabelStyle: text.labelMedium?.copyWith(color: t.textSecondary),
      hintStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
      helperStyle: text.labelSmall,
      helperMaxLines: 3,
      errorStyle: text.labelSmall?.copyWith(color: t.fieldError, fontWeight: FontWeight.w400),
      errorMaxLines: 3,
      prefixIconColor: t.textTertiary,
      suffixIconColor: t.textSecondary,
      suffixStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
      prefixStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.primary,
      selectionColor: t.primary.withValues(alpha: 0.25),
      selectionHandleColor: t.primary,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: t.primaryTint,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected) ? t.primary : t.navInactive,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),

    // Item card: white, r16, hairline border. Section cards (r20) are
    // `AppCard.section`.
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.lgRadius,
        side: BorderSide(color: t.border, width: AppTokens.ruleWidth),
      ),
    ),

    // Pills: filter chips, choice chips, info chips.
    chipTheme: ChipThemeData(
      backgroundColor: t.surface,
      selectedColor: t.primaryTint,
      disabledColor: t.neutralTint,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected) ? t.primary : t.border,
          width: AppTokens.ruleWidth,
        ),
      ),
      labelStyle: text.labelMedium!.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.primary : t.textSecondary,
        ),
      ),
      secondaryLabelStyle: text.labelMedium!.copyWith(color: t.primary, fontWeight: FontWeight.w700),
      showCheckmark: false,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space2, vertical: 6),
      shape: const StadiumBorder(),
      iconTheme: IconThemeData(color: t.primary, size: 18),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: t.primary,
      textColor: t.textPrimary,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      leadingAndTrailingTextStyle: text.bodySmall,
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space4),
      minVerticalPadding: AppTokens.space3,
      horizontalTitleGap: AppTokens.space3,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.lgRadius),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : t.iconMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.primary : t.neutralTint,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.primary : t.inputBorder,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.primary : Colors.transparent,
      ),
      side: BorderSide(color: t.iconMuted, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.primary : t.iconMuted,
      ),
    ),

    badgeTheme: BadgeThemeData(
      backgroundColor: t.danger,
      textColor: Colors.white,
      textStyle: text.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? t.surfaceRaised : t.textPrimary,
      contentTextStyle: text.bodyMedium?.copyWith(color: dark ? t.textPrimary : Colors.white),
      actionTextColor: dark ? t.primary : const Color(0xFF7FD6C2),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      // Symmetric, so the physical insets are direction-safe.
      insetPadding: const EdgeInsets.fromLTRB(
        AppTokens.gutter,
        0,
        AppTokens.gutter,
        AppTokens.space4,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.mdRadius),
    ),

    // Driver dialog: white, r20, generous padding.
    dialogTheme: DialogThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      barrierColor: t.scrim,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppTokens.space6, vertical: AppTokens.space6),
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      contentTextStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.xlRadius),
    ),

    // Driver sheet: r24 top corners, a 40×4 handle.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surfaceRaised,
      modalBackgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: t.scrim,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: dark ? t.inputBorder : const Color(0xFFE4E4E7),
      dragHandleSize: const Size(40, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusSheet)),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.mdRadius,
        side: BorderSide(color: t.border),
      ),
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: t.primary,
      headerForegroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.xlRadius),
      todayBorder: BorderSide(color: t.primary),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? t.surfaceRaised : t.textPrimary,
        borderRadius: AppTokens.smRadius,
      ),
      textStyle: text.labelSmall?.copyWith(color: dark ? t.textPrimary : Colors.white),
    ),
  );
}
