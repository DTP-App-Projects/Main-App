import 'package:flutter/widgets.dart';

/// The shell's bottom tabs. Each workspace shows its own subset, in its own
/// order: the trader has the shop where the supplier has notifications.
enum ShellTab { home, trade, notifications, shop, more }

/// Lets a tab root move the shell to another tab (Home's "See all" opens the
/// Trade hub) without the feature importing the shell.
class ShellScope extends InheritedWidget {
  final ShellTab current;
  final List<ShellTab> tabs;
  final ValueChanged<ShellTab> select;

  const ShellScope({
    super.key,
    required this.current,
    required this.tabs,
    required this.select,
    required super.child,
  });

  /// `null` outside a shell (a screen pushed as its own route).
  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  bool has(ShellTab tab) => tabs.contains(tab);

  @override
  bool updateShouldNotify(ShellScope oldWidget) => current != oldWidget.current;
}
