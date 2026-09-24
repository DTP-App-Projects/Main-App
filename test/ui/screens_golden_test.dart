import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:digital_trade_portal/app/shell/workspace_shell.dart';
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/ui/app_nav_bar.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/notifications_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';
import 'golden_support.dart';

/// Renders whole redesigned screens — the real shell, real cubits, a fake
/// backend — so the Driver redesign can be reviewed in both languages and
/// both brightnesses:
///
///     flutter test test/ui/screens_golden_test.dart --dart-define=GOLDENS=true --update-goldens
///
/// A design artefact, not a regression lock (see `ledger_golden_test.dart`).
const _goldens = bool.fromEnvironment('GOLDENS');

const _panel = {
  'workspace': 'trader',
  'kpis': [
    {'key': 'open_orders', 'label_ar': 'طلبات مفتوحة', 'label_en': 'Open orders', 'value': '12', 'severity': 'ok'},
    {'key': 'in_transit', 'label_ar': 'شحنات في الطريق', 'label_en': 'In transit', 'value': '4', 'severity': 'info'},
    {'key': 'due_soon', 'label_ar': 'مستحقة قريباً', 'label_en': 'Due this week', 'value': '3', 'severity': 'warn'},
    {'key': 'overdue', 'label_ar': 'متأخرة', 'label_en': 'Overdue', 'value': '1', 'severity': 'danger'},
  ],
  'attention': [
    {
      'key': 'overdue_invoice',
      'title_ar': 'فاتورة متأخرة INV-3021',
      'title_en': 'Invoice INV-3021 is overdue',
      'body_ar': 'مستحقة منذ ٤ أيام لدى دار الرياض للتوريد',
      'body_en': 'Due 4 days ago to Riyadh Supply House',
      'severity': 'overdue',
    },
    {
      'key': 'receipt_pending',
      'title_ar': 'شحنة بانتظار الاستلام',
      'title_en': 'A shipment is waiting for receipt',
      'body_ar': 'DN-1180 وصلت إلى فرع العليا',
      'body_en': 'DN-1180 arrived at the Olaya branch',
      'severity': 'arrived',
    },
  ],
  'quick_actions': [
    {'key': 'create_purchase_draft', 'label_ar': 'طلب شراء جديد', 'label_en': 'New purchase order'},
    {'key': 'confirm_goods_receipt', 'label_ar': 'تأكيد الاستلام', 'label_en': 'Confirm receipt'},
    {'key': 'claim_payment', 'label_ar': 'إثبات دفعة', 'label_en': 'Claim a payment'},
    {'key': 'approve_purchase_order', 'label_ar': 'اعتماد الطلبات', 'label_en': 'Approve orders'},
  ],
  'document_groups': [
    {'key': 'purchase_orders', 'label_ar': 'أوامر الشراء', 'label_en': 'Purchase orders', 'count': 12},
    {'key': 'delivery_notes', 'label_ar': 'إشعارات التسليم', 'label_en': 'Delivery notes', 'count': 4},
    {'key': 'invoices', 'label_ar': 'الفواتير', 'label_en': 'Invoices', 'count': 0},
  ],
};

const _notifications = {
  'current_page': 1,
  'last_page': 1,
  'per_page': 20,
  'total': 3,
  'unread_count': 2,
  'data': [
    {
      'id': 1,
      'text_ar': 'تم اعتماد طلب الشراء PO-20418',
      'text_en': 'Purchase order PO-20418 was approved',
      'click_action': 'purchase_order',
      'is_read': false,
      'created_at': '2026-09-24 09:15:00',
    },
    {
      'id': 2,
      'text_ar': 'الشحنة DN-1180 في الطريق',
      'text_en': 'Shipment DN-1180 is on its way',
      'click_action': 'delivery_note',
      'is_read': false,
      'created_at': '2026-09-24 08:02:00',
    },
    {
      'id': 3,
      'text_ar': 'صدرت فاتورة جديدة INV-3021',
      'text_en': 'New invoice INV-3021 issued',
      'click_action': 'invoice',
      'is_read': true,
      'created_at': '2026-09-20 16:40:00',
    },
  ],
};

FakeAdapter _backend() => FakeAdapter((options) async {
      final path = options.path;
      final Object body = path.contains('ops/panel')
          ? {..._panel, 'workspace': options.queryParameters['workspace'] ?? 'trader'}
          : path.contains('notifications')
              ? _notifications
              : const {'theme': {}, 'quick_actions': []};
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    });

void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();
    await loadGoldenFonts();
  });

  Future<Widget> app({
    required String locale,
    required Brightness brightness,
    required Workspace workspace,
  }) async {
    final (client, _) = clientWith(_backend());
    final store = SessionStore();
    final ops = OpsRepository(client);
    final bootstrap = BootstrapRepository(client);
    final workspaceCubit = WorkspaceCubit(store, ops);
    final session = SessionCubit(
      store,
      bootstrap,
      workspaceCubit,
      PushService(AuthRepository(client), bootstrap, store),
    );
    final notifications = NotificationsCubit(NotificationsRepository(client));

    await getIt.reset();
    getIt
      ..registerSingleton<OpsRepository>(ops)
      ..registerSingleton<WorkspaceCubit>(workspaceCubit);

    await workspaceCubit.hydrate(Organization.fromJson(const {
      'id': 3,
      'display_name': 'مؤسسة الفيصل التجارية',
      'business_mode': 'hybrid',
      'is_owner': true,
      'approved_workspaces': ['trader', 'supplier'],
    }));
    if (workspaceCubit.state?.active != workspace) await workspaceCubit.switchTo(workspace);
    await notifications.load();

    final theme = buildAppTheme(ThemeTokens.traderFallback, locale, brightness: brightness);
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: session),
        BlocProvider.value(value: workspaceCubit),
        BlocProvider.value(value: notifications),
      ],
      child: EasyLocalization(
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
            home: workspace == Workspace.trader ? const TraderShell() : const SupplierShell(),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  final cases = [
    ('trader', Workspace.trader, 'ar', Brightness.light),
    ('trader', Workspace.trader, 'en', Brightness.light),
    ('supplier', Workspace.supplier, 'ar', Brightness.dark),
  ];

  for (final (name, workspace, locale, brightness) in cases) {
    final suffix = '$name-$locale${brightness == Brightness.dark ? '-dark' : ''}';
    testWidgets('shell $suffix', skip: !_goldens, (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 2, 844 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      late Widget root;
      await tester.runAsync(() async {
        root = await app(locale: locale, brightness: brightness, workspace: workspace);
        await tester.pumpWidget(root);
      });
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screen-home-$suffix.png'));

      // Walk the tabs through the real nav bar.
      const tabs = ['trade', 'alerts', 'more'];
      for (var i = 0; i < tabs.length; i++) {
        final navButtons = find.descendant(
          of: find.byType(AppNavBar),
          matching: find.byType(InkResponse),
        );
        await tester.tap(navButtons.at(i + 1));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await settle(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/screen-${tabs[i]}-$suffix.png'),
        );
      }
    });
  }
}
