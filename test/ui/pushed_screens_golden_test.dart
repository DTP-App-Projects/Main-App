import 'package:dio/dio.dart';
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:digital_trade_portal/data/repositories/account_repository.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/catalog_repository.dart';
import 'package:digital_trade_portal/data/repositories/contracts_repository.dart';
import 'package:digital_trade_portal/data/repositories/lookups_repository.dart';
import 'package:digital_trade_portal/data/repositories/notifications_repository.dart';
import 'package:digital_trade_portal/data/repositories/onboarding_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/data/repositories/receivables_repository.dart';
import 'package:digital_trade_portal/data/repositories/shipments_repository.dart';
import 'package:digital_trade_portal/data/repositories/shop_repository.dart';
import 'package:digital_trade_portal/data/repositories/supplier_repository.dart';
import 'package:digital_trade_portal/data/repositories/uploads_repository.dart';
import 'package:digital_trade_portal/features/shared/advanced/views/account_views.dart';
import 'package:digital_trade_portal/features/shared/advanced/views/contracts_views.dart';
import 'package:digital_trade_portal/features/shared/advanced/views/finance_views.dart';
import 'package:digital_trade_portal/features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/views/documents_view.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/views/onboarding_wizard_view.dart';
import 'package:digital_trade_portal/features/shared/orders/views/order_detail_view.dart';
import 'package:digital_trade_portal/features/shop/views/shop_browse_views.dart';
import 'package:digital_trade_portal/features/shop/views/shop_cart_views.dart';
import 'package:digital_trade_portal/features/shop/views/shop_product_view.dart';
import 'package:digital_trade_portal/features/supplier/views/money_views.dart';
import 'package:digital_trade_portal/features/supplier/views/orders_inbox_view.dart';
import 'package:digital_trade_portal/features/supplier/views/outbound_views.dart';
import 'package:digital_trade_portal/features/supplier/views/pricing_views.dart';
import 'package:digital_trade_portal/features/supplier/views/relationships_views.dart';
import 'package:digital_trade_portal/features/trader/catalog/views/catalog_views.dart';
import 'package:digital_trade_portal/features/trader/drafts/views/draft_editor_view.dart';
import 'package:digital_trade_portal/features/trader/orders/views/orders_views.dart';
import 'package:digital_trade_portal/features/trader/payables/views/payables_views.dart';
import 'package:digital_trade_portal/features/trader/shipments/views/shipments_views.dart';
import 'package:digital_trade_portal/features/trader/suppliers/views/supplier_detail_view.dart';
import 'package:digital_trade_portal/features/trader/suppliers/views/suppliers_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';
import 'golden_support.dart';

/// Renders the pushed (non-tab) screens — real views, real cubits, one fake
/// backend that answers by path — so the redesign can be reviewed in Arabic
/// light and English dark:
///
///     flutter test test/ui/pushed_screens_golden_test.dart --dart-define=GOLDENS=true --update-goldens
///
/// A design artefact, not a regression lock (see `ledger_golden_test.dart`).
const _goldens = bool.fromEnvironment('GOLDENS');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _paged(List<Map<String, dynamic>> rows, {bool formatted = true}) => {
      'current_page': 1,
      'last_page': 1,
      'per_page': 15,
      'total': rows.length,
      'data': [
        for (final row in rows) formatted ? {'id': row['id'], 'formatted': row} : row,
      ],
    };

/// Every payload is built per locale, the way the server localizes
/// `display_name` from `Accept-Language`.
class _Fixtures {
  final bool ar;

  _Fixtures(String locale) : ar = locale == 'ar';

  String t(String arabic, String english) => ar ? arabic : english;

  // ---------------------------------------------------------------- parties

  Map<String, dynamic> get riyadh => {'id': 7, 'name': t('دار الرياض للتوريد', 'Riyadh Supply House')};
  Map<String, dynamic> get najd => {'id': 8, 'name': t('مصانع نجد للأغذية', 'Najd Food Factories')};
  Map<String, dynamic> get gulf => {'id': 9, 'name': t('شركة الخليج للتجارة', 'Gulf Trading Co.')};
  Map<String, dynamic> get alfaisal => {'id': 3, 'name': t('مؤسسة الفيصل التجارية', 'Al-Faisal Trading Est.')};
  Map<String, dynamic> get tamimi => {'id': 21, 'name': t('أسواق التميمي', 'Tamimi Markets')};
  Map<String, dynamic> get othaim => {'id': 22, 'name': t('العثيم للتجزئة', 'Othaim Retail')};
  Map<String, dynamic> get danube => {'id': 23, 'name': t('بقالات الدانوب', 'Danube Grocers')};
  Map<String, dynamic> get noor => {'id': 24, 'name': t('مخابز النور', 'Al-Noor Bakeries')};

  Map<String, dynamic> get net30 => {
        'id': 2,
        'display_name': t('آجل ٣٠ يوماً', 'Net 30 days'),
        'code': 'NET30',
        'term_mode': 'deferred',
        'due_days': 30,
        'installment_count': 1,
      };

  List<Map<String, dynamic>> get paymentTerms => [
        {
          'id': 1,
          'display_name': t('نقداً عند الاستلام', 'Cash on delivery'),
          'code': 'COD',
          'term_mode': 'cash',
          'due_days': 0,
          'installment_count': 1,
        },
        net30,
        {
          'id': 3,
          'display_name': t('ثلاثة أقساط شهرية', 'Three monthly instalments'),
          'code': 'INST3',
          'term_mode': 'installments',
          'due_days': 30,
          'installment_count': 3,
          'installment_interval_days': 30,
        },
      ];

  // ----------------------------------------------------------------- orders

  Map<String, dynamic> _order(
    int id,
    String code,
    String status,
    Map<String, dynamic> supplier,
    Map<String, dynamic> trader,
    num total, {
    int items = 4,
    String viewer = 'trader',
    String delivery = '2026-09-28 00:00:00',
    String credit = 'passed',
  }) =>
      {
        'id': id,
        'code': code,
        'status': status,
        'credit_check_status': credit,
        'trader_organization_id': trader['id'],
        'supplier_organization_id': supplier['id'],
        'requested_delivery_date': delivery,
        'subtotal': total / 1.15,
        'tax_total': total - total / 1.15,
        'grand_total': total,
        'currency': 'SAR',
        'ordered_items_count': items,
        'ordered_units_total': items * 24,
        'shipped_units_total': status == 'delivered' ? items * 24 : 0,
        'outstanding_items_count': status == 'delivered' ? 0 : items,
        'outstanding_units_total': status == 'delivered' ? 0 : items * 24,
        'supplier': supplier,
        'trader': trader,
        'payment_term': net30,
        'viewer_role': viewer,
      };

