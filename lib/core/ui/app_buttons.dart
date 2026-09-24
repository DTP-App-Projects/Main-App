import 'package:flutter/material.dart';

import '../utils/theme/tokens.dart';

enum AppButtonVariant {
  /// The gradient CTA — one per screen (Driver "متابعة").
  primary,

  /// Solid teal — the safe action in a dialog, secondary positives.
  solid,

  /// Neutral outline on the card colour.
  outline,

  /// Solid red — the one destructive CTA in a destructive sheet.
  danger,

  /// Red text on a neutral fill with a red hairline — the destructive choice
  /// in a confirmation, deliberately quieter than the safe one.
  outlineDanger,

  /// Teal text, no container.
  text,
}

/// The Driver button family.
///
/// Busy keeps the button's size and swaps the label for a spinner, so a form
/// does not jump when it submits.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool busy;

  /// Full width (the default for primary CTAs) or intrinsic.
  final bool expand;

  /// 52 for page CTAs, 48 for dialog / inline pairs.
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.height = 52,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.height = 52,
  }) : variant = AppButtonVariant.primary;

  const AppButton.solid({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.height = 52,
  }) : variant = AppButtonVariant.solid;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.height = 52,
  }) : variant = AppButtonVariant.outline;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.height = 52,
  }) : variant = AppButtonVariant.danger;

  const AppButton.outlineDanger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.height = 52,
  }) : variant = AppButtonVariant.outlineDanger;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.height = 48,
  }) : variant = AppButtonVariant.text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final enabled = onPressed != null && !busy;
    final radius = height >= 52 ? AppTokens.lgRadius : AppTokens.mdRadius;

    final (Color fill, Color fg, BorderSide? side) = switch (variant) {
      AppButtonVariant.primary => (Colors.transparent, Colors.white, null),
      AppButtonVariant.solid => (t.primary, Colors.white, null),
      AppButtonVariant.outline => (t.surface, t.textPrimary, BorderSide(color: t.inputBorder)),
      AppButtonVariant.danger => (t.danger, Colors.white, null),
      AppButtonVariant.outlineDanger => (
          t.isDark ? t.dangerTint : t.neutralTint,
          t.dangerText,
          BorderSide(color: t.dangerBorder),
        ),
      AppButtonVariant.text => (Colors.transparent, t.primary, null),
    };

    final spinnerColor = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.solid || AppButtonVariant.danger => Colors.white,
      _ => fg,
    };

    final content = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor),
          )
        // A long label (Arabic runs longer) shrinks to fit a narrow button
        // in a bar rather than being cut to "Mor…".
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppTokens.space2),
                ],
                Text(label, maxLines: 1),
              ],
            ),
          );

    final gradient = variant == AppButtonVariant.primary && enabled;
    final disabledFill = variant == AppButtonVariant.text ? Colors.transparent : t.neutralTint;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : 64, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space5),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius)),
      side: side == null ? null : WidgetStatePropertyAll(side),
      textStyle: WidgetStatePropertyAll(
        (variant == AppButtonVariant.text ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !busy ? t.textTertiary : fg,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !busy ? disabledFill : fill,
      ),
      overlayColor: WidgetStatePropertyAll(
        (variant == AppButtonVariant.primary ||
                variant == AppButtonVariant.solid ||
                variant == AppButtonVariant.danger)
            ? Colors.white.withValues(alpha: 0.12)
            : fg.withValues(alpha: 0.08),
      ),
      // The gradient sits under the ink; a busy primary keeps it so the
      // button does not flash grey while submitting.
      backgroundBuilder: (gradient || (busy && variant == AppButtonVariant.primary))
          ? (context, states, child) => DecoratedBox(
                decoration: BoxDecoration(gradient: AppTokens.brandGradient, borderRadius: radius),
                child: child,
              )
          : null,
    );

    return TextButton(
      onPressed: enabled ? onPressed : (busy ? () {} : null),
      style: style,
      child: content,
    );
  }
}
