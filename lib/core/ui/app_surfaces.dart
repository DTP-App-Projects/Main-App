import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/theme/tokens.dart';
import '../workspace/workspace.dart';
import '../workspace/workspace_cubit.dart';
import 'value_widgets.dart';

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// A white island on the grey page.
///
/// * [AppCard.section] — r20, holds grouped rows (Driver settings menu).
/// * [AppCard.item] — r16, a record in a list (Driver route card).
/// * [AppCard.new] — r20 with padding, a form or a summary.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius radius;
  final VoidCallback? onTap;
  final bool shadow;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(AppTokens.cardPadding),
    this.margin = EdgeInsetsDirectional.zero,
    this.radius = AppTokens.xlRadius,
    this.onTap,
    this.shadow = false,
    this.color,
    this.borderColor,
  });

  const AppCard.section({
    super.key,
    required this.child,
    this.padding = EdgeInsetsDirectional.zero,
    this.margin = EdgeInsetsDirectional.zero,
    this.onTap,
    this.shadow = false,
    this.color,
    this.borderColor,
  }) : radius = AppTokens.xlRadius;

  const AppCard.item({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(AppTokens.space4),
    this.margin = const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
    this.onTap,
    this.shadow = false,
    this.color,
    this.borderColor,
  }) : radius = AppTokens.lgRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = Padding(padding: padding, child: child);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? t.surface,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? t.border, width: AppTokens.ruleWidth),
          boxShadow: shadow ? t.shadowSoft : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: onTap == null ? body : InkWell(onTap: onTap, borderRadius: radius, child: body),
        ),
      ),
    );
  }
}

/// A card with a header row (icon · title · trailing) over a divider, then
/// its body — the Driver "Today's route" card.
class AppHeaderCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry bodyPadding;
  final Color? iconColor;

  const AppHeaderCard({
    super.key,
    this.icon,
    required this.title,
    this.trailing,
    required this.child,
    this.bodyPadding = const EdgeInsetsDirectional.all(AppTokens.space4),
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard.section(
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.space5,
              AppTokens.space4,
              AppTokens.space4,
              AppTokens.space4,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24, color: iconColor ?? t.primary),
                  const SizedBox(width: AppTokens.space3),
                ],
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(height: 1, color: t.divider),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon circles, labels, rows
// ---------------------------------------------------------------------------

enum AppTone { brand, neutral, info, warning, danger }

extension _ToneColors on AppTokens {
  (Color fg, Color bg) forTone(AppTone tone) => switch (tone) {
        AppTone.brand => (primary, primaryTint),
        AppTone.neutral => (textSecondary, neutralTint),
        AppTone.info => (info, infoTint),
        AppTone.warning => (warningText, warningTint),
        AppTone.danger => (danger, dangerTint),
      };
}

/// The Driver tinted icon disc.
class AppIconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final double? iconSize;
  final AppTone tone;

  const AppIconCircle(
    this.icon, {
    super.key,
    this.size = 44,
    this.iconSize,
    this.tone = AppTone.brand,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.tokens.forTone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize ?? size * 0.5, color: fg),
    );
  }
}