  List<Map<String, dynamic>> get traderOrders => [
        _order(1, 'PO-20260921-A1F4', 'approved', riyadh, alfaisal, 18450, items: 6),
        _order(2, 'PO-20260922-B7C2', 'submitted', najd, alfaisal, 7320.5, items: 3),
        _order(3, 'PO-20260920-C3D9', 'cancel_requested', gulf, alfaisal, 2980, items: 2),
        _order(4, 'PO-20260915-D8E1', 'delivered', riyadh, alfaisal, 26400, items: 9,
            delivery: '2026-09-18 00:00:00'),
        _order(5, 'PO-20260912-E2A7', 'rejected', najd, alfaisal, 5140, items: 2,
            credit: 'failed'),
        _order(6, 'PO-20260910-F5B3', 'under_review', gulf, alfaisal, 11275.75, items: 5),
      ];

  List<Map<String, dynamic>> get supplierOrders => [
        _order(11, 'PO-20260924-K1Q8', 'submitted', alfaisal, tamimi, 32150, items: 12,
            viewer: 'supplier'),
        _order(12, 'PO-20260924-K2R3', 'submitted', alfaisal, othaim, 8600, items: 4,
            viewer: 'supplier'),
        _order(13, 'PO-20260923-K3S6', 'under_review', alfaisal, danube, 14420.25, items: 7,
            viewer: 'supplier', credit: 'warning'),
        _order(14, 'PO-20260923-K4T1', 'submitted', alfaisal, noor, 2275, items: 2,
            viewer: 'supplier'),
        _order(15, 'PO-20260920-K5U4', 'approved', alfaisal, tamimi, 9800, items: 3,
            viewer: 'supplier'),
      ];

  List<Map<String, dynamic>> _poLines() => [
        {
          'id': 101,
          'sku_id': 501,
          'sku_code': 'RIC-BAS-5KG',
          'sku_name': t('أرز بسمتي ٥ كجم', 'Basmati rice 5 kg'),
          'product_id': 51,
          'product_name': t('أرز بسمتي', 'Basmati rice'),
          'qty': 120,
          'unit_price': 42.5,
          'tax_value': 765,
          'line_total': 5865,
          'shipped_qty': 0,
        },
        {
          'id': 102,
          'sku_id': 502,
          'sku_code': 'OIL-SUN-18L',
          'sku_name': t('زيت دوار الشمس ١٫٨ لتر', 'Sunflower oil 1.8 L'),
          'product_id': 52,
          'product_name': t('زيت دوار الشمس', 'Sunflower oil'),
          'qty': 200,
          'unit_price': 28,
          'tax_value': 840,
          'line_total': 6440,
          'shipped_qty': 0,
        },
        {
          'id': 103,
          'sku_id': 503,
          'sku_code': 'SUG-WHT-2KG',
          'sku_name': t('سكر أبيض ٢ كجم', 'White sugar 2 kg'),
          'product_id': 53,
          'product_name': t('سكر أبيض', 'White sugar'),
          'qty': 150,
          'unit_price': 35.5,
          'tax_value': 798.75,
          'line_total': 6123.75,
          'shipped_qty': 0,
        },
      ];

  Map<String, dynamic> get orderDetail => {
        ...traderOrders.first,
        'notes': t('يرجى التسليم صباحاً قبل الساعة ١٠', 'Please deliver in the morning before 10 am'),
        'allowed_transitions': <String>[],
        'reason_required_for': ['rejected', 'canceled'],
        'next_action': 'await_shipment',
        'can_request_cancel': true,
        'lines': _poLines(),
        'timeline': [
          {
            'event': 'approved',
            'title': t('اعتمد المورد الطلب', 'Supplier approved the order'),
            'status': 'approved',
            'actor_name': t('سارة القحطاني', 'Sara Al-Qahtani'),
            'at': '2026-09-22 11:40:00',
          },
          {
            'event': 'under_review',
            'title': t('قيد المراجعة', 'Under review'),
            'status': 'under_review',
            'actor_name': t('سارة القحطاني', 'Sara Al-Qahtani'),
            'at': '2026-09-21 16:05:00',
          },
          {
            'event': 'submitted',
            'title': t('تم إرسال الطلب', 'Order submitted'),
            'status': 'submitted',
            'actor_name': t('خالد الفيصل', 'Khaled Al-Faisal'),
            'at': '2026-09-21 09:12:00',
          },
        ],
      };

  // -------------------------------------------------------------- suppliers

  Map<String, dynamic> _supplier(
    Map<String, dynamic> party,
    String relationship, {
    bool contract = false,
    bool ready = false,
    int products = 48,
    String nature = 'supplier',
  }) =>
      {
        'id': party['id'],
        'display_name': party['name'],
        'business_mode': 'supplier',
        'supplier_nature': nature,
        'status': 'active',
        'profile_status': 'active',
        'sectors': [
          {'id': 1, 'name': t('المواد الغذائية', 'Food & groceries')},
          {'id': 4, 'name': t('المشروبات', 'Beverages')},
        ],
        'relationship_id': relationship == 'none' ? null : 40 + (party['id'] as int),
        'relationship_status': relationship,
        'relationship_classification': 'standard',
        'active_contracts_count': contract ? 1 : 0,
        'has_active_contract': contract,
        'latest_contract': contract
            ? {
                'id': 61,
                'display_name': t('عقد توريد سنوي ٢٠٢٦', 'Annual supply contract 2026'),
                'contract_type': 'supply',
                'status': 'active',
              }
            : null,
        'products_count': products,
        'skus_count': products * 3,
        'branches_count': 4,
        'order_entry_ready': ready,
      };

  List<Map<String, dynamic>> get suppliers => [
        _supplier(riyadh, 'approved', contract: true, ready: true, products: 126),
        _supplier(najd, 'approved', products: 64, nature: 'manufacturer'),
        _supplier(gulf, 'pending_review', products: 37),
        _supplier({'id': 10, 'name': t('ألبان المراعي الذهبية', 'Golden Dairy Co.')}, 'none',
            products: 22, nature: 'manufacturer'),
        _supplier({'id': 11, 'name': t('مؤسسة الواحة للتوزيع', 'Oasis Distribution')},
            'suspended', products: 15),
      ];

  // ---------------------------------------------------------------- catalog

