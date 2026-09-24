import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/trade/catalog.dart';
import 'package:digital_trade_portal/data/models/trade/delivery_note.dart';
import 'package:digital_trade_portal/data/repositories/catalog_repository.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/data/repositories/receivables_repository.dart';
import 'package:digital_trade_portal/data/repositories/shipments_repository.dart';
import 'package:digital_trade_portal/features/trader/drafts/view_models/draft_cubit.dart';
import 'package:digital_trade_portal/features/trader/receipts/view_models/goods_receipt_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
  group('workspace scoping of list calls', () {
    test('orders always send role, and statuses go comma-separated', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      final repo = OrdersRepository(client);

      await repo.orders(
        role: Workspace.trader,
        statuses: ['submitted', 'under_review'],
      );

      final query = adapter.requests.single.queryParameters;
      // Omitting `role` merges a hybrid organization's two sides into one
      // list; omitting it is never correct here.
      expect(query['role'], 'trader');
      expect(query['status'], 'submitted,under_review');
      expect(query['limit'], 15);
    });

    test('an empty status filter sends no status param at all', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      await OrdersRepository(client).orders(role: Workspace.trader);

      expect(adapter.requests.single.queryParameters.containsKey('status'), isFalse);
    });

    test('shipments and invoices carry role too', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));

      await ShipmentsRepository(client).deliveryNotes(role: Workspace.trader);
      await ReceivablesRepository(client).invoices(role: Workspace.trader);

      for (final request in adapter.requests) {
        expect(request.queryParameters['role'], 'trader', reason: request.path);
      }
    });

    test('tracking opts out of de-duplication so a poll is never stale', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'delivery_note': {}}));
      final repo = ShipmentsRepository(client);

      await Future.wait([repo.tracking(5), repo.tracking(5)]);

      // Two polls, two requests — collapsing them would freeze the screen on
      // one snapshot.
      expect(adapter.requests.length, 2);
    });
  });

  group('draft upserts', () {
    test('a create omits draft_id and an edit carries it', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'draft': {'id': 4}}));
      final repo = OrdersRepository(client);

      await repo.saveDraft(supplierOrganizationId: 7);
      await repo.saveDraft(draftId: 4, supplierOrganizationId: 7);

      expect((adapter.requests.first.data as Map).containsKey('draft_id'), isFalse);
      expect((adapter.requests.last.data as Map)['draft_id'], 4);
    });

    test('a claim sends the schedule instead of the invoice when given one',
        () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'collection_receipt': {'id': 1}}));
      final repo = ReceivablesRepository(client);

      await repo.claimPayment(amount: 100, dueScheduleId: 12);
      final body = adapter.requests.single.data as Map;

      // One of the two is required; sending both would be ambiguous.
      expect(body['due_schedule_id'], 12);
      expect(body.containsKey('invoice_id'), isFalse);
      expect(body['amount'], 100);
    });
  });

  group('DraftCubit', () {
    Sku sku({double min = 0, double step = 0}) => Sku.fromJson({
          'id': 55,
          'sku_code': 'SKU-55',
          'min_order_qty': min,
          'order_step_qty': step,
        });

    DraftCubit cubitWith(FakeAdapter adapter) {
      final (client, _) = clientWith(adapter);
      return DraftCubit(
        OrdersRepository(client),
        CatalogRepository(client),
        supplierOrganizationId: 7,
        draftId: 4,
      );
    }

    test('a quantity the SKU forbids never reaches the network', () async {
      final adapter = FakeAdapter.json(const {'draft': {'id': 4}});
      final cubit = cubitWith(adapter);
      await cubit.start();
      final before = adapter.requests.length;

      final rejection = await cubit.addLine(sku: sku(min: 10), qty: 5);

      expect(rejection, 'qty_less_than_min_order_qty');
      expect(adapter.requests.length, before, reason: 'no request should be sent');
      expect(cubit.state.lineError, isNotNull);
    });

    /// Routes by path rather than by call order: `start()` reads the draft
    /// *and* the payment terms, so counting requests is brittle.
    FakeAdapter routed({
      required bool priced,
      Map<String, dynamic>? addLineError,
      Map<String, dynamic> draft = const {'draft': {'id': 4}},
    }) =>
        FakeAdapter((options) async {
          if (options.path.contains('/pricing/resolve')) {
            return FakeAdapter.json({
              'sku_id': 55,
              'pricing': {'matched': priced, 'final_price': 10.0},
            }).handler(options);
          }
          if (options.path.contains('/lines')) {
            if (addLineError != null) {
              return FakeAdapter.json(addLineError, status: 400).handler(options);
            }
            return FakeAdapter.json(draft).handler(options);
          }
          if (options.path.contains('payment_terms')) {
            return FakeAdapter.json(const {'payment_terms': []}).handler(options);
          }
          return FakeAdapter.json(draft).handler(options);
        });

    test('an unpriced SKU is blocked before the add is attempted', () async {
      final adapter = routed(priced: false);
      final cubit = cubitWith(adapter);
      await cubit.start();

      final rejection = await cubit.addLine(sku: sku(), qty: 5);

      expect(rejection, 'pricing_not_found_for_sku');
      expect(cubit.state.lineError, isNotNull);
      // The add itself was never attempted.
      expect(
        adapter.requests.any((r) => r.path.contains('/lines')),
        isFalse,
      );
    });

    test('a priced, valid line is added and the draft comes back', () async {
      final cubit = cubitWith(routed(
        priced: true,
        draft: const {
          'draft': {
            'id': 4,
            'lines': [
              {'id': 1, 'sku_id': 55, 'qty': 5, 'line_total': 50.0},
            ],
          },
        },
      ));
      await cubit.start();

      final rejection = await cubit.addLine(sku: sku(), qty: 5);

      expect(rejection, isNull);
      expect(cubit.state.draft?.lines.length, 1);
      expect(cubit.state.lineError, isNull);
    });

    test('a server-side line rejection is surfaced verbatim', () async {
      final cubit = cubitWith(routed(
        priced: true,
        addLineError: const {'msg': 'insufficient_supplier_inventory'},
      ));
      await cubit.start();

      final rejection = await cubit.addLine(sku: sku(), qty: 5);

      expect(rejection, 'insufficient_supplier_inventory');
      expect(cubit.state.lineError, isNotNull);
    });
  });

  group('goods receipt counting', () {
    DeliveryLine line(double shipped) => DeliveryLine.fromJson({
          'id': 1,
          'sku_id': 9,
          'shipped_qty': shipped,
        });

    test('counting everything balances', () {
      final draft = ReceiptLineDraft(line: line(10), receivedQty: 10);
      expect(draft.balances, isTrue);
      expect(draft.unaccounted, 0);
    });

    test('received plus rejected must equal shipped', () {
      final draft = ReceiptLineDraft(line: line(10), receivedQty: 7, rejectedQty: 3);
      expect(draft.balances, isTrue);
    });

    test('a short count is flagged as unaccounted', () {
      final draft = ReceiptLineDraft(line: line(10), receivedQty: 7);
      expect(draft.balances, isFalse);
      expect(draft.unaccounted, 3);
    });

    test('a rejection without a reason blocks the submit', () {
      final draft = ReceiptLineDraft(line: line(10), receivedQty: 8, rejectedQty: 2);
      expect(draft.needsReason, isTrue);

      final withReason = draft.copyWith(rejectionReason: 'Damaged in transit');
      expect(withReason.needsReason, isFalse);
    });

    test('the form starts from "everything arrived"', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {
        'delivery_note': {
          'id': 5,
          'lines': [
            {'id': 1, 'sku_id': 9, 'shipped_qty': 12},
            {'id': 2, 'sku_id': 10, 'shipped_qty': 4},
          ],
        },
      }));
      final cubit = GoodsReceiptCubit(ShipmentsRepository(client), 5);

      await cubit.load();

      expect(cubit.state.lines.map((l) => l.receivedQty), [12, 4]);
      expect(cubit.state.hasMismatch, isFalse);
      expect(cubit.state.missingReason, isFalse);
    });
  });
}
