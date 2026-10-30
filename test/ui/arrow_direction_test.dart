import 'package:digital_trade_portal/core/ui/ui.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chevrons are `matchTextDirection` icons: Flutter mirrors them in RTL.
/// The widgets must pick one icon and let Flutter flip it exactly once —
/// choosing by direction as well flipped every arrow back the wrong way.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, TextDirection direction) => tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(ThemeTokens.traderFallback, direction == TextDirection.rtl ? 'ar' : 'en'),
          home: Directionality(textDirection: direction, child: Scaffold(body: Center(child: child))),
        ),
      );

  bool mirrored(WidgetTester tester) =>
      find.descendant(of: find.byType(Icon), matching: find.byType(Transform)).evaluate().isNotEmpty;

  for (final (name, widget, icon) in [
    ('forward chevron', const DirectionalChevron(), Icons.chevron_right_rounded),
    ('back button', const AppBackIcon(), Icons.chevron_left_rounded),
  ]) {
    testWidgets('$name: one icon, mirrored only in RTL', (tester) async {
      await pump(tester, widget, TextDirection.ltr);
      expect(tester.widget<Icon>(find.byType(Icon)).icon, icon);
      expect(mirrored(tester), isFalse);

      await pump(tester, widget, TextDirection.rtl);
      expect(tester.widget<Icon>(find.byType(Icon)).icon, icon);
      expect(mirrored(tester), isTrue, reason: 'Flutter flips it once in Arabic');
    });
  }
}