  Map<String, dynamic> _sku(int id, String code, String nameAr, String nameEn, num price,
          {num min = 6, num step = 6, num available = 340}) =>
      {
        'id': id,
        'sku_code': code,
        'display_name_ar': nameAr,
        'display_name_en': nameEn,
        'packaging_type': 'carton',
        'unit_label_ar': 'كرتون',
        'unit_label_en': 'carton',
        'pack_quantity': 6,
        'min_order_qty': min,
        'order_step_qty': step,
        'barcode': '6281000123456',
        'status': 'active',
        'track_inventory': true,
        'available_qty': available,
        'pricing': {
          'matched': true,
          'currency_code': 'SAR',
          'unit_price': price,
          'final_price': price * 0.95,
        },
      };

  Map<String, dynamic> _product(int id, String ar, String en, Map<String, dynamic> supplier,
          Map<String, dynamic> sku, {String category = 'grocery', num discount = 0}) =>
      {
        'id': id,
        'organization_id': supplier['id'],
        'name': t(ar, en),
        'ar_name': ar,
        'en_name': en,
        'type': 'static',
        'status': 'active',
        'image': '',
        'thumb_image': '',
        'discount': discount,
        'is_negotiated': discount > 0,
        'supplier': supplier,
        'relationship_id': 47,
        'relationship_status': 'approved',
        'categories': [
          {'id': 1, 'name': category == 'grocery' ? t('بقالة', 'Grocery') : t('مشروبات', 'Beverages')},
        ],
        'skus_count': 3,
        'primary_sku': sku,
      };

  List<Map<String, dynamic>> get products => [
        _product(51, 'أرز بسمتي فاخر', 'Premium basmati rice', riyadh,
            _sku(501, 'RIC-BAS-5KG', 'أرز بسمتي ٥ كجم', 'Basmati rice 5 kg', 42.5), discount: 5),
        _product(52, 'زيت دوار الشمس', 'Sunflower oil', riyadh,
            _sku(502, 'OIL-SUN-18L', 'زيت ١٫٨ لتر', 'Oil 1.8 L', 28)),
        _product(53, 'سكر أبيض ناعم', 'Fine white sugar', najd,
            _sku(503, 'SUG-WHT-2KG', 'سكر ٢ كجم', 'Sugar 2 kg', 35.5)),
        _product(54, 'مياه معدنية', 'Mineral water', gulf,
            _sku(504, 'WAT-330-40', 'مياه ٣٣٠ مل × ٤٠', 'Water 330 ml × 40', 19.75,
                min: 10, step: 10, available: 1200),
            category: 'drinks'),
        _product(55, 'تمر خلاص', 'Khalas dates', najd,
            _sku(505, 'DAT-KHL-1KG', 'تمر خلاص ١ كجم', 'Khalas dates 1 kg', 54), discount: 10),
        _product(56, 'حليب طويل الأجل', 'Long-life milk', gulf,
            _sku(506, 'MLK-UHT-1L', 'حليب ١ لتر × ١٢', 'Milk 1 L × 12', 61.25), category: 'drinks'),
      ];

  // ------------------------------------------------------------------ draft

  Map<String, dynamic> get draft => {
        'id': 41,
        'status': 'open',
        'supplier_organization_id': 7,
        'business_relationship_id': 47,
        'payment_term_id': 2,
        'notes': '',
        'subtotal': 16052.17,
        'tax_total': 2407.83,
        'grand_total': 18460,
        'supplier': riyadh,
        'payment_term': net30,
        'lines_count': 3,
        'lines': [
          for (final line in _poLines())
            {
              'id': line['id'],
              'sku_id': line['sku_id'],
              'sku_code': line['sku_code'],
              'sku_name': line['sku_name'],
              'qty': line['qty'],
              'unit_price': line['unit_price'],
              'line_total': line['line_total'],
            },
        ],
      };

  // -------------------------------------------------------------- shipments

  Map<String, dynamic> _note(int id, String code, String status, String poCode, num total,
          {String dispatched = '2026-09-23 07:30:00'}) =>
      {
        'id': id,
        'purchase_order_id': id,
        'purchase_order_code': poCode,
        'code': code,
        'status': status,
        'supplier_branch': {'id': 70, 'name': t('مستودع السلي', 'Al-Sulay warehouse')},
        'trader_branch': {'id': 80, 'name': t('فرع العليا', 'Olaya branch')},
        'dispatched_at': status == 'draft' ? null : dispatched,
        'delivered_at': status == 'delivered' ? '2026-09-23 12:10:00' : null,
        'subtotal': total / 1.15,
        'tax_total': total - total / 1.15,
        'grand_total': total,
        'currency': 'SAR',
        'driver': {'id': 5, 'name': t('فهد العتيبي', 'Fahad Al-Otaibi'), 'phone': 'm_p0551234567'},
        'vehicle': {'id': 3, 'plate_number': 'ر س ع ٤٥٢١'},
        if (status == 'canceled') ...{
          'cancel_reason': 'vehicle_issue',
          'cancel_reason_label': t('عطل في المركبة', 'Vehicle issue'),
        },
      };

  List<Map<String, dynamic>> get deliveryNotes => [
        _note(5, 'DN-1180', 'en_route', 'PO-20260921-A1F4', 18450),
        _note(6, 'DN-1178', 'arrived', 'PO-20260920-C3D9', 2980),
        _note(7, 'DN-1175', 'dispatched', 'PO-20260910-F5B3', 11275.75),
        _note(8, 'DN-1169', 'delivered', 'PO-20260915-D8E1', 26400,
            dispatched: '2026-09-18 06:45:00'),
        _note(9, 'DN-1160', 'rejected', 'PO-20260912-E2A7', 5140,
            dispatched: '2026-09-14 08:00:00'),
        _note(10, 'DN-1152', 'canceled', 'PO-20260908-G1H2', 3400,
            dispatched: '2026-09-09 09:20:00'),
      ];

  List<Map<String, dynamic>> _dnLines() => [
        for (final line in _poLines())
          {
            'id': (line['id'] as int) + 100,
            'purchase_order_line_id': line['id'],
            'sku_id': line['sku_id'],
            'sku_name': line['sku_name'],
            'product_id': line['product_id'],
            'product_name': line['product_name'],
            'shipped_qty': line['qty'],
            'unit_price': line['unit_price'],
            'tax_value': line['tax_value'],
            'line_total': line['line_total'],
          },
      ];

  Map<String, dynamic> get tracking => {
        ...deliveryNotes.first,
        'en_route_at': '2026-09-24 08:05:00',
        'pickup_seal_numbers': ['SL-44821', 'SL-44822'],
        'notes': t('الشحنة مبردة — يرجى الاستلام فوراً', 'Chilled load — please receive promptly'),
        'lines': _dnLines(),
        'route_stop': {
          'id': 3,
          'status': 'en_route',
          'planned_arrival_time': '2026-09-24 10:30:00',
          'receiver_otp_status': 'pending',
          'proofs': [
            {
              'id': 1,
              'proof_type': 'pickup_photo',
              'file_type': 'image/jpeg',
              'file_path': '',
              'captured_at': '2026-09-24 07:25:00',
            },
            {
              'id': 2,
              'proof_type': 'pickup_signature',
              'signer_name': t('ماجد الحربي', 'Majed Al-Harbi'),
              'signer_role': 'warehouse_keeper',
              'captured_at': '2026-09-24 07:28:00',
            },
          ],
        },
      };

