import 'package:digital_trade_portal/data/models/common/branch.dart';
import 'package:digital_trade_portal/data/models/trade/catalog.dart';
import 'package:digital_trade_portal/data/models/trade/purchase_order.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/catalog_repository.dart';
import 'package:digital_trade_portal/data/repositories/contracts_repository.dart';
import 'package:digital_trade_portal/data/repositories/lookups_repository.dart';
import 'package:digital_trade_portal/data/repositories/onboarding_repository.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/data/repositories/shipments_repository.dart';
import 'package:digital_trade_portal/data/repositories/supplier_repository.dart';
import 'package:digital_trade_portal/features/shared/advanced/view_models/advanced_cubits.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/onboarding_form_cubits.dart';
import 'package:digital_trade_portal/features/supplier/view_models/delivery_note_form_cubit.dart';
import 'package:digital_trade_portal/features/supplier/view_models/supplier_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Batch 3 of the guide audit: supplier operations (guide Parts 5, 7, 10).
void main() {
  setUp(() async => useFakeStorage());

  const orderJson = {
    'id': 300,
    'code': 'PO-1',
    'status': 'approved',
    'viewer_role': 'supplier',
    'delivery_branch_id': 13,
    'lines': [
      {'id': 1, 'sku_id': 501, 'sku_name': 'Rice 5kg', 'qty': 10, 'shipped_qty': 4},
      {'id': 2, 'sku_id': 502, 'sku_name': 'Oil 1L', 'qty': 6, 'shipped_qty': 6},
    ],
  };

  group('delivery note (guide 10.1)', () {
    test('an approved order with open quantity can be shipped; a fully shipped one cannot', () {
      final open = PurchaseOrder.fromJson(orderJson);
      final done = PurchaseOrder.fromJson({
        ...orderJson,
        'lines': [
          {'id': 2, 'sku_id': 502, 'qty': 6, 'shipped_qty': 6},
        ],
      });
      final draft = PurchaseOrder.fromJson({...orderJson, 'status': 'submitted'});

      expect(open.canShip, isTrue);
      expect(done.canShip, isFalse);
      expect(draft.canShip, isFalse, reason: 'only after the supplier accepted it');
    });

    test('pre-fills the open quantity, clamps edits, and sends only shipped lines', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.path.contains('purchase_orders')) {
            return jsonBody(const {'purchase_order': orderJson});
          }
          if (options.path.contains('lookups/branches')) {
            return jsonBody(const {
              'items': [
                {'id': 14, 'label': 'Warehouse', 'is_default': true},
              ],
            });
          }
          return jsonBody(const {
            'delivery_note': {'id': 77, 'status': 'draft'},
          });
        }),
      );
      final cubit = DeliveryNoteFormCubit(
        OrdersRepository(client),
        ShipmentsRepository(client),
        LookupsRepository(client),
        300,
      );
      await cubit.load();

      expect(cubit.state.shipQty, {1: 6, 2: 0}, reason: 'ordered minus shipped');
      expect(cubit.state.supplierBranchId, 14);

      final line = cubit.state.order!.lines.first;
      cubit.setQty(line, 99);
      expect(cubit.state.shipQty[1], 6, reason: 'never above what is open');
      cubit.setQty(line, 3);

      final note = await cubit.submit(notes: ' fragile ');
      final body = adapter.requests.last.data as Map;

      expect(note?.id, 77);
      expect(body['purchase_order_id'], 300);
      expect(body['supplier_branch_id'], 14);
      expect(body['trader_branch_id'], 13);
      expect(body['notes'], 'fragile');
      expect(body['lines'], [
        {'purchase_order_line_id': 1, 'sku_id': 501, 'shipped_qty': 3},
      ]);
      await cubit.close();
    });
  });

  group('branch location (guide 5.1)', () {
    test('the pin travels in the upsert; only the default flag is PATCHed', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.method == 'PATCH') {
            return jsonBody(const {
              'branch': {'id': 14},
            });
          }
          if (options.method == 'POST') {
            return jsonBody(const {
              'branch': {'id': 14},
            });
          }
          return jsonBody(const {
            'items': [
              {
                'id': 14,
                'name_ar': 'الفرع',
                'latitude': 24.7,
                'longitude': 46.6,
                'has_location': true,
              },
            ],
          });
        }),
      );
      final cubit = BranchesCubit(OnboardingRepository(client), AuthRepository(client));

      final ok = await cubit.save(
        branchId: 14,
        branchType: 'warehouse',
        nameAr: 'مستودع',
        countryId: 1,
        cityId: 2,
        addressText: 'x',
        latitude: 24.71361234,
        longitude: 46.6,
        isDefault: true,
      );
      final post = adapter.requests.firstWhere((r) => r.method == 'POST').data as Map;
      final patch = adapter.requests.firstWhere((r) => r.method == 'PATCH');

      expect(ok, isTrue);
      // Rounded to the 7 decimals the server stores.
      expect(post['latitude'], 24.7136123);
      expect(post['longitude'], 46.6);
      expect(patch.path, endsWith('/v2/organization/branches/14'));
      expect(patch.data, {'is_default': true});
      // The listing carries the pin itself now — no extra organization read.
      expect(adapter.requests.where((r) => r.path.endsWith('/v2/organization')), isEmpty);
      expect(cubit.state.items.single.hasLocation, isTrue);
      await cubit.close();
    });

    test('a branch without a pin sends both coordinates as null, and no PATCH', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.method == 'POST') {
            return jsonBody(const {
              'branch': {'id': 15},
            });
          }
          return jsonBody(const {'items': <Map<String, dynamic>>[]});
        }),
      );
      final cubit = BranchesCubit(OnboardingRepository(client), AuthRepository(client));

      await cubit.save(
        branchType: 'store',
        nameAr: 'متجر',
        countryId: 1,
        cityId: 2,
        addressText: 'x',
      );
      final post = adapter.requests.firstWhere((r) => r.method == 'POST').data as Map;

      // Omitting them would keep a pin the user just cleared.
      expect(post.containsKey('latitude'), isTrue);
      expect(post['latitude'], isNull);
      expect(post['longitude'], isNull);
      expect(adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
      await cubit.close();
    });

    test('has_location decides; 0,0 from GET /organization is no pin', () {
      final legacy = Branch.fromJson(const {'id': 1, 'latitude': 0, 'longitude': 0});
      final flagged = Branch.fromJson(const {
        'id': 1,
        'latitude': 0,
        'longitude': 0,
        'has_location': false,
      });
      final console = Branch.fromJson(const {'id': 1, 'latitude': null, 'has_location': false});
      final pinned = Branch.fromJson(const {
        'id': 1,
        'latitude': '24.7136123',
        'longitude': 46.6753,
        'has_location': true,
      });

      expect(legacy.hasLocation, isFalse);
      expect(legacy.latitude, isNull);
      expect(flagged.hasLocation, isFalse);
      expect(console.hasLocation, isFalse);
      expect(pinned.hasLocation, isTrue);
      expect(pinned.latitude, 24.7136123);
    });

    test('the link / coordinate parser matches the website', () {
      ({double lat, double lng})? p(String s) => BranchPin.parse(s);

      expect(p('https://www.google.com/maps/@28.8214,30.9066,17z'), (lat: 28.8214, lng: 30.9066));
      expect(p('28.8214, 30.9066'), (lat: 28.8214, lng: 30.9066));
      expect(p('28.8214، 30.9066'), (lat: 28.8214, lng: 30.9066));
      expect(p('24 46'), (lat: 24.0, lng: 46.0));
      expect(p('https://maps.google.com/?q=24.7136,46.6753'), (lat: 24.7136, lng: 46.6753));
      expect(p('https://maps.google.com/?Q=24.7136%2C46.6753'), (lat: 24.7136, lng: 46.6753));
      expect(p('https://waze.com/ul?ll=24.7136,46.6753&navigate=yes'), (
        lat: 24.7136,
        lng: 46.6753,
      ));
      expect(p('https://www.google.com/maps/place/X/data=!3m1!4b1!4m6!3m5!3d24.7136!4d46.6753'), (
        lat: 24.7136,
        lng: 46.6753,
      ));
      expect(p('https://www.openstreetmap.org/#map=16/24.7136/46.6753'), (
        lat: 24.7136,
        lng: 46.6753,
      ));
      expect(p('Olaya street'), isNull);
      expect(p('0, 0'), isNull);
      expect(p('95.1, 46.6'), isNull);
      expect(p('https://maps.app.goo.gl/abc123'), isNull);
      expect(BranchPin.isShortLink('https://maps.app.goo.gl/abc123'), isTrue);
    });

    test('a pin is both coordinates or neither, never 0,0 or out of range', () {
      expect(BranchPin.body(24.7, 46.6), {'latitude': 24.7, 'longitude': 46.6});
      expect(BranchPin.body(24.7, null), {'latitude': null, 'longitude': null});
      expect(BranchPin.body(0, 0), {'latitude': null, 'longitude': null});
      expect(BranchPin.body(91, 46.6), {'latitude': null, 'longitude': null});
      expect(BranchPin.body(24.7, -181), {'latitude': null, 'longitude': null});
    });
  });

  group('SKU readiness and tiers (guide 5.3)', () {
    test('readiness is computed when the server sends no checklist', () {
      final ready = Sku.fromJson(const {
        'id': 1,
        'status': 'active',
        'min_order_qty': 1,
        'order_step_qty': 1,
        'business_sectors': [
          {'id': 5, 'name': 'Retail'},
        ],
        'general_tiers': [
          {'payment_term_id': 1, 'min_qty': 1, 'max_qty': null, 'final_price': 12.5},
        ],
      });
      final bare = Sku.fromJson(const {
        'id': 2,
        'status': 'active',
        'min_order_qty': 1,
        'order_step_qty': 1,
      });

      expect(ready.businessSectorIds, [5]);
      expect(ready.generalTiers.single.finalPrice, 12.5);
      expect(ready.isReadyToSell, isTrue);
      expect(bare.isReadyToSell, isFalse);
      expect(bare.readiness['sectors'], isFalse);
      expect(bare.readiness['tiers'], isFalse);
    });

    test('untouched tiers and sectors are never sent (they would replace the SKU\'s)', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.method == 'PUT') {
            return jsonBody(const {
              'sku': {'id': 1},
            });
          }
          return jsonBody(const {
            'product': {'id': 9, 'skus': []},
            'items': [],
          });
        }),
      );
      final cubit = SkuRulesCubit(
        CatalogRepository(client),
        SupplierRepository(client),
        9,
        LookupsRepository(client),
      );
      await cubit.load();

      await cubit.save(skuId: 1, minOrderQty: 2);
      final first = adapter.requests.firstWhere((r) => r.method == 'PUT').data as Map;
      expect(first.containsKey('tiers'), isFalse);
      expect(first.containsKey('business_sector_ids'), isFalse);

      await cubit.save(
        skuId: 1,
        businessSectorIds: const [5],
        tiers: const [SkuTierInput(paymentTermId: 1, minQty: 1, finalPrice: 10)],
      );
      final second = adapter.requests.lastWhere((r) => r.method == 'PUT').data as Map;
      expect(second['business_sector_ids'], [5]);
      expect(second['tiers'], [
        {'payment_term_id': 1, 'min_qty': 1.0, 'final_price': 10.0},
      ]);
      await cubit.close();
    });
  });

  test('a new contract is created as a draft (guide 7.2)', () async {
    final (client, adapter) = clientWith(
      FakeAdapter((options) async {
        if (options.method == 'POST') {
          return jsonBody(const {
            'contract': {'id': 2, 'status': 'draft', 'contract_type': 'cash'},
          });
        }
        return jsonBody(const {'data': [], 'current_page': 1, 'last_page': 1});
      }),
    );
    final cubit = ContractsCubit(ContractsRepository(client));

    final result = await cubit.create(
      relationshipId: 6,
      contractType: 'direct_cash',
      nameEn: 'Supply 2026',
      startDate: DateTime(2026, 10, 6),
      endDate: DateTime(2027, 10, 6),
    );
    final body = adapter.requests.firstWhere((r) => r.method == 'POST').data as Map;

    expect(result.dataOrNull?.id, 2);
    expect(body['status'], 'draft');
    expect(body['contract_type'], 'direct_cash');
    expect(body['start_date'], '2026-10-06');
    await cubit.close();
  });
}