/// A section label above a card (Driver "الحساب").
class AppSectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppSectionLabel(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppTokens.space1,
      AppTokens.sectionGap,
      AppTokens.space1,
      AppTokens.space3,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: context.tokens.textSecondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rows grouped in one section card, with inset dividers between them.
class AppMenuGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const AppMenuGroup({
    super.key,
    required this.children,
    this.margin = EdgeInsetsDirectional.zero,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        // Starts under the title, not under the icon column (Driver S3).
        rows.add(Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppTokens.space5 + 44 + AppTokens.space4,
            end: AppTokens.space5,
          ),
          child: Divider(height: 1, color: t.divider),
        ));
      }
    }
    return AppCard.section(
      margin: margin,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// The Driver menu row: tinted icon disc, title, optional value, chevron.
class AppMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// A current value shown before the chevron ("العربية").
  final String? value;

  /// Replaces [value] — a count badge, a switch.
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppTone tone;
  final bool showChevron;

  const AppMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.tone = AppTone.brand,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final danger = tone == AppTone.danger;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTokens.rowHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppTokens.space5,
            vertical: AppTokens.space3,
          ),
          child: Row(
            children: [
              AppIconCircle(icon, tone: tone),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: danger ? t.dangerText : null,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTokens.space2),
                trailing!,
              ] else if (value != null) ...[
                const SizedBox(width: AppTokens.space2),
                Text(value!, style: theme.textTheme.bodySmall),
              ],
              if (showChevron && onTap != null && !danger) ...[
                const SizedBox(width: AppTokens.space2),
                DirectionalChevron(size: 20, color: t.iconMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Figures and badges
// ---------------------------------------------------------------------------

/// The Driver stat tile: label above, a big semantic figure below.
class AppStatTile extends StatelessWidget {
  final String label;

  /// Either a plain string or a widget (e.g. a `MoneyText`).
  final String? value;
  final Widget? valueWidget;
  final AppTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppStatTile({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.tone = AppTone.brand,
    this.icon,
    this.onTap,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final (fg, _) = t.forTone(tone);
    final color = tone == AppTone.neutral ? t.textPrimary : fg;

    return AppCard(
      radius: AppTokens.lgRadius,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppTokens.space3,
        vertical: AppTokens.space4,
      ),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: t.iconMuted),
                const SizedBox(width: AppTokens.space1),
              ],
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: DefaultTextStyle.merge(
              style: theme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              child: valueWidget ?? Text(value!),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tinted pill (Driver "متأخر" / count "1").
class AppBadge extends StatelessWidget {
  final String label;
  final AppTone tone;
  final IconData? icon;

  const AppBadge(this.label, {super.key, this.tone = AppTone.brand, this.icon});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = context.tokens.forTone(tone);
    final color = tone == AppTone.danger ? context.tokens.dangerText : fg;
    return _Pill(label: label, fg: color, bg: bg, icon: icon);
  }
}

/// A count in a teal pill (Driver "خط سير اليوم  1").
class AppCountBadge extends StatelessWidget {
  final int count;

  const AppCountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Pill(
      label: count > 99 ? '99+' : '$count',
      fg: t.primary,
      bg: t.primaryTintSoft,
      bold: true,
      minWidth: 36,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;
  final bool bold;
  final double minWidth;

  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.bold = false,
    this.minWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: 26, minWidth: minWidth),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppTokens.fullRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which side of the trade the user is acting as.
///
/// This is the only place the server's per-workspace colour survives
/// (decision D1): a subtle accent on an otherwise Driver-styled pill.
class RoleBadge extends StatelessWidget {
  /// Defaults to the active workspace.
  final Workspace? workspace;

  /// The translucent white variant for gradient surfaces.
  final bool onGradient;

  const RoleBadge({super.key, this.workspace, this.onGradient = false});

  static IconData iconFor(Workspace workspace) => workspace == Workspace.trader
      ? Icons.storefront_outlined
      : Icons.local_shipping_outlined;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceCubit>().state;
    final ws = workspace ?? state?.active ?? Workspace.trader;
    final palette = (workspace == null || workspace == state?.active)
        ? (state?.theme ?? ThemeTokens.fallbackFor(ws))
        : ThemeTokens.fallbackFor(ws);
    final label = 'workspace.${ws.name}'.tr();
    final t = context.tokens;
    final theme = Theme.of(context);

    final Color fg;
    final Color bg;
    final Color? border;
    if (onGradient) {
      fg = Colors.white;
      bg = Colors.white.withValues(alpha: 0.18);
      border = Colors.white.withValues(alpha: 0.35);
    } else {
      fg = _readableAccent(palette.primary, t);
      bg = Color.alphaBlend(palette.primary.withValues(alpha: t.isDark ? 0.22 : 0.12), t.surface);
      border = null;
    }

    return Semantics(
      label: 'workspace.acting_as'.tr(namedArgs: {'workspace': label}),
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppTokens.fullRadius,
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(ws), size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// The server colour, darkened (light) or lightened (dark) until it holds
  /// AA contrast as small text on its own tint.
  static Color _readableAccent(Color accent, AppTokens t) {
    var hsl = HSLColor.fromColor(accent);
    final bg = Color.alphaBlend(accent.withValues(alpha: t.isDark ? 0.22 : 0.12), t.surface);
    for (var i = 0; i < 12; i++) {
      final color = hsl.toColor();
      if (_contrast(color, bg) >= 4.5) return color;
      final l = t.isDark ? (hsl.lightness + 0.05).clamp(0.0, 1.0) : (hsl.lightness - 0.05).clamp(0.0, 1.0);
      hsl = hsl.withLightness(l);
    }
    return t.isDark ? t.textPrimary : t.textPrimary;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

/// A rounded, tinted message block with an icon — info, success, warning or
/// danger. Replaces the ad-hoc `Card(color: errorContainer)` banners.
class AppBanner extends StatelessWidget {
  final String message;
  final String? title;
  final AppTone tone;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry margin;

  const AppBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = AppTone.info,
    this.icon,
    this.action,
    this.margin = const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
  });

  static IconData defaultIcon(AppTone tone) => switch (tone) {
        AppTone.brand => Icons.check_circle_outline_rounded,
        AppTone.neutral || AppTone.info => Icons.info_outline_rounded,
        AppTone.warning => Icons.warning_amber_rounded,
        AppTone.danger => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final (fg, bg) = t.forTone(tone);
    final text = tone == AppTone.danger ? t.dangerText : fg;

    return Container(
      margin: margin,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.space4,
        AppTokens.space3,
        AppTokens.space4,
        AppTokens.space3,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppTokens.mdRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: Icon(icon ?? defaultIcon(tone), size: 20, color: fg),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: text)),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: title == null ? text : t.textSecondary,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppTokens.space2),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