  Map<String, dynamic> get outboundDetail => {
        ..._note(5, 'DN-1180', 'draft', 'PO-20260924-K1Q8', 32150),
        'supplier_branch_id': 70,
        'trader_branch_id': 80,
        'trader_branch': {'id': 80, 'name': t('أسواق التميمي — فرع الملقا', 'Tamimi — Al-Malqa branch')},
        'lines': _dnLines(),
        'notes': t('تحميل الساعة ٦ صباحاً', 'Load at 6 am'),
      };

  // --------------------------------------------------------------- invoices

  Map<String, dynamic> _invoice(int id, String no, String status, num total, num outstanding,
          String due, {Map<String, dynamic>? po}) =>
      {
        'id': id,
        'purchase_order_id': po?['id'],
        'purchase_order': po,
        'invoice_no': no,
        'invoice_date': '2026-09-01 00:00:00',
        'due_date': due,
        'status': status,
        'subtotal': total / 1.15,
        'tax_total': total - total / 1.15,
        'grand_total': total,
        'currency_code': 'SAR',
        'payment_term': net30,
        'outstanding_amount': outstanding,
      };

  List<Map<String, dynamic>> get invoices => [
        _invoice(1, 'INV-3021', 'issued', 18450, 12300, '2026-09-20 00:00:00',
            po: {'id': 1, 'name': 'PO-20260921-A1F4'}),
        _invoice(2, 'INV-3034', 'issued', 7320.5, 7320.5, '2026-10-15 00:00:00'),
        _invoice(3, 'INV-3002', 'partially_paid', 26400, 8800, '2026-10-02 00:00:00'),
        _invoice(4, 'INV-2987', 'paid', 5140, 0, '2026-09-05 00:00:00'),
        _invoice(5, 'INV-2950', 'overdue', 2980, 2980, '2026-09-10 00:00:00'),
        _invoice(6, 'INV-2941', 'canceled', 1200, 0, '2026-09-01 00:00:00'),
      ];

  Map<String, dynamic> get invoiceDetail => {
        ...invoices.first,
        'payment_term': paymentTerms.last,
        'due_schedules': [
          {
            'id': 11,
            'installment_no': 1,
            'due_date': '2026-08-20 00:00:00',
            'due_amount': 6150,
            'paid_amount': 6150,
            'status': 'paid',
          },
          {
            'id': 12,
            'installment_no': 2,
            'due_date': '2026-09-20 00:00:00',
            'due_amount': 6150,
            'paid_amount': 0,
            'status': 'overdue',
          },
          {
            'id': 13,
            'installment_no': 3,
            'due_date': '2026-10-20 00:00:00',
            'due_amount': 6150,
            'paid_amount': 0,
            'status': 'pending',
          },
        ],
        'lines': [
          for (final line in _poLines())
            {
              'id': line['id'],
              'sku_id': line['sku_id'],
              'sku_name': line['sku_name'],
              'qty': line['qty'],
              'unit_price': line['unit_price'],
              'tax_value': line['tax_value'],
              'line_total': line['line_total'],
            },
        ],
      };

  List<Map<String, dynamic>> get collections => [
        {
          'id': 31,
          'invoice_id': 1,
          'invoice': {'id': 1, 'name': 'INV-3021'},
          'receipt_no': 'RC-7781',
          'payment_method': 'transfer',
          'amount': 6150,
          'received_at': '2026-09-22 10:00:00',
          'reference_no': 'SNB-99812345',
          'status': 'pending',
        },
        {
          'id': 30,
          'invoice_id': 3,
          'invoice': {'id': 3, 'name': 'INV-3002'},
          'receipt_no': 'RC-7760',
          'payment_method': 'cheque',
          'amount': 17600,
          'received_at': '2026-09-15 13:30:00',
          'confirmed_at': '2026-09-16 09:00:00',
          'reference_no': 'CHQ-004512',
          'status': 'confirmed',
        },
        {
          'id': 29,
          'invoice_id': 5,
          'invoice': {'id': 5, 'name': 'INV-2950'},
          'receipt_no': 'RC-7741',
          'payment_method': 'cash',
          'amount': 1500,
          'received_at': '2026-09-11 17:45:00',
          'status': 'rejected',
        },
        {
          'id': 28,
          'invoice_id': 4,
          'invoice': {'id': 4, 'name': 'INV-2987'},
          'receipt_no': 'RC-7720',
          'payment_method': 'transfer',
          'amount': 5140,
          'received_at': '2026-09-04 08:20:00',
          'confirmed_at': '2026-09-04 12:00:00',
          'reference_no': 'RJH-11200458',
          'status': 'confirmed',
        },
      ];

  List<Map<String, dynamic>> get returns => [
        {
          'id': 71,
          'invoice_id': 1,
          'reason_type': 'damage',
          'reason_notes': t('وصلت ١٢ كرتونة زيت متضررة', '12 cartons of oil arrived damaged'),
          'status': 'submitted',
          'currency_code': 'SAR',
          'total_amount': 386.4,
          'created_at': '2026-09-23 15:10:00',
        },
        {
          'id': 70,
          'invoice_id': 3,
          'reason_type': 'wrong_item',
          'reason_notes': t('تم توريد سكر بني بدلاً من الأبيض', 'Brown sugar shipped instead of white'),
          'status': 'approved',
          'currency_code': 'SAR',
          'total_amount': 710,
          'created_at': '2026-09-18 11:00:00',
        },
        {
          'id': 69,
          'invoice_id': 4,
          'reason_type': 'quality',
          'reason_notes': t('تاريخ الصلاحية قريب', 'Short shelf life on arrival'),
          'status': 'rejected',
          'currency_code': 'SAR',
          'total_amount': 1240,
          'created_at': '2026-09-09 09:45:00',
        },
      ];

  // ---------------------------------------------------------- relationships

  Map<String, dynamic> _relationship(int id, Map<String, dynamic> party, String status,
          {int orders = 3, int contracts = 1}) =>
      {
        'id': id,
        'my_role': 'supplier',
        'classification': 'standard',
        'status': status,
        'opened_at': '2026-03-14 10:00:00',
        'counterparty': party,
        'contracts_count': contracts,
        'open_purchase_orders_count': orders,
      };

