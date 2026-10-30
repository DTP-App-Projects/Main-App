import 'dart:convert';
import 'dart:io';

import 'package:digital_trade_portal/core/ui/ui.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/trade/purchase_order.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Guards for the final QA pass (UI_REDESIGN_PLAN.md §7): backend status
/// coverage, timeline order, and confirmation semantics.
void main() {
  /// Every status value the backend documents (API reference, Postman
  /// collection, event catalogue) for a workflow the UI renders.
  const documented = {
    // purchase orders + approvals
    'submitted', 'under_review', 'approved', 'ready', 'rejected', 'canceled',
    'cancel_requested', 'pending',
    // delivery notes, goods receipts
    'created', 'dispatched', 'delivered', 'draft', 'confirmed', 'disputed',
    // invoices, collections, adjustments
    'issued', 'paid', 'overdue',
    // contracts, relationships, organizations, SKUs
    'active', 'suspended', 'expired', 'terminated', 'none', 'pending_review',
    'blacklisted', 'closed', 'blocked',
    // settlements, payouts, consignment, shelf documents
    'calculated', 'reviewed', 'completed', 'failed', 'sent', 'received', 'verified',
    // shop (v1) orders
    'processing', 'declined',
    // ops attention severities
    'ok', 'info', 'warn', 'danger',
    // van trips, delivery contracts, internal transfers (supplier fleet brief,
    // 2026-10-27)
    'on_road', 'returning', 'reconciled', 'ended', 'in_transit',
  };

  Map<String, dynamic> statusKeys(String lang) =>
      (jsonDecode(File('lib/core/language/$lang.json').readAsStringSync())
          as Map<String, dynamic>)['status'] as Map<String, dynamic>;

  group('backend status values', () {
    test('every documented status is translated in Arabic and English', () {
      for (final lang in ['en', 'ar']) {
        final keys = statusKeys(lang);
        final missing = documented.where((s) => !keys.containsKey(s)).toList();
        expect(missing, isEmpty, reason: '$lang is missing status.$missing');
      }
    });

    test('guessed values from the redesign are not mapped (no invented statuses)', () {
      // `cancelled` left this list with the compliance release, which
      // documents it (`PATCH quotations/{id}/status {status: cancelled}`).
      // `passed` too: it is the `credit_check_status` of every order on
      // staging (2026-10-05), so it is observed, not guessed. `in_transit`
      // is documented by the fleet brief (2026-10-27): an internal transfer
      // goes `approved` → `in_transit` → `received`.
      const guessed = ['success', 'warning', 'unpaid'];
      for (final lang in ['en', 'ar']) {
        final keys = statusKeys(lang);
        expect(guessed.where(keys.containsKey), isEmpty, reason: lang);
      }
      for (final value in guessed) {
        expect(toneForStatus(value), StatusTone.unknown, reason: value);
      }
    });

    test('documented outcomes carry the right tone', () {
      for (final s in ['approved', 'delivered', 'paid', 'confirmed', 'active', 'completed']) {
        expect(toneForStatus(s), StatusTone.good, reason: s);
      }
      for (final s in ['rejected', 'canceled', 'declined', 'failed', 'terminated', 'blacklisted']) {
        expect(toneForStatus(s), StatusTone.danger, reason: s);
      }
      for (final s in ['overdue', 'disputed', 'cancel_requested']) {
        expect(toneForStatus(s), StatusTone.warn, reason: s);
      }
      for (final s in ['submitted', 'under_review', 'pending', 'dispatched', 'issued']) {
        expect(toneForStatus(s), StatusTone.inFlight, reason: s);
      }
    });
  });

  group('timeline', () {
    TimelineEvent at(String event, DateTime? when) => TimelineEvent(
          event: event,
          title: event,
          description: '',
          status: '',
          actorName: '',
          at: when,
        );

    test('orders newest first whatever order the server sent', () {
      final sorted = DocumentTimeline.newestFirst([
        at('created', DateTime(2026, 9, 1)),
        at('undated', null),
        at('approved', DateTime(2026, 9, 3)),
        at('submitted', DateTime(2026, 9, 2)),
      ]);
      expect(sorted.map((e) => e.event), ['approved', 'submitted', 'created', 'undated']);
    });

    test('ties keep the server order', () {
      final same = DateTime(2026, 9, 1);
      final sorted = DocumentTimeline.newestFirst([at('a', same), at('b', same)]);
      expect(sorted.map((e) => e.event), ['a', 'b']);
    });
  });

  group('confirmations never fire on dismiss', () {
    setUpAll(() async {
      await useFakeStorage();
      await EasyLocalization.ensureInitialized();
    });

    Future<BuildContext> host(WidgetTester tester) async {
      late BuildContext captured;
      await tester.runAsync(() async {
        await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ar'), Locale('en')],
          path: 'lib/core/language',
          startLocale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: buildAppTheme(ThemeTokens.traderFallback, 'en'),
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: Builder(builder: (context) {
                captured = context;
                return const Scaffold(body: SizedBox.expand());
              }),
            ),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('showAppConfirm: barrier tap and Cancel resolve false', (tester) async {
      final context = await host(tester);

      var result = showAppConfirm(context, title: 'Delete?', destructive: true);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();
      expect(await result, isFalse);

      result = showAppConfirm(context, title: 'Delete?', destructive: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();
      expect(await result, isFalse);

      result = showAppConfirm(context, title: 'Delete?', confirmLabel: 'Yes', destructive: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('showAppReasonDialog: required and minLength block confirm', (tester) async {
      final context = await host(tester);

      final result = showAppReasonDialog(
        context,
        title: 'Reject',
        confirmLabel: 'Send',
        required: true,
        minLength: 3,
        lengthRule: 'At least 3',
      );
      await tester.pumpAndSettle();

      // Empty: confirm disabled, tapping it does nothing.
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Send'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'no');
      await tester.pumpAndSettle();
      expect(find.text('At least 3'), findsOneWidget);
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Send'), findsOneWidget, reason: 'still below the minimum');

      await tester.enterText(find.byType(TextField), '  wrong item  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(await result, 'wrong item');
    });

    testWidgets('showAppReasonDialog: cancel resolves null', (tester) async {
      final context = await host(tester);
      final result = showAppReasonDialog(context, title: 'Reject', required: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('showAppSheet: dismissing resolves null (mark-delivered guard)', (tester) async {
      final context = await host(tester);
      final result = showAppSheet<bool>(
        context: context,
        title: 'Mark delivered',
        builder: (sheet) => AppButton.solid(
          label: 'Continue',
          onPressed: () => Navigator.of(sheet).pop(true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // the scrim
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });
}
