import 'package:digital_trade_portal/core/ui/ui.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/trade/purchase_order.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// The order's «سجل النشاط», from the timeline staging sent for PO 12: the
/// titles come as `title_ar`/`title_en`, the step as `ref`, and the note in
/// English only — none of it may reach an Arabic screen untranslated.
const _timeline = [
  {'at': '2026-09-27 16:30:31', 'type': 'order_created', 'title_ar': 'تم إنشاء أمر الشراء', 'title_en': 'Purchase order created', 'ref': 'PO-20260927-F522AFEB'},
  {'at': '2026-09-27 16:30:32', 'type': 'order_approval', 'title_ar': 'تم اعتماد الطلب', 'title_en': 'Order approved', 'status': 'approved', 'ref': 'credit_check', 'note': 'Credit module is disabled by platform admin.'},
  {'at': '2026-09-27 16:35:56', 'type': 'order_approval', 'title_ar': 'تم اعتماد الطلب', 'title_en': 'Order approved', 'status': 'approved', 'ref': 'supplier_review', 'note': 'Status changed to approved'},
  {'at': '2026-09-27 16:37:43', 'type': 'delivery_note_created', 'ref': 'DN-20260927-9B9FF1A0'},
  // Supplier side, from PO 4 on staging.
  {'at': '2026-09-28 10:00:00', 'type': 'order_cancel_decided', 'title_ar': 'قرار طلب الإلغاء', 'title_en': 'Cancel decision', 'status': 'accepted', 'ref': 'cancel_decision', 'note': 'Cancel request accepted'},
];

void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, String locale) async {
    final events = [for (final e in _timeline) TimelineEvent.fromJson(Map<String, dynamic>.from(e))];
    await tester.runAsync(() async {
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        path: 'lib/core/language',
        startLocale: Locale(locale),
        fallbackLocale: const Locale('ar'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: buildAppTheme(ThemeTokens.traderFallback, locale),
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: DocumentTimeline(events: events))),
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
  }

  testWidgets('Arabic: server titles, translated steps and notes', (tester) async {
    await pump(tester, 'ar');
    expect(find.text('تم إنشاء أمر الشراء'), findsOneWidget);
    expect(find.text('تم اعتماد الطلب'), findsNWidgets(2));
    // No title from the server: the event code is translated, not shown raw.
    expect(find.text('تم إنشاء إذن تسليم'), findsOneWidget);
    expect(find.text('فحص الائتمان'), findsOneWidget);
    expect(find.text('مراجعة المورد'), findsOneWidget);
    expect(find.text('وحدة الائتمان معطّلة من إدارة المنصة.'), findsOneWidget);
    expect(find.text('تغيّرت الحالة إلى «${'status.approved'.tr()}»'), findsOneWidget);
    expect(find.text('قرار الإلغاء'), findsOneWidget);
    expect(find.text('قُبل طلب الإلغاء.'), findsOneWidget);
    // Nothing English left over.
    for (final raw in ['order_created', 'Order approved', 'Status changed to approved', 'credit_check', 'Cancel request accepted']) {
      expect(find.text(raw), findsNothing, reason: raw);
    }
  });

  testWidgets('the credit check status is translated', (tester) async {
    await pump(tester, 'ar');
    expect(StatusChip.localize('passed'), 'اجتاز');
    expect(toneForStatus('passed'), StatusTone.good);
  });

  testWidgets('English: the English titles', (tester) async {
    await pump(tester, 'en');
    expect(find.text('Purchase order created'), findsOneWidget);
    expect(find.text('Credit check'), findsOneWidget);
  });
}