  List<Map<String, dynamic>> get relationships => [
        _relationship(51, tamimi, 'approved', orders: 6, contracts: 2),
        _relationship(52, othaim, 'pending_review', orders: 0, contracts: 0),
        _relationship(53, danube, 'approved', orders: 2),
        _relationship(54, noor, 'suspended', orders: 1),
        _relationship(55, {'id': 25, 'name': t('تموينات الأمانة', 'Al-Amana Supplies')},
            'blacklisted', orders: 0, contracts: 0),
      ];

  Map<String, dynamic> get credit => {
        'relationship_id': 51,
        'credit_profile': {
          'id': 9,
          'grade': 'B',
          'credit_limit': 150000,
          'currency_code': 'SAR',
          'max_due_days': 45,
          'max_overdue_days': 10,
          'upfront_required_percent': 10,
          'auto_freeze_on_limit': true,
          'auto_freeze_on_overdue': false,
          'review_cycle_days': 90,
          'status': 'active',
        },
        'credit_exposure': {
          'open_orders_amount': 41950,
          'issued_invoices_amount': 62300,
          'due_amount': 18400,
          'overdue_amount': 6150,
          'available_credit': 45750,
          'last_calculated_at': '2026-09-24 06:00:00',
        },
      };

  List<Map<String, dynamic>> get priceLists => [
        {
          'id': 1,
          'name_ar': 'قائمة الأسعار العامة',
          'name_en': 'General price list',
          'scope_type': 'default',
          'currency_code': 'SAR',
          'start_date': '2026-01-01 00:00:00',
          'status': 'active',
          'items_count': 126,
        },
        {
          'id': 2,
          'name_ar': 'أسعار أسواق التميمي',
          'name_en': 'Tamimi Markets pricing',
          'scope_type': 'relationship',
          'scope_id': 51,
          'currency_code': 'SAR',
          'start_date': '2026-07-01 00:00:00',
          'end_date': '2026-12-31 00:00:00',
          'status': 'active',
          'items_count': 42,
        },
        {
          'id': 3,
          'name_ar': 'عروض اليوم الوطني',
          'name_en': 'National Day offers',
          'scope_type': 'campaign',
          'scope_id': 4,
          'currency_code': 'SAR',
          'start_date': '2026-09-20 00:00:00',
          'end_date': '2026-09-30 00:00:00',
          'status': 'draft',
          'items_count': 18,
        },
        {
          'id': 4,
          'name_ar': 'عقد العثيم ٢٠٢٥',
          'name_en': 'Othaim contract 2025',
          'scope_type': 'contract',
          'scope_id': 12,
          'currency_code': 'SAR',
          'start_date': '2025-01-01 00:00:00',
          'end_date': '2025-12-31 00:00:00',
          'status': 'inactive',
          'items_count': 64,
        },
      ];

  // -------------------------------------------------------------- contracts

  Map<String, dynamic> _contract(int id, String code, String ar, String en, String status,
          Map<String, dynamic> party, String start, String end) =>
      {
        'id': id,
        'business_relationship_id': 40 + (party['id'] as int),
        'contract_type': 'supply',
        'code': code,
        'name_ar': ar,
        'name_en': en,
        'start_date': start,
        'end_date': end,
        'auto_renew': status == 'active',
        'status': status,
        'relationship': {
          'id': 40 + (party['id'] as int),
          'my_role': 'trader',
          'status': 'approved',
          'counterparty': party,
        },
      };

  List<Map<String, dynamic>> get contracts => [
        _contract(61, 'CT-2026-061', 'عقد توريد سنوي ٢٠٢٦', 'Annual supply contract 2026',
            'active', riyadh, '2026-01-01 00:00:00', '2026-12-31 00:00:00'),
        _contract(62, 'CT-2026-074', 'عقد المواد الجافة', 'Dry goods contract', 'under_review',
            najd, '2026-10-01 00:00:00', '2027-09-30 00:00:00'),
        _contract(63, 'CT-2026-080', 'اتفاقية المشروبات', 'Beverages agreement', 'draft', gulf,
            '2026-11-01 00:00:00', '2027-10-31 00:00:00'),
        _contract(58, 'CT-2025-032', 'عقد توريد ٢٠٢٥', 'Supply contract 2025', 'expired', riyadh,
            '2025-01-01 00:00:00', '2025-12-31 00:00:00'),
        _contract(55, 'CT-2025-019', 'عقد الألبان', 'Dairy contract', 'suspended', gulf,
            '2025-06-01 00:00:00', '2026-05-31 00:00:00'),
      ];

  // --------------------------------------------------------- wallet, billing

  Map<String, dynamic> get wallet => {
        'wallet': {'balance': 12500.5, 'pending_balance': 2000, 'currency_code': 'SAR'},
      };

  List<Map<String, dynamic>> get walletTransactions => [
        {
          'id': 901,
          'type': 'credit',
          'amount': 5000,
          'description': t('شحن عبر تحويل بنكي', 'Top-up by bank transfer'),
          'status': 'completed',
          'created_at': '2026-09-22 10:15:00',
        },
        {
          'id': 900,
          'type': 'debit',
          'amount': 299,
          'description': t('رسوم الاشتراك الشهري', 'Monthly subscription fee'),
          'status': 'completed',
          'created_at': '2026-09-20 00:00:00',
        },
        {
          'id': 899,
          'type': 'credit',
          'amount': 2000,
          'description': t('شحن قيد المراجعة', 'Top-up under review'),
          'status': 'pending',
          'created_at': '2026-09-19 14:40:00',
        },
        {
          'id': 898,
          'type': 'debit',
          'amount': 184.5,
          'description': t('عمولة الطلب PO-20260915-D8E1', 'Commission on PO-20260915-D8E1'),
          'status': 'completed',
          'created_at': '2026-09-16 09:00:00',
        },
      ];

  List<Map<String, dynamic>> get topupMethods => [
        {'code': 'bank_transfer', 'label_ar': 'تحويل بنكي', 'label_en': 'Bank transfer', 'enabled': true},
        {'code': 'hyperpay', 'label_ar': 'بطاقة مدى / فيزا', 'label_en': 'mada / Visa card', 'enabled': true},
      ];

  Map<String, dynamic> get subscription => {
        'summary': {
          'status': 'active',
          'billing_mode': 'subscription',
          'plan_id': 2,
          'plan_name': t('الباقة الاحترافية', 'Professional'),
          'renews_at': '2026-10-20 00:00:00',
        },
      };

