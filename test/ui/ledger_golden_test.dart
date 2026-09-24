
import 'package:easy_localization/easy_localization.dart';

import 'package:digital_trade_portal/core/ui/document_widgets.dart';
import 'package:digital_trade_portal/core/ui/value_widgets.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/utils/theme/tokens.dart';
import 'package:digital_trade_portal/core/utils/theme/typography.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the design so it can be looked at:
///
///     flutter test test/ui/ledger_golden_test.dart --dart-define=GOLDENS=true --update-goldens
///
/// The images are a design artefact, not a regression lock. Font rasterisation
/// differs between machines and platforms, so left ungated these would fail on
/// anyone else's checkout for reasons that have nothing to do with the code —
/// which is how a suite learns to be ignored. Off by default, on when someone
/// actually wants to look.
const _goldens = bool.fromEnvironment('GOLDENS');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // MoneyText formats against the active locale, so the harness needs the
    // real localization ancestor rather than a stand-in.
    await EasyLocalization.ensureInitialized();

    // Without this the test font renders every glyph as a filled box, which
    // makes a typographic review impossible.
    final loader = FontLoader('IBMPlex');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'),
      );
    }
    await loader.load();
  });

  Widget frame(ThemeTokens palette, Brightness brightness, String locale) {
    final theme = buildAppTheme(palette, locale, brightness: brightness);
    return EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'lib/core/language',
      startLocale: Locale(locale),
      fallbackLocale: const Locale('en'),
      child: Builder(
        builder: (context) => MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: _LedgerSample(locale: locale),
        ),
      ),
    );
  }

  for (final (name, palette) in [
    ('trader', ThemeTokens.traderFallback),
    ('supplier', ThemeTokens.supplierFallback),
  ]) {
    for (final locale in ['ar', 'en']) {
      for (final brightness in Brightness.values) {
        // `testWidgets` takes a bool here, so the reason lives in the doc
        // comment above rather than in the skip message.
        testWidgets('$name $locale ${brightness.name}', skip: !_goldens,
            (tester) async {
          tester.view
            ..physicalSize = const Size(390 * 2, 780 * 2)
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          // EasyLocalization reads its translations off the real asset
          // bundle, which is I/O — fake-async never lets that future
          // complete, so the tree renders its empty placeholder forever.
          await tester.runAsync(() async {
            await tester.pumpWidget(frame(palette, brightness, locale));
            await Future<void>.delayed(const Duration(milliseconds: 60));
          });
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name-$locale-${brightness.name}.png'),
          );
        });
      }
    }
  }
}

/// A page of the app as it actually appears: an app bar, a figure that has to
/// carry the screen, a run of ledger rows, and a detail table.
class _LedgerSample extends StatelessWidget {
  final String locale;

  const _LedgerSample({required this.locale});

  bool get _ar => locale == 'ar';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final rows = <(String, String, String, String, double)>[
      ('20419', _ar ? 'مؤسسة الفيصل التجارية' : 'Al-Faisal Trading Co.',
          _ar ? '٣ أصناف · تستحق ١٢ أكتوبر' : '3 lines · due 12 Oct', 'under_review', 12480),
      ('20418', _ar ? 'دار الرياض للتوريد' : 'Riyadh Supply House',
          _ar ? '٨ أصناف · تستحق ١٩ أكتوبر' : '8 lines · due 19 Oct', 'approved', 4902.5),
      ('20417', _ar ? 'شركة نجد للجملة' : 'Najd Wholesale Ltd.',
          _ar ? '١٢ صنفًا · متأخرة ٤ أيام' : '12 lines · 4 days overdue', 'overdue', 31150),
      ('20416', _ar ? 'مخازن جدة' : 'Jeddah Stores',
          _ar ? '٢ صنفان · تم التسليم' : '2 lines · delivered', 'delivered', 890),
      ('20415', _ar ? 'مجموعة تبوك' : 'Tabuk Group',
          _ar ? '٦ أصناف · مرفوضة' : '6 lines · rejected', 'rejected', 7420),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_ar ? 'أوامر الشراء' : 'Purchase orders'),
        actions: const [Icon(Icons.filter_list_rounded), SizedBox(width: 16)],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // The figure that carries the screen. No gradient, no card, no trio
          // of supporting stats — it is a balance, so it is set as one.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ar ? 'المستحق هذا الشهر' : 'Payable this month',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                MoneyText(56842.5, style: AppType.ledgerLarge(tokens.ink)),
              ],
            ),
          ),
          Container(height: 1, color: tokens.rule),
          for (final (code, title, subtitle, status, amount) in rows)
            DocumentTile(
              code: 'PO-$code',
              title: title,
              subtitle: subtitle,
              status: status,
              amount: amount,
              icon: Icons.receipt_long_outlined,
              onTap: () {},
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              _ar ? 'تفاصيل التسوية' : 'Settlement detail',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                DetailRow(
                  label: _ar ? 'الإجمالي قبل الضريبة' : 'Subtotal',
                  value: MoneyText(49428.26),
                ),
                DetailRow(
                  label: _ar ? 'ضريبة القيمة المضافة' : 'VAT',
                  value: MoneyText(7414.24),
                ),
                DetailRow(
                  label: _ar ? 'الإجمالي' : 'Total',
                  value: MoneyText(56842.5, style: AppType.ledger(tokens.ink, size: 19)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                labelText: _ar ? 'رقم المرجع' : 'Reference number',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: FilledButton(
              onPressed: () {},
              child: Text(_ar ? 'تسجيل السداد' : 'Record payment'),
            ),
          ),
        ],
      ),
    );
  }
}

