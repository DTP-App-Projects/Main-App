import 'package:flutter/material.dart';

import '../utils/theme/tokens.dart';

/// A sticky footer for a screen's primary action, so the CTA never scrolls
/// out of reach on a long form or document. Use as `Scaffold.bottomNavigationBar`.
class AppBottomBar extends StatelessWidget {
  final Widget child;

  /// Optional content above the action (a total, a validation hint).
  final Widget? leading;

  const AppBottomBar({super.key, required this.child, this.leading});

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
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.gutter,
            AppTokens.space3,
            AppTokens.gutter,
            AppTokens.space3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(height: AppTokens.space3),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