  List<Map<String, dynamic>> get plans => [
        {
          'id': 1,
          'name_ar': 'الباقة الأساسية',
          'name_en': 'Starter',
          'monthly_price': 99,
          'yearly_price': 990,
          'currency_code': 'SAR',
        },
        {
          'id': 2,
          'name_ar': 'الباقة الاحترافية',
          'name_en': 'Professional',
          'monthly_price': 299,
          'yearly_price': 2990,
          'currency_code': 'SAR',
        },
        {
          'id': 3,
          'name_ar': 'باقة المؤسسات',
          'name_en': 'Enterprise',
          'monthly_price': 899,
          'yearly_price': 8990,
          'currency_code': 'SAR',
        },
      ];

  List<Map<String, dynamic>> get biometricDevices => [
        {
          'id': 1,
          'device_id': 'a1b2',
          'device_name': 'iPhone 15 Pro',
          'device_platform': 'ios',
          'biometric_type': 'face',
          'created_at': '2026-06-02 12:00:00',
          'last_used_at': '2026-09-24 08:00:00',
        },
        {
          'id': 2,
          'device_id': 'c3d4',
          'device_name': 'Galaxy S24',
          'device_platform': 'android',
          'biometric_type': 'fingerprint',
          'created_at': '2026-08-11 18:30:00',
          'last_used_at': '2026-09-20 21:10:00',
        },
      ];

  // ------------------------------------------------------------- onboarding

  Map<String, dynamic> get onboarding => {
        'organization': {
          'id': 3,
          'display_name': alfaisal['name'],
          'legal_name_ar': 'مؤسسة الفيصل التجارية',
          'legal_name_en': 'Al-Faisal Trading Est.',
          'trade_name': t('الفيصل', 'Al-Faisal'),
          'commercial_reg_no': '1010456789',
          'vat_no': '300456789100003',
          'country_id': 1,
          'city_id': 2,
          'business_mode': 'hybrid',
          'status': 'draft',
          'is_owner': true,
          'approved_workspaces': ['trader'],
        },
        'journey': {
          'state': 'collecting',
          'state_label': t('بانتظار مستنداتك', 'Awaiting your documents'),
          'next_best_action': t(
            'أضف حساباً بنكياً باسم المنشأة لإكمال ملف المورد.',
            'Add a bank account in the organization name to finish the supplier profile.',
          ),
          'profiles_ready': 1,
          'profiles_pending': 1,
          'trader': {'status': 'active', 'score': 92, 'missing': <String>[]},
          'supplier': {
            'status': 'draft',
            'score': 64,
            'missing': [
              t('مطلوب حساب بنكي باسم المنشأة.', 'A bank account in the organization name is required.'),
              t('انتهت صلاحية شهادة ضريبة القيمة المضافة.', 'The VAT certificate has expired.'),
            ],
          },
        },
        'profiles': [
          {'id': 1, 'profile_type': 'trader', 'status': 'active'},
          {'id': 2, 'profile_type': 'supplier', 'status': 'draft', 'supplier_nature': 'both'},
        ],
      };

  List<Map<String, dynamic>> get branches => [
        {
          'id': 80,
          'type': 'main',
          'name_ar': 'فرع العليا',
          'name_en': 'Olaya branch',
          'address_text': t('طريق العليا، الرياض', 'Olaya Rd, Riyadh'),
          'is_default': true,
          'status': 'active',
        },
        {
          'id': 81,
          'type': 'warehouse',
          'name_ar': 'مستودع السلي',
          'name_en': 'Al-Sulay warehouse',
          'address_text': t('حي السلي، الرياض', 'Al-Sulay, Riyadh'),
          'status': 'active',
        },
      ];

  List<Map<String, dynamic>> get documents => [
        {
          'id': 1,
          'document_type': 'commercial_registration',
          'file_path': 'org/3/cr.pdf',
          'issued_at': '2025-02-10 00:00:00',
          'expires_at': '2027-02-09 00:00:00',
          'status': 'approved',
          'notes': t('السجل التجاري الرئيسي', 'Main commercial registration'),
        },
        {
          'id': 2,
          'document_type': 'vat_certificate',
          'file_path': 'org/3/vat.pdf',
          'issued_at': '2024-08-01 00:00:00',
          'expires_at': '2026-08-01 00:00:00',
          'status': 'rejected',
        },
        {
          'id': 3,
          'document_type': 'national_address',
          'file_path': 'org/3/address.pdf',
          'issued_at': '2026-09-01 00:00:00',
          'status': 'pending',
        },
      ];

  // ------------------------------------------------------------------- shop

  Map<String, dynamic> _shopProduct(int id, String ar, String en, num price,
          {num sale = 0, int count = 40, bool fav = false, bool cart = false}) =>
      {
        'id': id,
        'type': 'static',
        'name': t(ar, en),
        'image': '',
        'price_meta': {
          'price': price,
          'sale_price': sale,
          'sale': sale > 0,
          'sale_till': sale > 0 ? '2026-09-30 23:59:59' : '',
          'count': count,
        },
        'is_favorite': fav,
        'is_cart': cart,
      };

  List<Map<String, dynamic>> get shopProducts => [
        _shopProduct(11, 'قهوة عربية محمصة', 'Roasted Arabic coffee', 65, sale: 52, fav: true),
        _shopProduct(12, 'زعفران إيراني ٥ جم', 'Saffron 5 g', 48),
        _shopProduct(13, 'عسل سدر جبلي', 'Mountain Sidr honey', 180, cart: true),
        _shopProduct(14, 'هيل حب أخضر', 'Green cardamom', 72, sale: 60),
        _shopProduct(15, 'دلة قهوة نحاسية', 'Copper dallah', 145, count: 0),
        _shopProduct(16, 'تمر سكري مفتل', 'Sukkari dates', 55),
      ];

  Map<String, dynamic> get shopHome => {
        'sliders': [
          {'url': '', 'image': ''},
          {'url': '', 'image': ''},
          {'url': '', 'image': ''},
        ],
        'categories': [
          {'id': 1, 'name': t('القهوة والشاي', 'Coffee & tea'), 'image': '', 'subs': true},
          {'id': 2, 'name': t('التمور', 'Dates'), 'image': '', 'subs': true},
          {'id': 3, 'name': t('البهارات', 'Spices'), 'image': '', 'subs': false, 'type': 'sec'},
          {'id': 4, 'name': t('العسل', 'Honey'), 'image': '', 'subs': false, 'type': 'sec'},
          {'id': 5, 'name': t('أدوات الضيافة', 'Hospitality'), 'image': '', 'subs': true},
        ],
        'best_selling': shopProducts.sublist(0, 4),
        'most_viewed': shopProducts.sublist(2, 6),
        'discount': [shopProducts[0], shopProducts[3]],
        'cart_count': 2,
      };

