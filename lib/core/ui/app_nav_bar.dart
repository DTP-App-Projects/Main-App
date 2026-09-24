import 'package:flutter/material.dart';

import '../utils/theme/tokens.dart';

class AppNavItem {
  final IconData icon;
  final String label;

  /// Unread count on the icon (0 hides it).
  final int badge;

  const AppNavItem({required this.icon, required this.label, this.badge = 0});
}

/// The Driver bottom navigation: a white bar, outline icons, and the active
/// destination's icon inside a gradient pill with a teal bold label.
class AppNavBar extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        boxShadow: t.shadowNav,
        border: t.isDark ? Border(top: BorderSide(color: t.border)) : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);

    Widget icon = Icon(item.icon, size: 26, color: selected ? Colors.white : t.navInactive);
    if (item.badge > 0) {
      icon = Badge(
        label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
        child: icon,
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        highlightShape: BoxShape.rectangle,
        containedInkWell: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 64,
              height: 36,
              decoration: BoxDecoration(
                gradient: selected ? AppTokens.brandGradient : null,
                borderRadius: AppTokens.fullRadius,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? t.primary : t.navInactive,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
