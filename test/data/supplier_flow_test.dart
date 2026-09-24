import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/trade/pricing.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/data/repositories/receivables_repository.dart';
import 'package:digital_trade_portal/data/repositories/shipments_repository.dart';
import 'package:digital_trade_portal/data/repositories/supplier_repository.dart';
import 'package:digital_trade_portal/features/trader/orders/view_models/orders_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

void main() {
  group('price list scopes', () {
    test('only default stands alone; every other scope points at something', () {
      expect(PriceList.scopeNeedsId('default'), isFalse);
      for (final scope in ['organization', 'relationship', 'contract', 'campaign']) {
        expect(PriceList.scopeNeedsId(scope), isTrue, reason: scope);
      }
    });

    test('a default list sends no scope_id at all', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'price_list': {'id': 1}}));
      final repo = SupplierRepository(client);

      await repo.savePriceList(scopeType: 'default', nameEn: 'Standard');
      final body = adapter.requests.single.data as Map;

      expect(body['scope_type'], 'default');
      expect(body.containsKey('scope_id'), isFalse);
    });

    test('a scoped list carries its target', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'price_list': {'id': 1}}));
      final repo = SupplierRepository(client);

      await repo.savePriceList(scopeType: 'relationship', scopeId: 12, nameEn: 'Acme');
      expect((adapter.requests.single.data as Map)['scope_id'], 12);
    });

    test('an upsert carries the id, a create does not', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'price_list': {'id': 1}}));
      final repo = SupplierRepository(client);

      await repo.savePriceList(scopeType: 'default');
      await repo.savePriceList(priceListId: 4, scopeType: 'default');

      expect((adapter.requests.first.data as Map).containsKey('price_list_id'), isFalse);
      expect((adapter.requests.last.data as Map)['price_list_id'], 4);
    });
  });

  group('SKU rules', () {
    test('only the fields the supplier changed are sent', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'sku': {'id': 9}}));
      final repo = SupplierRepository(client);

      await repo.updateSkuRules(productId: 3, skuId: 9, minOrderQty: 6, orderStepQty: 6);
      final body = adapter.requests.single.data as Map;

      expect(body['min_order_qty'], 6);
      expect(body['order_step_qty'], 6);
      // Untouched rules are left alone rather than blanked.
      expect(body.containsKey('pack_quantity'), isFalse);
      expect(body.containsKey('barcode'), isFalse);
      expect(adapter.requests.single.path, contains('/products/3/skus/9/rules'));
    });
  });

  group('credit profile', () {
    test('the freeze switches are what stop the next order', () {
      final frozen = CreditProfile.fromJson(const {
        'grade': 'B',
        'auto_freeze_on_limit': true,
        'auto_freeze_on_overdue': false,
      });
      final open = CreditProfile.fromJson(const {'grade': 'A'});

      expect(frozen.freezesAnything, isTrue);
      expect(open.freezesAnything, isFalse);
    });

    test('exposure flags overdue and an exhausted limit', () {
      final exposure = CreditExposure.fromJson(const {
        'overdue_amount': 1200,
        'available_credit': 0,
      });
      expect(exposure.hasOverdue, isTrue);
      expect(exposure.exhausted, isTrue);
    });

    test('the credit PUT carries the freeze flags', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'credit_profile': {'grade': 'B'}}));
      final repo = SupplierRepository(client);

      await repo.saveCredit(
        relationshipId: 12,
        grade: 'B',
        creditLimit: 50000,
        autoFreezeOnLimit: true,
        autoFreezeOnOverdue: false,
      );
      final body = adapter.requests.single.data as Map;

      expect(body['grade'], 'B');
      expect(body['credit_limit'], 50000);
      expect(body['auto_freeze_on_limit'], isTrue);
      expect(body['auto_freeze_on_overdue'], isFalse);
      expect(adapter.requests.single.path, contains('/relationships/12/credit'));
    });

    test('the credit snapshot splits profile from exposure', () {
      final snapshot = CreditSnapshot.fromJson(const {
        'relationship_id': 12,
        'credit_profile': {'grade': 'C', 'credit_limit': 1000},
        'credit_exposure': {'available_credit': 400},
      });
      expect(snapshot.profile?.grade, 'C');
      expect(snapshot.exposure?.availableCredit, 400);
    });
  });

  group('outbound shipment', () {
    test('seals go as a list of strings', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'delivery_note': {'id': 5}}));
      final repo = ShipmentsRepository(client);

      await repo.setSeals(id: 5, seals: ['SEAL-1', 'SEAL-2']);
      expect((adapter.requests.single.data as Map)['seals'], ['SEAL-1', 'SEAL-2']);
      expect(adapter.requests.single.path, endsWith('/delivery_notes/5/seals'));
    });

    test('dispatch is a status change, not its own verb', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'delivery_note': {'id': 5}}));
      final repo = ShipmentsRepository(client);

      await repo.changeDeliveryStatus(id: 5, status: 'dispatched');
      expect((adapter.requests.single.data as Map)['status'], 'dispatched');
      expect(adapter.requests.single.method, 'PATCH');
    });

    test('cancelling takes a code from the documented list', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final repo = ShipmentsRepository(client);

      await repo.cancelDelivery(id: 5, reason: 'out_of_stock', note: 'Nothing left');
      final body = adapter.requests.single.data as Map;

      expect(ShipmentsRepository.cancelReasons, contains(body['reason']));
      expect(body['note'], 'Nothing left');
    });

    test('rescheduling sends a plain day, not a timestamp', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'delivery_note': {'id': 5}}));
      final repo = ShipmentsRepository(client);

      await repo.reschedule(id: 5, routeDate: DateTime(2026, 9, 25, 14, 30));
      expect((adapter.requests.single.data as Map)['route_date'], '2026-09-25');
    });

    test('the dispatch board is never de-duplicated', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'deliveries': []}));
      final repo = ShipmentsRepository(client);

      await Future.wait([repo.supplierFleet(), repo.supplierFleet()]);
      expect(adapter.requests.length, 2);
    });

    test('a delivery note upsert carries the id only on an edit', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'delivery_note': {'id': 5}}));
      final repo = ShipmentsRepository(client);

      await repo.saveDeliveryNote(purchaseOrderId: 91);
      await repo.saveDeliveryNote(deliveryNoteId: 5, purchaseOrderId: 91);

      expect((adapter.requests.first.data as Map).containsKey('delivery_note_id'), isFalse);
      expect((adapter.requests.last.data as Map)['delivery_note_id'], 5);
    });
  });

  group('invoicing', () {
    test('a proforma never carries a delivery note', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'invoice': {'id': 1}}));
      final repo = ReceivablesRepository(client);

      await repo.issueProforma(
        purchaseOrderId: 91,
        invoiceDate: DateTime(2026, 9, 22),
      );
      final body = adapter.requests.single.data as Map;

      expect(adapter.requests.single.path, endsWith('/invoices/proforma'));
      expect(body.containsKey('delivery_note_id'), isFalse);
      expect(body['invoice_date'], '2026-09-22');
    });

    test('omitting lines invoices the whole delivery note', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'invoice': {'id': 1}}));
      final repo = ReceivablesRepository(client);

      await repo.issueInvoice(purchaseOrderId: 91, deliveryNoteId: 5);
      final body = adapter.requests.single.data as Map;

      expect(body['delivery_note_id'], 5);
      expect(body.containsKey('lines'), isFalse);
    });

    test('an instalment edit sends a plain day', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'due_schedule': {'id': 7}}));
      final repo = ReceivablesRepository(client);

      await repo.updateDueSchedule(
        id: 7,
        dueDate: DateTime(2026, 10, 22),
        dueAmount: 690,
      );
      final body = adapter.requests.single.data as Map;

      expect(body['due_date'], '2026-10-22');
      expect(body['due_amount'], 690);
    });
  });

  group('settling money', () {
    test('a claim is settled by a status change', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'collection_receipt': {'id': 3}}));
      final repo = ReceivablesRepository(client);

      await repo.decideCollection(id: 3, status: 'confirmed');
      expect((adapter.requests.single.data as Map)['status'], 'confirmed');
      expect(adapter.requests.single.path, endsWith('/collections/3/status'));
    });

    test('the supplier may record methods a trader cannot claim with', () {
      expect(ReceivablesRepository.supplierPaymentMethods, contains('gateway'));
      expect(ReceivablesRepository.traderPaymentMethods, isNot(contains('gateway')));
    });

    test('a supplier recording carries the bank account a claim cannot', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'collection_receipt': {'id': 3}}));
      final repo = ReceivablesRepository(client);

      await repo.recordCollection(amount: 500, invoiceId: 1, bankAccountId: 9);
      expect((adapter.requests.single.data as Map)['bank_account_id'], 9);
    });

    test('a return decision carries its reason', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'post_invoice_return': {'id': 4}}));
      final repo = ReceivablesRepository(client);

      await repo.decideReturn(id: 4, status: 'rejected', reason: 'Goods were used');
      final body = adapter.requests.single.data as Map;

      expect(body['status'], 'rejected');
      expect(body['reason'], 'Goods were used');
    });

    test('a debit note raises what is owed and a credit note lowers it', () {
      final credit = AdjustmentNote.fromJson(const {'id': 1, 'note_side': 'credit'});
      final debit = AdjustmentNote.fromJson(const {'id': 2, 'note_side': 'debit'});
      expect(credit.isCredit, isTrue);
      expect(debit.isCredit, isFalse);
    });
  });

  group('cancel request decision', () {
    test('accepting needs no note; rejecting sends one', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final repo = OrdersRepository(client);

      await repo.decideCancelRequest(id: 91, decision: 'accepted');
      await repo.decideCancelRequest(
        id: 91,
        decision: 'rejected',
        note: 'Already dispatched',
      );

      final accepted = adapter.requests.first.data as Map;
      final rejected = adapter.requests.last.data as Map;

      expect(accepted['decision'], 'accepted');
      expect(accepted.containsKey('note'), isFalse);
      expect(rejected['note'], 'Already dispatched');
      expect(adapter.requests.first.path, endsWith('/cancel_request/decision'));
    });
  });

  group('supplier list scoping', () {
    test('the inbox asks for the supplier side, not the trader side', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      final cubit = OrdersCubit(OrdersRepository(client), role: Workspace.supplier);
      cubit.statuses.addAll(['submitted', 'under_review']);

      await cubit.load();
      final query = adapter.requests.single.queryParameters;

      expect(query['role'], 'supplier');
      expect(query['status'], 'submitted,under_review');
    });
  });
}