  Map<String, dynamic> get cart => {
        'carts': {
          'data': [
            {
              'id': 301,
              'product_id': 13,
              'product_variation_id': 0,
              'count': 2,
              'price': 180,
              'product': shopProducts[2],
            },
            {
              'id': 302,
              'product_id': 11,
              'product_variation_id': 0,
              'count': 3,
              'price': 52,
              'product': shopProducts[0],
            },
            {
              'id': 303,
              'product_id': 16,
              'product_variation_id': 0,
              'count': 1,
              'price': 55,
              'product': shopProducts[5],
            },
          ],
        },
        'totals': {'total': 571, 'tax': 74.48, 'cart': 496.52},
        'addresses': [
          {'id': 1, 'text': t('الرياض، حي الملقا، شارع أنس بن مالك', 'Riyadh, Al-Malqa, Anas bin Malik St')},
          {'id': 2, 'text': t('جدة، حي الروضة', 'Jeddah, Al-Rawdah')},
        ],
      };

  Map<String, dynamic> get shopProductDetail => {
        'product': {
          ...shopProducts.first,
          'rate': 4.6,
          'desc': t(
            'قهوة عربية خفيفة التحميص من مزارع جازان، مطحونة طازجة ومعبأة في أكياس محكمة.',
            'Light-roast Arabic coffee from Jazan farms, freshly ground and sealed.',
          ),
          'category': {'id': 1, 'name': t('القهوة والشاي', 'Coffee & tea'), 'image': ''},
          'images': <Map<String, dynamic>>[],
        },
        'seller': {
          'id': 90,
          'first_name': t('محمصة', 'Jazan'),
          'last_name': t('جازان', 'Roastery'),
          'image': '',
          'phone': 'm_p0559876543',
          'company_name': t('محمصة جازان', 'Jazan Roastery'),
        },
        'similars': shopProducts.sublist(3, 6),
      };
}

// ---------------------------------------------------------------------------
// The fake backend
// ---------------------------------------------------------------------------

const _panel = {
  'workspace': 'trader',
  'kpis': <Object>[],
  'attention': <Object>[],
  'quick_actions': <Object>[],
  'document_groups': <Object>[],
};

const _notifications = {
  'current_page': 1,
  'last_page': 1,
  'per_page': 20,
  'total': 0,
  'unread_count': 2,
  'data': <Object>[],
};

/// Routes by path. The more specific patterns come first so
/// `/v2/relationships/51/credit` is not answered as the list.
(int, Object?) _route(_Fixtures f, RequestOptions o) {
  final path = o.path;
  final query = o.queryParameters;
  bool at(String pattern) => RegExp('^$pattern\$').hasMatch(path);

  List<Map<String, dynamic>> byStatus(List<Map<String, dynamic>> rows) {
    final raw = query['status'];
    if (raw == null || '$raw'.isEmpty) return rows;
    final wanted = '$raw'.split(',');
    return rows.where((row) => wanted.contains(row['status'])).toList();
  }

  // shell plumbing
  if (path.contains('ops/panel')) return (200, {..._panel, 'workspace': query['workspace'] ?? 'trader'});
  if (at('/v2/notifications')) return (200, _notifications);
  // The workspace switch re-reads the theme and quick actions.
  if (at('/v2/ops/quick_actions')) return (200, const {'theme': {}, 'quick_actions': []});

  // orders
  if (at('/v2/purchase_orders')) {
    final rows = query['role'] == 'supplier' ? f.supplierOrders : f.traderOrders;
    return (200, _paged(byStatus(rows)));
  }
  if (at(r'/v2/purchase_orders/\d+')) return (200, {'purchase_order': f.orderDetail});
  if (at(r'/v2/purchase_orders/\d+/timeline')) {
    return (200, {'timeline': f.orderDetail['timeline']});
  }
  if (at('/v2/purchase_drafts')) return (200, {'draft': f.draft});
  if (at(r'/v2/purchase_drafts/\d+')) return (200, {'draft': f.draft});
  if (at('/v2/pricing/payment_terms')) return (200, {'payment_terms': f.paymentTerms});

  // suppliers and catalog
  if (at('/v2/catalog/suppliers')) return (200, _paged(f.suppliers));
  if (at(r'/v2/catalog/suppliers/\d+')) return (200, {'supplier': f.suppliers.first});
  if (at(r'/v2/suppliers/\d+/follow')) return (200, {'is_following': true});
  if (at(r'/v2/suppliers/\d+/public_catalog')) {
    return (200, {'items': f.products.where((p) => (p['supplier'] as Map)['id'] == 7).toList()});
  }
  if (at('/v2/catalog/products')) return (200, _paged(f.products));

  // shipments
  if (at('/v2/delivery_notes')) return (200, _paged(byStatus(f.deliveryNotes)));
  if (at(r'/v2/delivery_notes/\d+/tracking')) return (200, {'delivery_note': f.tracking});
  if (at(r'/v2/delivery_notes/\d+')) return (200, {'delivery_note': f.outboundDetail});

  // receivables
  if (at('/v2/invoices')) return (200, _paged(byStatus(f.invoices)));
  if (at(r'/v2/invoices/\d+')) return (200, {'invoice': f.invoiceDetail});
  if (at('/v2/collections')) {
    final invoiceId = query['invoice_id'];
    final rows = invoiceId == null
        ? f.collections
        : f.collections.where((c) => '${c['invoice_id']}' == '$invoiceId').toList();
    return (200, _paged(byStatus(rows)));
  }
  if (at('/v2/post_invoice_returns')) return (200, _paged(byStatus(f.returns)));

  // supplier tools
  if (at('/v2/relationships')) return (200, _paged(byStatus(f.relationships)));
  if (at(r'/v2/relationships/\d+/credit')) return (200, f.credit);
  if (at('/v2/pricing/price_lists')) return (200, _paged(f.priceLists));

  // advanced
  if (at('/v2/contracts')) return (200, _paged(byStatus(f.contracts)));
  if (at('/v2/wallet')) return (200, f.wallet);
  if (at('/v2/wallet/transactions')) {
    return (200, _paged(f.walletTransactions, formatted: false));
  }
  if (at('/v2/wallet/topup_methods')) return (200, {'methods': f.topupMethods});
  if (at('/v2/subscription/current')) return (200, f.subscription);
  if (at('/v2/subscription/plans')) return (200, {'plans': f.plans});
  // "Nothing pending" is a 404 on this endpoint.
  if (at('/v2/account/deletion_request')) return (404, {'status': 'failed', 'msg': 'not_found'});
  if (at('/v2/biometric/credentials')) return (200, {'credentials': f.biometricDevices});

  // onboarding
  if (at('/v2/onboarding/bootstrap')) return (200, f.onboarding);
  if (at('/v2/b2b/owner-console/branches')) return (200, {'items': f.branches});
  if (at('/v2/b2b/owner-console/bank_accounts')) return (200, {'items': <Object>[]});
  if (at('/v2/b2b/owner-console/documents')) return (200, {'items': f.documents});

  // v1 marketplace
  if (at('/home')) return (200, f.shopHome);
  if (at('/cart')) return (200, f.cart);
  if (at(r'/products/\d+')) return (200, f.shopProductDetail);

  // Anything unrouted is logged so a missing fixture is visible in the run.
  // ignore: avoid_print
  print('UNROUTED ${o.method} $path $query');
  return (200, const {'theme': {}, 'quick_actions': []});
}

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

