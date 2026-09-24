import 'package:flutter/material.dart';

import '../utils/theme/tokens.dart';

/// One option in an [AppFilterBar]. Selection state and the tap handler stay
/// with the screen's cubit — the bar only draws.
class AppFilterOption {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  const AppFilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
}

/// A horizontally scrolling row of Driver pills: white with a hairline at
/// rest, teal tint + teal text when selected. Height follows the text scale.
class AppFilterBar extends StatelessWidget {
  final List<AppFilterOption> options;
  final EdgeInsetsGeometry padding;

  const AppFilterBar({
    super.key,
    required this.options,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppTokens.gutter,
      AppTokens.space2,
      AppTokens.gutter,
      AppTokens.space2,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppTokens.space2),
            _FilterPill(option: options[i]),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final AppFilterOption option;

  const _FilterPill({required this.option});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final selected = option.selected;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? t.primaryTint : t.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? t.primary : t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: option.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected ? t.primary : t.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (option.count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${option.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected ? t.primary : t.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
