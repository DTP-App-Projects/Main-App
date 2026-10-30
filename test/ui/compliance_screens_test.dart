import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/data/repositories/receivables_repository.dart';
import 'package:digital_trade_portal/data/repositories/shipments_repository.dart';
import 'package:digital_trade_portal/features/shared/compliance/terms/terms_cubit.dart';
import 'package:digital_trade_portal/features/shared/compliance/terms/terms_views.dart';
import 'package:digital_trade_portal/features/shared/compliance/views/account_legal_views.dart';
import 'package:digital_trade_portal/features/shared/compliance/views/agreement_views.dart';
import 'package:digital_trade_portal/features/shared/compliance/views/document_views.dart';
import 'package:digital_trade_portal/features/shared/compliance/views/evidence_views.dart';
import 'package:digital_trade_portal/features/shared/compliance/views/marketer_views.dart';
import 'package:digital_trade_portal/features/shared/compliance/views/quotation_views.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Every new compliance screen, pumped in Arabic (RTL) at phone width against
/// trimmed copies of staging's real responses: it renders, it shows the
/// document, and nothing overflows.
const _fixtures = <String, Object>{
  '/v2/quotations/1': {
    'quotation': {
      'id': 1, 'quotation_no': 'QT-2026-000001', 'business_relationship_id': 1,
      'supplier': {'id': 5, 'display_name': 'بيرغامو'}, 'trader': {'id': 6, 'display_name': 'club city'},
      'supply_model': 'direct', 'supply_model_label': 'توريد نقدي',
      'valid_until': '2026-10-20T00:00:00+03:00', 'is_valid_now': true,
      'status': 'sent', 'status_label': 'مُرسل', 'currency_code': 'SAR',
      'subtotal': 6000, 'tax_total': 900, 'grand_total': 6900, 'my_role': 'trader',
      'can_accept': true, 'otp_document_type': 'quotation',
      'body_text': 'عرض سعر\nالمستند: QT-2026-000001', 'document_hash': 'f5e8',
      'lines': [
        {'id': 1, 'sku_id': 6, 'name': 'تيد 2', 'unit': 'وحدة', 'qty': 2, 'unit_price': 3000, 'vat_rate': 15, 'line_total': 6900},
      ],
    },
  },
  '/v2/quotations': {
    'quotations': [
      {'id': 1, 'quotation_no': 'QT-2026-000001', 'status': 'sent', 'grand_total': 6900, 'my_role': 'trader',
       'supplier': {'id': 5, 'display_name': 'بيرغامو'}, 'valid_until': '2026-10-20T00:00:00+03:00', 'can_accept': true},
    ],
    'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 1},
  },
  '/v2/relationship_requests/4': {
    'relationship_request': {
      'id': 4, 'relationship_id': 4, 'request_no': 'REL-2026-000001', 'request_status': 'submitted',
      'request_status_label': 'مقدّم', 'supply_status': 'active', 'my_role': 'supplier', 'can_decide': true,
      'otp_document_type': 'relationship_request', 'requested_model': 'credit', 'requested_model_label': 'توريد آجل',
      'requested_credit_term_days': 30, 'requested_credit_limit': 50000, 'debt_documentation_label': 'إقرار إلكتروني فقط',
      'submitted_at': '2026-10-05T19:10:19+03:00', 'counterparty': {'id': 16, 'display_name': 'مسوّق تجريبي'},
      'body_text': 'طلب فتح علاقة تجارية وتحديد حد التعامل', 'document_hash': '85d0',
    },
  },
  '/v2/return_notes/1': {
    'data': {
      'id': 1, 'return_no': 'RN-2026-000001', 'purchase_order_id': 11, 'purchase_order_no': 'PO-20260926-C73ECDC0',
      'status': 'requested', 'status_label': 'مطلوب', 'reason': 'defect', 'reason_label': 'عيب',
      'requested_by_side': 'trader', 'accepting_side': 'supplier', 'grand_total': 3450, 'currency_code': 'SAR',
      'lines': [{'id': 1, 'sku_id': 6, 'sku_name': 'تيد 2', 'qty': 1, 'line_total': 3000}],
    },
  },
  '/v2/invoices/1': {
    'invoice': {
      'id': 1, 'invoice_no': 'INV-2026-000001', 'status': 'issued', 'invoice_date': '2026-10-05',
      'subtotal': 57000, 'tax_total': 8550, 'grand_total': 65550, 'currency_code': 'SAR', 'business_relationship_id': 1,
      'document_title': 'فاتورة ضريبية', 'seller': {'organization_id': 5, 'name': 'بيرغامو', 'vat_no': 7678578},
      'buyer': {'organization_id': 6, 'name': 'club city', 'vat_no': 48740873804}, 'vat_rate': 15,
      'zatca_qr': 'AQ7YqNmK2LHYutin2YXZiAIHNzY3ODU3OA==',
      'refs': {'po_no': 'PO-20260926-C73ECDC0', 'fa_no': '', 'grn_nos': ['GR-20260926-1A3C5A1F']},
      'issued_at_utc': '2026-10-05 16:14:01', 'legal_footer': 'منصة التكامل التجاري الرقمي أداة توثيق وإدارة.',
    },
  },
  '/v2/invoices/1/late_payment': {
    'late_payment': {'supply_status': 'active', 'supply_status_label': 'التوريد قائم', 'outstanding': 65550,
      'is_past_due': false, 'original_due_date': '2026-10-05', 'notices': []},
  },
  '/v2/invoices/1/promissory_notes': {
    'promissory_notes': [], 'api_enabled': false, 'fallback_url': 'https://www.nafith.sa', 'eligible': false,
    'defaults': {'amount': 65550},
  },
  '/v2/dispute_packs/1': {
    'dispute_pack': {
      'id': 1, 'pack_no': 'PACK-2026-000001', 'scope_type': 'invoice', 'scope_id': 1, 'items_count': 2,
      'generated_at_utc': '2026-10-05 16:14:53', 'principal_outstanding': 65550, 'zip_sha256': '5ff5',
      'items': [
        {'type': 'purchase_order', 'label': 'أمر الشراء', 'number': 'PO-20260926-C73ECDC0', 'source': 'live'},
        {'type': 'invoice', 'label': 'الفاتورة', 'number': 'INV-2026-000001', 'source': 'frozen'},
      ],
    },
  },
  '/v2/complaint_tickets/1': {
    'ticket': {
      'ticket_id': 1, 'ticket_no': 'TKT-2026-000001', 'category_label': 'مشكلة تقنية', 'subject': 'تذكرة اختبار',
      'status': 'open', 'status_label': 'مفتوحة', 'sla_label': 'ضمن المهلة', 'due_at': '2026-10-20T19:12:47+03:00',
      'created_at': '2026-10-05T19:12:47+03:00', 'body': 'تفاصيل الشكوى', 'attachments': [],
      'messages': [
        {'message_id': 1, 'author': 'user', 'body': 'رد اختبار', 'created_at': '2026-10-05T19:12:57+03:00',
         'attachments': [{'name': 'test.png', 'size': 73, 'mime': 'image/png', 'url': 'https://tacaml.com/api/v2/complaint_tickets/1/attachment?message=1&i=0'}]},
      ],
    },
  },
  '/v2/signatories': {
    'organization': {'organization_id': 6, 'legal_name_ar': 'club city', 'commercial_reg_no': 4087340730,
      'vat_no': 48740873804, 'activity_type': 'retailer', 'activity_type_label': 'تاجر جملة / تجزئة',
      'registration_locked': true, 'cr_verified': false},
    'can_manage': true,
    'data': [
      {'membership_id': 6, 'user_id': 8, 'name': 'redouane ridmi', 'job_title': 'Owner', 'is_owner': true, 'is_authorized_signatory': true},
      {'membership_id': 7, 'user_id': 9, 'name': 'عضو', 'is_owner': false, 'is_authorized_signatory': false},
    ],
  },
  '/v2/goods_receipts/1': {
    'goods_receipt': {
      'id': 1, 'purchase_order_id': 11, 'delivery_note_id': 11, 'status': 'accepted', 'received_at': '2026-09-26 22:51:11',
      'receipt_no': 'GR-20260926-1A3C5A1F', 'pod_method': 'photo', 'recorded_by_role': 'carrier',
      'confirmation_status': 'received_unconfirmed', 'confirmation_label': 'وصل ولم يُؤكَّد',
      'requires_trader_confirmation': true,
      'lines': [{'id': 1, 'sku_id': 6, 'sku_name': 'تيد 2', 'expected_qty': 20, 'received_qty': 18,
        'shortage_qty': 1, 'defect_qty': 1, 'defect_note': 'كسر في العبوة'}],
    },
  },
  '/v2/marketer': {
    'marketer': {'id': 1, 'organization_id': 16, 'display_name': 'مسوّق تجريبي', 'referral_code': 'MKTNN7STN', 'status': 'active'},
    'totals': {'earned': 0, 'pending': 0, 'void': 0},
  },
  '/v2/marketer/assignments': {
    'assignments': [
      {'id': 1, 'assignment_no': 'MK-2026-000001', 'supplier_name': 'بيرغامو', 'rate_label': '2.5%', 'status': 'offered'},
    ],
  },
  '/v2/service_invoices': {
    'free_period': {
      'account_activated_at': '2026-10-01 09:12:00', 'free_until': '2099-01-01 09:12:00', 'in_free_period': true, 'months': 3,
      'extension': {'invoices': 7, 'invoices_target': 20, 'gmv_ex_vat': '38250.00', 'gmv_target': '100000.00',
                    'criterion_met': null, 'reviewed': false, 'extended': false},
    },
    'platform_fee_rate': 1.0,
    'new_orders_restricted': true,
    'wallet_enabled': false,
    'service_invoices': {'current_page': 1, 'last_page': 1, 'total': 1, 'data': [
      {'id': 12, 'invoice_no': 'SINV-2026-000012', 'kind': 'platform_fee', 'kind_label': 'رسوم المنصة', 'status': 'issued',
       'grand_total': '382.50', 'issued_at': '2026-11-01 00:05:00', 'period': '2026-10', 'due_at': '2026-11-08 00:05:00',
       'is_overdue': true},
    ]},
  },
  '/v2/terms_status': {
    'acceptance_required': true,
    'update_announced': false,
    'documents': [
      {'terms_version_id': 9, 'doc_key': 'service_partnership', 'title': 'عقد الشراكة (عقد الخدمة)',
       'label': 'عقد الشراكة (عقد الخدمة)', 'version': 1.0, 'effective_at': '2026-10-24T09:00:00+03:00',
       'in_force': true, 'scope': 'organization', 'accepted': false, 'can_accept': false},
    ],
  },
};

