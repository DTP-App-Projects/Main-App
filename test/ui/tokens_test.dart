import 'dart:math' as math;

import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/utils/theme/tokens.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design has rules (`DRIVER_DESIGN_SYSTEM.md`). They are asserted here,
/// because a rule nobody checks quietly stops being true the next time someone
/// edits the palette.
void main() {
  final trader = ThemeTokens.traderFallback;
  final supplier = ThemeTokens.supplierFallback;

  group('the brand is fixed, not server-driven', () {
    test('both workspaces get the same Driver palette', () {
      // Decision D1: the server palette only tints the role badge. A trader
      // and a supplier theme must be identical apart from that badge.
      for (final brightness in Brightness.values) {
        final a = buildAppTheme(trader, 'en', brightness: brightness);
        final b = buildAppTheme(supplier, 'en', brightness: brightness);
        expect(a.colorScheme.primary, b.colorScheme.primary);
        expect(a.scaffoldBackgroundColor, b.scaffoldBackgroundColor);
      }
    });

    test('primary is the Driver teal and never the server orange or blue', () {
      final theme = buildAppTheme(trader, 'en');
      expect(theme.colorScheme.primary, AppColors.brandTeal);
      expect(theme.colorScheme.primary, isNot(trader.primary));
      expect(theme.colorScheme.primary, isNot(supplier.primary));
    });

    test('the gradient runs blue → teal on the physical axis', () {
      expect(AppColors.brandGradient.colors, [AppColors.brandBlue, AppColors.brandTeal]);
      // Physical, not directional: it must not flip in RTL.
      expect(AppColors.brandGradient.begin, Alignment.centerLeft);
      expect(AppColors.brandGradient.end, Alignment.centerRight);
    });
  });

  group('status tones', () {
    test('good, warn and danger are separable by hue', () {
      for (final tokens in [AppTokens.light, AppTokens.dark]) {
        final hues = [StatusTone.good, StatusTone.warn, StatusTone.danger, StatusTone.inFlight]
            .map((tone) => HSLColor.fromColor(tokens.toneColor(tone)).hue)
            .toList();

        for (var i = 0; i < hues.length; i++) {
          for (var j = i + 1; j < hues.length; j++) {
            expect(_hueGap(hues[i], hues[j]), greaterThan(25),
                reason: 'tones $i and $j are too close to tell apart');
          }
        }
      }
    });

    test('an unrecognised status gets no mark rather than a guessed one', () {
      expect(AppTokens.light.markFor(StatusTone.unknown), isNull);
      expect(AppTokens.light.markFor(StatusTone.good), isNotNull);
    });
  });

  group('text holds AA contrast', () {
    for (final tokens in [AppTokens.light, AppTokens.dark]) {
      final name = tokens.isDark ? 'dark' : 'light';

      test('$name: ink and muted ink on the page and on cards', () {
        for (final ground in [tokens.background, tokens.surface]) {
          expect(_contrast(tokens.textPrimary, ground), greaterThan(4.5));
          expect(_contrast(tokens.textSecondary, ground), greaterThan(4.5));
          expect(_contrast(tokens.primary, ground), greaterThan(4.5));
          expect(_contrast(tokens.dangerText, ground), greaterThan(4.5));
          expect(_contrast(tokens.fieldError, ground), greaterThan(4.5));
        }
      });

      test('$name: every status pill reads on its own tint', () {
        for (final tone in StatusTone.values) {
          expect(
            _contrast(tokens.toneColor(tone), tokens.toneTint(tone)),
            greaterThan(4.5),
            reason: '${tone.name} pill',
          );
        }
      });
    }

    test('white text on the gradient stops and the solid CTA', () {
      expect(_contrast(Colors.white, AppColors.brandBlue), greaterThan(4.5));
      expect(_contrast(Colors.white, AppColors.brandTeal), greaterThan(4.5));
    });
  });

  group('the theme is wired to the tokens', () {
    test('both brightnesses carry the extension and the Driver page colour', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(trader, 'ar', brightness: brightness);
        final tokens = theme.extension<AppTokens>();

        expect(tokens, isNotNull, reason: 'context.tokens would fall back');
        expect(tokens!.isDark, brightness == Brightness.dark);
        expect(theme.scaffoldBackgroundColor, tokens.background);
        expect(theme.cardTheme.color, tokens.surface);
      }
    });

    test('dark mode keeps the hierarchy: page < card < sheet', () {
      final t = AppTokens.dark;
      expect(_luminance(t.surface), greaterThan(_luminance(t.background)));
      expect(_luminance(t.surfaceRaised), greaterThan(_luminance(t.surface)));
    });

    test('Arabic gets more leading than Latin, and no tracking', () {
      final arabic = buildAppTheme(trader, 'ar').textTheme.bodyMedium!;
      final latin = buildAppTheme(trader, 'en').textTheme.bodyMedium!;

      expect(arabic.height, greaterThan(latin.height!));
      expect(arabic.letterSpacing, 0);
    });

    test('every text role the app reaches for is actually defined', () {
      // Keep in step with:
      //     grep -rho 'textTheme\.[a-zA-Z]*' lib/ --include=*.dart | sort -u
      final text = buildAppTheme(trader, 'ar').textTheme;
      final roles = <String, TextStyle?>{
        'displaySmall': text.displaySmall,
        'headlineMedium': text.headlineMedium,
        'headlineSmall': text.headlineSmall,
        'titleLarge': text.titleLarge,
        'titleMedium': text.titleMedium,
        'titleSmall': text.titleSmall,
        'bodyLarge': text.bodyLarge,
        'bodyMedium': text.bodyMedium,
        'bodySmall': text.bodySmall,
        'labelLarge': text.labelLarge,
        'labelMedium': text.labelMedium,
        'labelSmall': text.labelSmall,
      };

      roles.forEach((name, style) {
        expect(style, isNotNull, reason: '$name is used in lib/ but undefined');
        expect(style!.fontFamily, 'IBMPlex', reason: name);
      });
    });
  });
}

/// The shortest distance between two hues on the wheel.
double _hueGap(double a, double b) {
  final gap = (a - b).abs() % 360;
  return gap > 180 ? 360 - gap : gap;
}

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}