class _Screen {
  final String name;
  final Workspace workspace;
  final Widget Function() build;

  const _Screen(this.name, this.build, {this.workspace = Workspace.trader});
}

final _screens = <_Screen>[
  _Screen('pushed-orders', () => const OrdersView()),
  _Screen('pushed-order-detail', () => const OrderDetailView(orderId: 1)),
  _Screen('pushed-suppliers', () => const SuppliersView()),
  _Screen('pushed-supplier-detail', () => const SupplierDetailView(supplierOrganizationId: 7)),
  _Screen('pushed-catalog', () => const ProductsView()),
  _Screen('pushed-draft',
      () => const DraftEditorView(supplierOrganizationId: 7, relationshipId: 47)),
  _Screen('pushed-shipments', () => const ShipmentsView()),
  _Screen('pushed-tracking', () => const ShipmentTrackingView(deliveryNoteId: 5)),
  _Screen('pushed-invoices', () => const InvoicesView()),
  _Screen('pushed-invoice-detail', () => const InvoiceDetailView(invoiceId: 1)),
  _Screen('pushed-inbox', () => const OrdersInboxView(), workspace: Workspace.supplier),
  _Screen('pushed-outbound-detail', () => const OutboundDetailView(deliveryNoteId: 5),
      workspace: Workspace.supplier),
  _Screen('pushed-collections', () => const CollectionsInboxView(),
      workspace: Workspace.supplier),
  _Screen('pushed-returns-inbox', () => const ReturnsInboxView(), workspace: Workspace.supplier),
  _Screen('pushed-relationships', () => const RelationshipsView(),
      workspace: Workspace.supplier),
  _Screen('pushed-credit', () => const CreditView(relationshipId: 51),
      workspace: Workspace.supplier),
  _Screen('pushed-pricing', () => const PriceListsView(), workspace: Workspace.supplier),
  _Screen('pushed-shop', () => const ShopHomeView()),
  _Screen('pushed-cart', () => const ShopCartView()),
  _Screen('pushed-product', () => const ShopProductView(productId: 11)),
  _Screen('pushed-contracts', () => const ContractsView()),
  _Screen('pushed-wallet', () => const WalletView()),
  _Screen('pushed-subscription', () => const SubscriptionView()),
  _Screen('pushed-onboarding', () => const OnboardingWizardView()),
  _Screen('pushed-account', () => const AccountSettingsView()),
  _Screen('pushed-documents', () => const DocumentsView()),
];

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
    required Widget screen,
  }) async {
    final fixtures = _Fixtures(locale);
    final adapter = FakeAdapter((options) async {
      final (status, body) = _route(fixtures, options);
      return jsonBody(body, status: status);
    });
    final (client, _) = clientWith(adapter, context: FakeAuthContext(locale: locale));

    final store = SessionStore();
    final ops = OpsRepository(client);
    final bootstrap = BootstrapRepository(client);
    final auth = AuthRepository(client);
    final workspaceCubit = WorkspaceCubit(store, ops);
    final push = PushService(auth, bootstrap, store);
    final session = SessionCubit(store, bootstrap, workspaceCubit, push);
    final notificationsRepo = NotificationsRepository(client);
    final notifications = NotificationsCubit(notificationsRepo);

    await getIt.reset();
    getIt
      ..registerSingleton<SessionStore>(store)
      ..registerSingleton(client)
      ..registerSingleton<AuthRepository>(auth)
      ..registerSingleton<BootstrapRepository>(bootstrap)
      ..registerSingleton<OnboardingRepository>(OnboardingRepository(client))
      ..registerSingleton<NotificationsRepository>(notificationsRepo)
      ..registerSingleton<LookupsRepository>(LookupsRepository(client))
      ..registerSingleton<CatalogRepository>(CatalogRepository(client))
      ..registerSingleton<OrdersRepository>(OrdersRepository(client))
      ..registerSingleton<ShipmentsRepository>(ShipmentsRepository(client))
      ..registerSingleton<ReceivablesRepository>(ReceivablesRepository(client))
      ..registerSingleton<UploadsRepository>(UploadsRepository(client))
      ..registerSingleton<SupplierRepository>(SupplierRepository(client))
      ..registerSingleton<ContractsRepository>(ContractsRepository(client))
      ..registerSingleton<AccountRepository>(AccountRepository(client))
      ..registerSingleton<ShopRepository>(ShopRepository(client))
      ..registerSingleton<OpsRepository>(ops)
      ..registerSingleton<PushService>(push)
      ..registerSingleton<WorkspaceCubit>(workspaceCubit)
      ..registerSingleton<SessionCubit>(session)
      ..registerSingleton<NotificationsCubit>(notifications);

    await workspaceCubit.hydrate(Organization.fromJson(const {
      'id': 3,
      'display_name': 'مؤسسة الفيصل التجارية',
      'business_mode': 'hybrid',
      'is_owner': true,
      'approved_workspaces': ['trader', 'supplier'],
    }));
    if (workspaceCubit.state?.active != workspace) await workspaceCubit.switchTo(workspace);
    await notifications.load();

    final theme = buildAppTheme(
      ThemeTokens.fallbackFor(workspace),
      locale,
      brightness: brightness,
    );
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
            home: screen,
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  const variants = [
    ('ar', Brightness.light, 'ar'),
    ('en', Brightness.dark, 'en-dark'),
  ];

  for (final screen in _screens) {
    for (final (locale, brightness, suffix) in variants) {
      testWidgets('${screen.name}-$suffix', skip: !_goldens, (tester) async {
        tester.view
          ..physicalSize = const Size(390 * 2, 844 * 2)
          ..devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.runAsync(() async {
          final root = await app(
            locale: locale,
            brightness: brightness,
            workspace: screen.workspace,
            screen: screen.build(),
          );
          await tester.pumpWidget(root);
        });
        await settle(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${screen.name}-$suffix.png'),
        );
        // Unmount inside the test so pollers (tracking) cancel their timers.
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