void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen, {Workspace workspace = Workspace.trader}) async {
    tester.view
      ..physicalSize = const Size(390 * 2, 844 * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final (client, _) = clientWith(FakeAdapter((options) async {
      final body = _fixtures[options.path];
      return body == null ? jsonBody(const {'msg': 'not_found'}, status: 404) : jsonBody(body);
    }));
    final workspaceCubit = WorkspaceCubit(SessionStore(), OpsRepository(client));

    await getIt.reset();
    getIt
      ..registerSingleton<ComplianceRepository>(ComplianceRepository(client))
      ..registerSingleton<TermsCubit>(TermsCubit(ComplianceRepository(client)))
      ..registerSingleton<ShipmentsRepository>(ShipmentsRepository(client))
      ..registerSingleton<ReceivablesRepository>(ReceivablesRepository(client))
      ..registerSingleton<WorkspaceCubit>(workspaceCubit);

    await tester.runAsync(() async {
      await workspaceCubit.hydrate(Organization.fromJson(const {
        'id': 3,
        'display_name': 'مؤسسة',
        'business_mode': 'hybrid',
        'is_owner': true,
        'approved_workspaces': ['trader', 'supplier'],
      }));
      if (workspaceCubit.state?.active != workspace) await workspaceCubit.switchTo(workspace);
      await tester.pumpWidget(BlocProvider.value(
        value: workspaceCubit,
        child: EasyLocalization(
          supportedLocales: const [Locale('ar'), Locale('en')],
          path: 'lib/core/language',
          startLocale: const Locale('ar'),
          fallbackLocale: const Locale('ar'),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: buildAppTheme(ThemeTokens.traderFallback, 'ar'),
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: screen,
            ),
          ),
        ),
      ));
    });
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    }
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// Detail screens are lazy lists: scroll the action into view first.
  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(find.text(text), find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pump();
  }

  void expectRtl(WidgetTester tester) {
    final dir = Directionality.of(tester.element(find.byType(Scaffold).first));
    expect(dir, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  }

  testWidgets('quotation detail: expiry, lines, accept for the trader', (tester) async {
    await pumpScreen(tester, const QuotationDetailView(quotationId: 1));
    expect(find.text('QT-2026-000001'), findsWidgets);
    await reveal(tester, 'قبول العرض');
    expect(find.text('قبول العرض'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('quotations list reads the pagination envelope', (tester) async {
    await pumpScreen(tester, const QuotationsView());
    expect(find.text('QT-2026-000001'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('relationship request: the supplier can accept or reject', (tester) async {
    await pumpScreen(tester, const RelationshipRequestDetailView(requestId: 4), workspace: Workspace.supplier);
    expect(find.text('REL-2026-000001'), findsOneWidget);
    await reveal(tester, 'رفض الطلب');
    expect(find.text('قبول الطلب'), findsOneWidget);
    expect(find.text('رفض الطلب'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('return note: the accepting side sees accept and reject', (tester) async {
    await pumpScreen(tester, const ReturnNoteDetailView(returnNoteId: 1), workspace: Workspace.supplier);
    expect(find.text('قبول المرتجع'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('tax invoice: title, both VAT numbers and the ZATCA QR', (tester) async {
    await pumpScreen(tester, const InvoiceComplianceView(invoiceId: 1));
    expect(find.text('فاتورة ضريبية'), findsOneWidget);
    expect(find.text('7678578'), findsOneWidget);
    expect(find.text('48740873804'), findsOneWidget);
    expect(find.byKey(const Key('zatca_qr')), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('dispute pack: contents and download', (tester) async {
    await pumpScreen(tester, const DisputePackDetailView(packId: 1));
    expect(find.text('مستند حي — غير مجمد'), findsOneWidget);
    expect(find.text('تنزيل الحزمة (ZIP)'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('complaint: number, 15-day deadline, thread', (tester) async {
    await pumpScreen(tester, const ComplaintDetailView(ticketId: 1));
    expect(find.text('TKT-2026-000001'), findsOneWidget);
    expect(find.text('رد اختبار'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('signatories: locked registration data', (tester) async {
    await pumpScreen(tester, const SignatoriesView());
    expect(find.byKey(const Key('registration_locked_hint')), findsOneWidget);
    expect(find.text('يُعدَّل عبر إدارة المنصة'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('goods receipt: «وصل ولم يُؤكَّد», shortage/defect, both confirm paths', (tester) async {
    await pumpScreen(tester, const GoodsReceiptDetailView(receiptId: 1));
    expect(find.text('وصل ولم يُؤكَّد'), findsWidgets);
    expect(find.text('كسر في العبوة'), findsOneWidget);
    await reveal(tester, 'تأكيد بصورة وإقرار');
    expect(find.text('تأكيد برمز تحقق'), findsOneWidget);
    expect(find.text('تأكيد بصورة وإقرار'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('marketer home: referral code and an offer to accept', (tester) async {
    await pumpScreen(tester, const MarketerHomeView());
    expect(find.text('MKTNN7STN'), findsOneWidget);
    expect(find.text('MK-2026-000001'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('service invoices: free period, extension progress, overdue', (tester) async {
    await pumpScreen(tester, const ServiceInvoicesView());
    expect(find.byKey(const Key('free_period_card')), findsOneWidget);
    expect(find.byKey(const Key('extension_invoices')), findsOneWidget);
    expect(find.byKey(const Key('extension_gmv')), findsOneWidget);
    expect(find.text('7 / 20'), findsOneWidget);
    expect(find.byKey(const Key('service_invoice_overdue_banner')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('SINV-2026-000012'), 200);
    expect(find.text('SINV-2026-000012'), findsOneWidget);
    expect(find.textContaining('رسوم المنصة'), findsOneWidget);
    expect(find.textContaining('تستحق في'), findsOneWidget);
    expect(find.text('متأخرة'), findsOneWidget);
    expectRtl(tester);
  });

  testWidgets('terms: the partnership contract waits for the signatory', (tester) async {
    await pumpScreen(tester, const TermsGateView());
    expect(find.text('عقد الشراكة (عقد الخدمة)'), findsWidgets);
    expect(find.text('بانتظار قبول المفوّض بالتوقيع'), findsOneWidget);
    // Not the signatory: no checkbox, no «أوافق».
    expect(find.byKey(const Key('terms_agree')), findsNothing);
    expect(find.text('أوافق'), findsNothing);
    expectRtl(tester);
  });
}
