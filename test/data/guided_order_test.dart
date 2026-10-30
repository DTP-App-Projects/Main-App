import 'package:digital_trade_portal/data/models/advanced/contract.dart';
import 'package:digital_trade_portal/data/repositories/catalog_repository.dart';
import 'package:digital_trade_portal/data/repositories/contracts_repository.dart';
import 'package:digital_trade_portal/data/repositories/lookups_repository.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/features/trader/drafts/view_models/draft_cubit.dart';
import 'package:digital_trade_portal/features/trader/drafts/view_models/new_order_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Batch 2 of the guide audit: the guided purchase order (guide Part 8).
void main() {
  setUp(() async => useFakeStorage());

  /// Live shapes (2026-10-11, the website's order entry): payment terms by
  /// `term_mode`, the trader's relationships, contracts (a `framework`
  /// agreement among them), sectors, the supplier directory, each
  /// relationship's credit terms and the orderable SKUs.
  FakeAdapter lookups({Map<String, dynamic>? submitBody, int submitStatus = 200}) => FakeAdapter((
    options,
  ) async {
    final path = options.path;
    if (path.endsWith('payment_terms')) {
      return jsonBody(const {
        'items': [
          {'id': 1, 'label': 'Cash on delivery', 'term_mode': 'cash'},
          {'id': 4, 'label': 'Net 30 days', 'term_mode': 'deferred'},
          {'id': 6, 'label': '3 instalments', 'term_mode': 'installment'},
        ],
      });
    }
    if (path.endsWith('lookups/branches')) {
      return jsonBody(const {
        'items': [
          {'id': 12, 'label': 'Store', 'is_default': false},
          {'id': 13, 'label': 'Main branch', 'is_default': true},
        ],
      });
    }
    if (path.endsWith('lookups/relationships')) {
      return jsonBody(const {
        'items': [
          {'id': 6, 'label': 'Factory A', 'status': 'approved', 'supplier_organization_id': 23},
          {'id': 7, 'label': 'Factory B', 'status': 'approved', 'supplier_organization_id': 24},
          {'id': 9, 'label': 'Factory C', 'status': 'approved', 'supplier_organization_id': 26},
          {'id': 8, 'label': 'Pending', 'status': 'pending_review', 'supplier_organization_id': 25},
        ],
      });
    }
    if (path.endsWith('lookups/contracts')) {
      return jsonBody(const {
        'items': [
          {
            'id': 50,
            'label': 'A credit',
            'status': 'active',
            'contract_type': 'direct_credit',
            'business_relationship_id': 6,
          },
          {
            'id': 51,
            'label': 'B draft',
            'status': 'draft',
            'contract_type': 'direct_credit',
            'business_relationship_id': 7,
          },
          {
            'id': 52,
            'label': 'B cash',
            'status': 'approved',
            'contract_type': 'direct_cash',
            'business_relationship_id': 7,
          },
          {
            'id': 4,
            'label': 'Framework',
            'code': 'FA-2026-000002',
            'status': 'active',
            'contract_type': 'framework',
            'business_relationship_id': 9,
          },
        ],
      });
    }
    if (path.endsWith('business_sectors')) {
      return jsonBody(const {
        'items': [
          {'id': 5, 'label': 'Retail'},
          {'id': 7, 'label': 'Electronics'},
        ],
      });
    }
    if (path.endsWith('catalog/suppliers')) {
      return jsonBody(const {
        'current_page': 1,
        'last_page': 1,
        'data': [
          {
            'formatted': {
              'id': 23,
              'sectors': [
                {'id': 7, 'name': 'Electronics'},
              ],
            },
          },
          {
            'formatted': {
              'id': 24,
              'sectors': [
                {'id': 5, 'name': 'Retail'},
              ],
            },
          },
          {
            'formatted': {
              'id': 26,
              'sectors': [
                {'id': 5, 'name': 'Retail'},
                {'id': 7, 'name': 'Electronics'},
              ],
            },
          },
        ],
      });
    }
    final relationship = RegExp(r'/v2/relationships/(\d+)$').firstMatch(path);
    if (relationship != null) {
      final id = int.parse(relationship.group(1)!);
      // A and C have credit terms; B has none configured (live: limit 0).
      final configured = id == 6 || id == 9;
      return jsonBody({
        'relationship': {
          'id': id,
          'status': 'approved',
          'credit': {
            'credit_limit': configured ? 50000 : 0,
            'max_due_days': configured ? 30 : 0,
            'status': 'active',
          },
        },
      });
    }
    if (path.endsWith('lookups/skus')) {
      return jsonBody(const {
        'items': [
          {
            'id': 501,
            'name': 'Television',
            'sku_code': 'SKU-501',
            'product_id': 3,
            'min_order_qty': 2,
            'order_step_qty': 1,
            'inventory_preview': {'available_qty': 230},
            'price_preview': {
              'matched': true,
              'source': 'legacy_fallback',
              'currency_code': 'SAR',
              'unit_price': 10,
              'final_price': 10,
            },
          },
          {
            'id': 502,
            'name': 'No price',
            'price_preview': {'matched': false},
          },
        ],
      });
    }
    if (path.endsWith('/submit')) {
      return jsonBody(
        submitBody ??
            const {
              'purchase_order': {'id': 300, 'code': 'PO-1', 'status': 'submitted'},
            },
        status: submitStatus,
      );
    }
    if (path.endsWith('/lines')) {
      return jsonBody(const {
        'draft': {'id': 90},
      });
    }
    // The draft upsert.
    return jsonBody(const {
      'draft': {'id': 90, 'supplier_organization_id': 23, 'lines': []},
    });
  });

  Future<(NewOrderCubit, FakeAdapter)> started({
    int? supplier,
    Map<String, dynamic>? submitBody,
    int submitStatus = 200,
  }) async {
    final adapter = lookups(submitBody: submitBody, submitStatus: submitStatus);
    final (client, _) = clientWith(adapter);
    final cubit = NewOrderCubit(
      LookupsRepository(client),
      OrdersRepository(client),
      CatalogRepository(client),
      preselectedSupplierId: supplier,
    );
    await cubit.load();
    return (cubit, adapter);
  }

  group('eligibility per mode, as the website counts it', () {
    test(
      'cash: every approved relationship; credit: credit terms plus a contract or framework',
      () async {
        final (cubit, _) = await started();
        final state = cubit.state;

        expect(state.eligibleFor(PurchaseMode.cash).map((r) => r.id), [6, 7, 9]);
        expect(
          state.eligibleFor(PurchaseMode.credit).map((r) => r.id),
          [6, 9],
          reason: 'B has no credit terms; C is governed by its framework agreement',
        );
        expect(state.eligibleFor(PurchaseMode.installment), isEmpty);
        expect(state.modeBlock(PurchaseMode.installment), ModeBlock.noInstallmentContract);
        expect(
          state.blockFor(state.relationships[1], PurchaseMode.credit),
          ModeBlock.creditNotConfigured,
        );
      },
    );

    test('it opens on cash, with the default branch and the mode\'s first term', () async {
      final (cubit, _) = await started();
      expect(cubit.state.mode, PurchaseMode.cash);
      expect(cubit.state.branchId, 13);
      expect(cubit.state.paymentTermId, 1);

      cubit.chooseMode(PurchaseMode.credit);
      expect(cubit.state.paymentTermId, 4, reason: 'a deferred term for credit');
    });

    test('the sector narrows the suppliers', () async {
      final (cubit, _) = await started();

      cubit.chooseSector(5);
      expect(cubit.state.eligibleFor(PurchaseMode.cash).map((r) => r.id), [7, 9]);
      cubit.chooseSector(null);
      expect(cubit.state.eligibleFor(PurchaseMode.cash), hasLength(3));
    });

    test('credit needs a contract unless a framework agreement governs; cash never', () async {
      final (cubit, _) = await started();

      cubit.chooseMode(PurchaseMode.credit);
      await cubit.chooseSupplier(cubit.state.relationships.first);
      expect(cubit.state.contractId, 50, reason: 'the only matching contract is picked');
      expect(cubit.state.contractRequired, isTrue);

      await cubit.chooseSupplier(cubit.state.relationships[2]);
      expect(cubit.state.contractRequired, isFalse);
      expect(cubit.state.frameworkOf(cubit.state.relationship!)?.code, 'FA-2026-000002');

      cubit.chooseMode(PurchaseMode.cash);
      await cubit.chooseSupplier(cubit.state.relationships.first);
      expect(cubit.state.contractRequired, isFalse, reason: '«يمكن المتابعة كاش بدون عقد»');
    });

    test('a supplier the user came from is picked, with its items', () async {
      final (cubit, adapter) = await started(supplier: 24);

      expect(cubit.state.relationship?.id, 7);
      expect(cubit.state.items.map((i) => i.skuId), [501, 502]);
      expect(cubit.state.items.first.availableQty, 230);
      expect(cubit.state.items.last.orderable, isFalse);
      final skus = adapter.requests.lastWhere((r) => r.path.endsWith('lookups/skus'));
      expect(
        skus.queryParameters['branch_id'],
        isNull,
        reason: "it filters the supplier's stock, not the trader's delivery branch",
      );
    });
  });

  group('one submit, like the website', () {
    test('draft with every choice → its lines → submit', () async {
      final (cubit, adapter) = await started(supplier: 23);
      cubit.setQuantity(501, 3);

      expect(cubit.state.estimatedTotal, 30);
      final order = await cubit.submit(notes: ' before noon ');
      final posts = adapter.requests.where((r) => r.method == 'POST').toList();

      expect(order?.code, 'PO-1');
      expect(posts.map((r) => r.path.split('/v2/').last), [
        'purchase_drafts',
        'purchase_drafts/90/lines',
        'purchase_drafts/90/submit',
      ]);
      expect(posts.first.data, {
        'supplier_organization_id': 23,
        'relationship_id': 6,
        'delivery_branch_id': 13,
        'payment_term_id': 1,
        'notes': 'before noon',
      });
      expect(posts[1].data, {'sku_id': 501, 'qty': 3.0});
    });

    test('a quantity never goes above the available stock', () async {
      final (cubit, _) = await started(supplier: 23);

      cubit.setQuantity(501, 500);
      expect(cubit.state.quantities[501], 230, reason: 'the stock is 230');
      cubit.nudge(cubit.state.items.first, 1);
      expect(cubit.state.quantities[501], 230);
    });

    test("a quantity the SKU's rules forbid never reaches the server", () async {
      final (cubit, adapter) = await started(supplier: 23);
      cubit.setQuantity(501, 1);

      final order = await cubit.submit();

      expect(order, isNull);
      expect(cubit.state.lineErrors[501], isNotNull);
      expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('a refused submit puts each rule under its item', () async {
      final (cubit, _) = await started(
        supplier: 23,
        submitStatus: 422,
        submitBody: const {
          'msg': 'contract_rules_failed',
          'message': 'The order breaks the rules.',
          'errors': [
            {'code': 'qty_above_contract_max', 'message': 'At most 2', 'sku_id': 501},
            {'code': 'contract_minimum_order_value', 'message': 'Order at least 1000'},
          ],
        },
      );
      cubit.setQuantity(501, 3);

      await cubit.submit();

      expect(cubit.state.lineErrors[501], 'At most 2');
      expect(cubit.state.ruleErrors.single.code, 'contract_minimum_order_value');
    });
  });

  group('draft editor', () {
    FakeAdapter draftServer() => FakeAdapter((options) async {
      if (options.path.contains('payment_terms')) return jsonBody(const {'payment_terms': []});
      if (options.path.endsWith('/submit')) {
        return jsonBody(const {
          'purchase_order': {'id': 300, 'code': 'PO-1', 'status': 'submitted'},
        });
      }
      return jsonBody(const {
        'draft': {
          'id': 90,
          'supplier_organization_id': 23,
          'contract_id': 50,
          'payment_term_id': 4,
          'delivery_branch_id': 13,
          'notes': '',
        },
      });
    });

    test('changing one header field keeps the contract and the rest', () async {
      final adapter = draftServer();
      final (client, _) = clientWith(adapter);
      final cubit = DraftCubit(
        OrdersRepository(client),
        CatalogRepository(client),
        supplierOrganizationId: 23,
        relationshipId: 6,
        draftId: 90,
      );
      await cubit.start();

      await cubit.updateHeader(deliveryBranchId: 12);
      final body = adapter.requests.lastWhere((r) => r.method == 'POST').data as Map;

      expect(body['delivery_branch_id'], 12);
      expect(body['contract_id'], 50, reason: 'an upsert without it could clear the contract');
      expect(body['payment_term_id'], 4);
      await cubit.close();
    });

    test('typed notes are saved before the submit', () async {
      final adapter = draftServer();
      final (client, _) = clientWith(adapter);
      final cubit = DraftCubit(
        OrdersRepository(client),
        CatalogRepository(client),
        supplierOrganizationId: 23,
        relationshipId: 6,
        draftId: 90,
      );
      await cubit.start();

      final order = await cubit.submit(notes: ' deliver before noon ');
      final posts = adapter.requests.where((r) => r.method == 'POST').toList();

      expect((posts.first.data as Map)['notes'], 'deliver before noon');
      expect(posts.last.path, endsWith('/submit'));
      expect(order?.code, 'PO-1');
      await cubit.close();
    });
  });

  test('the approvals inbox reads both lists', () async {
    final (client, _) = clientWith(
      FakeAdapter.json(const {
        'contracts': [
          {'id': 3, 'display_name': 'Supply contract', 'status': 'under_review'},
        ],
        'purchase_orders': [
          {
            'id': 11,
            'status': 'pending',
            'purchase_order': {
              'id': 300,
              'code': 'PO-2026-1',
              'grand_total': 1150,
              'supplier': {'display_name': 'Factory A'},
            },
          },
        ],
        'counts': {'contracts': 1, 'purchase_orders': 1, 'total': 2},
      }),
    );

    final inbox = (await ContractsRepository(client).approvalsInbox()).dataOrNull!;

    expect(inbox.total, 2);
    final approval = inbox.purchaseOrders.single;
    expect(approval.purchaseOrderId, 300);
    expect(approval.orderCode, 'PO-2026-1');
    expect(approval.amount, 1150);
    expect(approval.counterpartyName, 'Factory A');
    expect(approval.isPending, isTrue);
    expect(inbox.contracts.single, isA<Contract>());
  });
}
