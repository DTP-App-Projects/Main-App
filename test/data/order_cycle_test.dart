import 'package:digital_trade_portal/core/deeplink/deep_link.dart';
import 'package:digital_trade_portal/core/deeplink/deep_link_router.dart';
import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/data/models/trade/catalog.dart';
import 'package:digital_trade_portal/data/models/trade/delivery_note.dart';
import 'package:digital_trade_portal/data/models/trade/document_flow.dart';
import 'package:digital_trade_portal/data/models/trade/payment_notice.dart';
import 'package:digital_trade_portal/data/repositories/catalog_repository.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/data/repositories/receivables_repository.dart';
import 'package:digital_trade_portal/data/repositories/shipments_repository.dart';
import 'package:digital_trade_portal/features/trader/drafts/view_models/draft_cubit.dart';
import 'package:digital_trade_portal/features/trader/orders/view_models/orders_cubits.dart';
import 'package:digital_trade_portal/features/trader/payables/view_models/payables_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// The full order cycle brief (2026-10-10): the submit's contract rules and
/// credit review, the refresh after every order action, the receipt edit
/// window, payment notices, the document chain and the push for a notice.
void main() {
  setUp(() async => useFakeStorage());

  group('draft submit', () {
    FakeAdapter server({
      int? branchId = 13,
      Map<String, dynamic>? submitBody,
      int submitStatus = 200,
    }) => FakeAdapter((options) async {
      if (options.path.endsWith('/submit')) {
        return jsonBody(submitBody ?? const {}, status: submitStatus);
      }
      if (options.path.contains('payment_terms')) return jsonBody(const {'items': []});
      return jsonBody({
        'draft': {
          'id': 90,
          'supplier_organization_id': 23,
          'delivery_branch_id': branchId,
          'lines': [
            {'id': 1, 'sku_id': 501, 'qty': 2},
            {'id': 2, 'sku_id': 502, 'qty': 1},
          ],
        },
      });
    });

    DraftCubit cubitOn(FakeAdapter adapter) {
      final (client, _) = clientWith(adapter);
      return DraftCubit(
        OrdersRepository(client),
        CatalogRepository(client),
        supplierOrganizationId: 23,
        draftId: 90,
      );
    }

    test('without a delivery branch the submit never reaches the server', () async {
      final adapter = server(branchId: null);
      final cubit = cubitOn(adapter);
      await cubit.start();

      final order = await cubit.submit();

      expect(order, isNull);
      expect(cubit.state.actionCode, 'delivery_branch_required');
      expect(adapter.requests.any((r) => r.path.endsWith('/submit')), isFalse);
      await cubit.close();
    });

    test('a refused submit keeps every rule and points at its line', () async {
      final cubit = cubitOn(
        server(
          submitStatus: 422,
          submitBody: const {
            'msg': 'contract_rules_failed',
            'message': 'The order breaks the contract rules.',
            'errors': [
              {
                'code': 'qty_below_contract_min',
                'message': 'At least 5',
                'sku_id': 501,
                'min_qty': 5,
              },
              {'code': 'contract_minimum_order_value', 'message': 'Order at least 1000'},
            ],
            'draft': {'id': 90},
          },
        ),
      );
      await cubit.start();

      await cubit.submit();

      expect(cubit.state.ruleErrors, hasLength(2));
      expect(cubit.state.actionCode, 'contract_rules_failed');
      expect(cubit.errorsForSku(501).single.minQty, 5);
      expect(cubit.errorsForSku(502), isEmpty);
      expect(cubit.state.action.message, 'The order breaks the contract rules.');
      await cubit.close();
    });

    test('a manual credit review still creates the order, flagged as a hold', () async {
      final cubit = cubitOn(
        server(
          submitBody: const {
            'purchase_order': {'id': 300, 'code': 'PO-1', 'grand_total': 1150},
            'credit_review': {
              'status': 'manual_review',
              'reason_code': 'credit_limit_exceeded',
              'message': 'Waiting for credit review',
              'available_before': 1000,
              'available_after': -150,
            },
          },
        ),
      );
      await cubit.start();

      final order = await cubit.submit();

      expect(order?.code, 'PO-1');
      expect(order?.grandTotal, 1150, reason: "the server's totals, not the draft's");
      expect(cubit.state.creditReview?.isHold, isTrue);
      expect(cubit.state.creditReview?.availableAfter, -150);
      await cubit.close();
    });
  });

  test('an order action is followed by a fresh read of the order and its timeline', () async {
    final (client, adapter) = clientWith(
      FakeAdapter((options) async {
        if (options.method == 'PATCH') {
          return jsonBody(const {
            'purchase_order': {'id': 7, 'status': 'stale'},
          });
        }
        if (options.path.endsWith('/timeline')) {
          return jsonBody(const {
            'timeline': [
              {'event': 'cancel_request.rejected', 'note': 'Already loaded'},
            ],
          });
        }
        if (options.path.contains('document_flow')) {
          return jsonBody(const {
            'document': {'entity_type': 'purchase_order', 'id': 7},
            'delivery_notes': [
              {'id': 20, 'code': 'DN-20', 'status': 'dispatched'},
            ],
          });
        }
        return jsonBody(const {
          'purchase_order': {'id': 7, 'status': 'approved'},
        });
      }),
    );
    final cubit = OrderDetailCubit(OrdersRepository(client), 7);
    await cubit.load();
    adapter.requests.clear();

    final ok = await cubit.changeStatus('ready');

    expect(ok, isTrue);
    expect(cubit.state.order?.status, 'approved', reason: 'the PATCH answer is not trusted');
    expect(adapter.requests.map((r) => r.method).toList(), ['PATCH', 'GET', 'GET', 'GET']);
    expect(cubit.timeline.single.description, 'Already loaded');
    expect(cubit.state.flow.related.single.code, 'DN-20');
    await cubit.close();
  });

  group('edit window', () {
    test('reads nested or flat, with an end time or a remaining count', () {
      final nested = EditWindow.fromJson(const {
        'edit_window': {'is_open': true, 'ends_at': '2099-01-01T10:00:00+03:00'},
      });
      final flat = EditWindow.fromJson(const {'open': true, 'remaining_seconds': 600});
      final closed = EditWindow.fromJson(const {'status': 'closed'});

      expect(nested.isOpenAt(DateTime.now()), isTrue);
      expect(flat.endsAt, isNotNull);
      expect(closed.isOpen, isFalse);
    });

    test('a correction posts the receipt line ids and only what changed', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'status': 'ok'}));

      await ShipmentsRepository(client).adjustReceipt(
        deliveryNoteId: 20,
        adjustments: const [ReceiptAdjustment(lineId: 3, receivedQty: 8)],
      );
      final request = adapter.requests.single;

      expect(request.path, endsWith('/delivery_notes/20/edit_window/adjust'));
      expect(request.data, {
        'adjustments': [
          {'line_id': 3, 'received_qty': 8.0},
        ],
      });
    });

    test('its {status, message} errors keep their code', () async {
      final (client, _) = clientWith(
        FakeAdapter.json(const {'status': 404, 'message': 'delivery_note_not_found'}, status: 404),
      );

      final result = await ShipmentsRepository(client).editWindow(20);

      expect(result, isA<Failed<EditWindow>>());
      expect((result as Failed<EditWindow>).code, 'delivery_note_not_found');
    });
  });

  group('payment notices', () {
    test("the trader's notice is what «سداد» sends, then the invoice is re-read", () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.method == 'POST') {
            return jsonBody(const {
              'payment_notice': {'id': 5, 'status': 'submitted'},
            });
          }
          if (options.path.endsWith('/payment_notices')) {
            return jsonBody(const {
              'current_page': 1,
              'last_page': 1,
              'data': [
                {
                  'id': 99,
                  'formatted': {
                    'id': 5,
                    'status': 'submitted',
                    'amount': '500.00',
                    'can_review': false,
                  },
                },
              ],
            });
          }
          if (options.path.contains('/collections')) return jsonBody(const {'data': []});
          return jsonBody(const {
            'invoice': {'id': 40, 'outstanding_amount': 500},
          });
        }),
      );
      final cubit = InvoiceDetailCubit(ReceivablesRepository(client), 40);

      final ok = await cubit.sendNotice(
        amount: 500,
        paymentMethod: 'transfer',
        paidAt: DateTime(2026, 10, 5),
        dueScheduleId: 8,
        proofFile: 'uploads/proof.jpg',
      );
      final post = adapter.requests.firstWhere((r) => r.method == 'POST');

      expect(ok, isTrue);
      expect(post.path, endsWith('/v2/payment_notices'));
      expect(post.data, {
        'invoice_id': 40,
        'due_schedule_id': 8,
        'payment_method': 'transfer',
        'amount': 500.0,
        'paid_at': '2026-10-05',
        'proof_file': 'uploads/proof.jpg',
      });
      expect(cubit.state.notices.single.id, 5, reason: 'rows are read from `formatted`');
      expect(cubit.state.notices.single.isPending, isTrue);
      await cubit.close();
    });

    test('the supplier filters by status and reviews with a note', () async {
      final (client, adapter) = clientWith(
        FakeAdapter.json(const {
          'payment_notice': {'id': 5, 'status': 'rejected'},
        }),
      );
      final repo = ReceivablesRepository(client);

      await repo.paymentNotices(statuses: const ['submitted'], invoiceId: 40);
      final rejected = await repo.reviewPaymentNotice(
        id: 5,
        status: 'rejected',
        reviewNote: 'No transfer found',
      );

      expect(adapter.requests.first.queryParameters['status'], 'submitted');
      expect(adapter.requests.first.queryParameters['invoice_id'], 40);
      expect(adapter.requests.last.path, endsWith('/payment_notices/5/status'));
      expect(adapter.requests.last.data, {
        'status': 'rejected',
        'review_note': 'No transfer found',
      });
      expect(rejected.dataOrNull?.status, 'rejected');
    });

    test('a notice reads its review fields', () {
      final notice = PaymentNotice.fromJson(const {
        'id': 5,
        'status': 'confirmed',
        'viewer_side': 'supplier',
        'can_review': false,
        'proof_url': 'https://tacaml.com/storage/p.jpg',
        'review_note': 'Received',
        'collection_receipt_id': 12,
        'invoice': {'id': 40, 'invoice_no': 'INV-40'},
      });

      expect(notice.collectionReceiptId, 12);
      expect(notice.invoiceId, 40);
      expect(notice.invoiceNo, 'INV-40');
      expect(notice.isPending, isFalse);
    });

    test("a payment notice push opens the trader's invoice at that notice", () {
      String? path(Map<String, dynamic> data) => DeepLinkRouter.pathFor(DeepLink.fromData(data));

      expect(
        path({
          'click_action': 'invoice',
          'entity_type': 'invoice',
          'entity_id': '40',
          'payment_notice_id': '5',
          'event_code': 'payment_notice.rejected',
          'side': 'trader',
        }),
        '/trader/invoices/40?notice=5',
      );
      expect(
        path({
          'click_action': 'invoice',
          'entity_id': '40',
          'payment_notice_id': '5',
          'event_code': 'payment_notice.submitted',
          'side': 'supplier',
        }),
        '/compliance/invoices/40',
      );
    });
  });

  test('the document chain reads lists and groups, without duplicates', () {
    final flow = DocumentFlow.fromJson(const {
      'document': {'entity_type': 'purchase_order', 'id': 7},
      'flow': [
        {'entity_type': 'purchase_order', 'entity_id': 7},
        {'entity_type': 'delivery_note', 'entity_id': 20, 'code': 'DN-20'},
      ],
      'delivery_notes': [
        {'id': 20},
      ],
      'invoices': [
        {'id': 40, 'invoice_no': 'INV-40', 'status': 'issued'},
      ],
      'unrelated': {'id': 1},
    });

    expect(flow.related.map((d) => d.key), ['delivery_note:20', 'invoice:40']);
    expect(flow.related.last.code, 'INV-40');
  });

  test("a public catalog row opens its product by product_id, not the row's id", () {
    final row = Product.fromJson(const {'id': 3, 'product_id': 41, 'name': 'Rice'});
    final plain = Product.fromJson(const {'id': 41, 'name': 'Rice'});

    expect(row.detailId, 41);
    expect(plain.detailId, 41);
  });
}
