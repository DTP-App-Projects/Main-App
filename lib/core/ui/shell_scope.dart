import 'package:flutter/widgets.dart';

/// The shell's bottom tabs, in order.
enum ShellTab { home, trade, notifications, more }

/// Lets a tab root move the shell to another tab (Home's "See all" opens the
/// Trade hub) without the feature importing the shell.
class ShellScope extends InheritedWidget {
  final ShellTab current;
  final ValueChanged<ShellTab> select;

  const ShellScope({
    super.key,
    required this.current,
    required this.select,
    required super.child,
  });

  /// `null` outside a shell (a screen pushed as its own route).
  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => current != oldWidget.current;
}
