import 'package:flutter/material.dart';

import '../utils/assets/assets.dart';
import '../utils/colors/colors.dart';
import '../utils/theme/tokens.dart';

/// The title block of a tab root. The Driver app has no app bar there: a
/// large start-aligned title sits straight on the page, actions at the end.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Content under the title (a role badge, a filter bar).
  final Widget? bottom;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.gutter,
          AppTokens.space4,
          AppTokens.space4,
          AppTokens.space2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                for (final action in actions) ...[
                  const SizedBox(width: AppTokens.space2),
                  action,
                ],
              ],
            ),
            if (bottom != null) ...[
              const SizedBox(height: AppTokens.space3),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The Driver 48dp circular header button (bell, alert). [dot] draws the red
/// unread mark; [danger] is the tinted warning variant.
class AppCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool dot;
  final int? count;
  final bool danger;
  final double size;

  const AppCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.dot = false,
    this.count,
    this.danger = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fill = danger ? t.dangerTint : t.surface;
    final fg = danger ? t.danger : t.textPrimary;
    final showCount = count != null && count! > 0;

    final button = Material(
      color: fill,
      shape: CircleBorder(
        side: BorderSide(color: danger ? t.dangerBorder : t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: fg),
        ),
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: danger ? null : t.shadowSoft),
      child: button,
    );

    final withMark = Stack(
      clipBehavior: Clip.none,
      children: [
        decorated,
        if (showCount)
          PositionedDirectional(
            top: -2,
            end: -2,
            child: Badge(label: Text(count! > 99 ? '99+' : '$count')),
          )
        else if (dot)
          PositionedDirectional(
            top: size * 0.22,
            start: size * 0.28,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: t.danger,
                shape: BoxShape.circle,
                border: Border.all(color: fill, width: 1.5),
              ),
            ),
          ),
      ],
    );

    return tooltip == null ? withMark : Tooltip(message: tooltip!, child: withMark);
  }
}

/// The back affordance for pushed screens: a 40dp bordered circle holding a
/// chevron that points against the reading direction.
///
/// Wired into every `AppBar` through `ActionIconThemeData` in the theme, so
/// screens get it without touching their `AppBar`s.
class AppBackIcon extends StatelessWidget {
  const AppBackIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: t.surface,
        shape: BoxShape.circle,
        border: Border.all(color: t.border),
      ),
      alignment: Alignment.center,
      child: Icon(
        rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        size: 24,
        color: t.textPrimary,
      ),
    );
  }
}

/// The logo in the Driver gradient tile.
class AppLogoTile extends StatelessWidget {
  final double size;

  const AppLogoTile({super.key, this.size = 88});

  /// The asset already is the gradient tile; clipping to the tile radius
  /// trims the white corners baked into the PNG.
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          AssetData.logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(gradient: AppTokens.brandGradient),
            child: Icon(Icons.hub_outlined, color: Colors.white, size: size * 0.5),
          ),
        ),
      );
}

/// The full-bleed gradient header with rounded bottom corners (Driver profile).
class AppGradientHeader extends StatelessWidget {
  final Widget child;

  const AppGradientHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTokens.brandGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTokens.radiusSheet)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              AppTokens.space5,
              AppTokens.gutter,
              AppTokens.space6,
            ),
            child: child,
          ),
        ),
      );
}

/// A circular avatar showing an initial (Driver "b").
class AppInitialAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// White disc with teal letter (on gradient) or tinted disc (on cards).
  final bool onGradient;

  const AppInitialAvatar({super.key, required this.name, this.size = 44, this.onGradient = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onGradient ? Colors.white : t.primaryTint,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: onGradient ? AppColors.brandTeal : t.primary,
              fontSize: size * 0.4,
              height: 1,
            ),
      ),
    );
  }
}
