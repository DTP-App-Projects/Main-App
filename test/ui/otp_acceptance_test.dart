import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/core/ui/ui.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:digital_trade_portal/features/shared/compliance/otp_acceptance_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// The level-2 sheet: the challenge goes out, the legal sentence sits above
/// the confirm button, and a server rejection stays on the sheet.
void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, Widget panel, {String locale = 'ar'}) async {
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
            home: Scaffold(body: SingleChildScrollView(child: panel)),
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    // Localization resolves first; only then does the panel build and send
    // its challenge, which needs a second real-async turn to come back.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    }
    await tester.pump();
  }

  ComplianceRepository repoAnswering(Map<String, dynamic> challenge) =>
      ComplianceRepository(clientWith(FakeAdapter.json(challenge, status: 201)).$1);

  testWidgets('requests a challenge and shows the legal sentence above confirm', (tester) async {
    final (client, adapter) = clientWith(FakeAdapter.json(const {
      'challenge_id': 4,
      'channel': 'sms',
      'destination': '05•••••12',
      'expires_at': '2026-10-05 14:10:00',
    }));
    await pump(
      tester,
      OtpAcceptancePanel(
        documentType: 'quotation',
        documentId: 77,
        repository: ComplianceRepository(client),
        submit: (_) async => const NoContent(),
      ),
    );

    expect(adapter.requests.single.data, {'document_type': 'quotation', 'document_id': 77});
    // On the sheet, and in the «أرسلنا الرمز إلى …» toast.
    expect(find.textContaining('05•••••12'), findsWidgets);

    final legal = find.byKey(const Key('otp_legal_sentence'));
    expect(tester.widget<Text>(legal).data, 'تأكيد برمز تحقق — قبول ملزم');
    // Never the forbidden labels.
    expect(find.textContaining('توقيع إلكتروني معتمد'), findsNothing);
    expect(find.textContaining('مصدّق'), findsNothing);

    final confirm = find.text('acceptance.confirm'.tr());
    expect(tester.getTopLeft(legal).dy, lessThan(tester.getTopLeft(confirm).dy));
  });

  testWidgets('posts the typed code and shows a 422 rejection in place', (tester) async {
    String? sent;
    await pump(
      tester,
      OtpAcceptancePanel(
        documentType: 'purchase_order',
        documentId: 5,
        repository: repoAnswering(const {'challenge_id': 1, 'destination': 'a•••@x.com'}),
        submit: (code) async {
          sent = code;
          return const Failed<Object?>('authorized_signatory_required', 422,
              message: 'هذا الإجراء للمفوَّض بالتوقيع فقط');
        },
      ),
    );

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('acceptance.confirm'.tr()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();

    expect(sent, '123456');
    expect(find.text('هذا الإجراء للمفوَّض بالتوقيع فقط'), findsOneWidget);
  });

  testWidgets('resend is held back by the cooldown', (tester) async {
    await pump(
      tester,
      OtpAcceptancePanel(
        documentType: 'goods_receipt',
        documentId: 2,
        repository: repoAnswering(const {'challenge_id': 1}),
        submit: (_) async => const NoContent(),
      ),
    );
    expect(find.textContaining('60'), findsOneWidget, reason: 'one new code a minute');
    // Let the periodic timer end so the test does not leak it.
    await tester.pump(const Duration(seconds: 61));
  });

  SubmitButton confirmButton(WidgetTester tester) => tester.widget<SubmitButton>(find.byType(SubmitButton));

  testWidgets('confirm stays off until six digits are typed', (tester) async {
    await pump(
      tester,
      OtpAcceptancePanel(
        documentType: 'relationship_request',
        documentId: 6,
        repository: repoAnswering(const {'challenge_id': 1, 'destination': 'a•••@x.com'}),
        submit: (_) async => const NoContent(),
      ),
    );

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('a wrong code clears the field; an expired one asks for a new code at once', (tester) async {
    var answer = 'otp_invalid';
    await pump(
      tester,
      OtpAcceptancePanel(
        documentType: 'relationship_request',
        documentId: 6,
        repository: repoAnswering(const {'challenge_id': 1, 'destination': 'a•••@x.com'}),
        submit: (_) async => Failed<Object?>(answer, 422, message: 'رسالة الخادم'),
      ),
    );

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    await tester.tap(find.byType(SubmitButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('رسالة الخادم'), findsOneWidget);

    answer = 'otp_expired';
    await tester.enterText(find.byType(TextField), '222222');
    await tester.pump();
    await tester.tap(find.byType(SubmitButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    // The resend button is enabled straight away (no countdown text).
    expect(find.text('acceptance.resend'.tr()), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('not the signatory: the message stays and the inputs go', (tester) async {
    await pump(
      tester,
      OtpAcceptancePanel(
        documentType: 'relationship_request',
        documentId: 6,
        repository: repoAnswering(const {'challenge_id': 1, 'destination': 'a•••@x.com'}),
        submit: (_) async => const Failed<Object?>('signatory_required', 422,
            message: 'هذا الإجراء للمفوّض بالتوقيع عن المنشأة فقط'),
      ),
    );

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.byType(SubmitButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();

    expect(find.text('هذا الإجراء للمفوّض بالتوقيع عن المنشأة فقط'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(confirmButton(tester).onPressed, isNull);
    await tester.pump(const Duration(seconds: 61));
  });
}
