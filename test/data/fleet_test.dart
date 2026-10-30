import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/data/models/fleet/fleet_contract.dart';
import 'package:digital_trade_portal/data/models/fleet/internal_transfer.dart';
import 'package:digital_trade_portal/data/models/fleet/van_trip.dart';
import 'package:digital_trade_portal/data/repositories/fleet_repository.dart';
import 'package:digital_trade_portal/data/repositories/internal_transfers_repository.dart';
import 'package:digital_trade_portal/features/supplier/view_models/delivery_contracts_cubit.dart';
import 'package:digital_trade_portal/features/supplier/view_models/internal_transfers_cubits.dart';
import 'package:digital_trade_portal/features/supplier/view_models/van_sales_cubits.dart';
import 'package:digital_trade_portal/features/supplier/views/fleet_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Van sales, delivery contracts and internal transfers (supplier side,
/// 2026-10-27 brief). Shapes copied from the brief's examples.
void main() {
  setUp(() async => useFakeStorage());

  const tripJson = {
    'id': 7,
    'code': 'VT-2026-000007',
    'status': 'draft',
    'driver': {'id': 4, 'name': 'Redouane Ridmi', 'phone': '0500000009'},
    'vehicle': {'id': 2, 'plate_number': 'ABC 1234'},
    'warehouse': {'id': 5, 'name_ar': 'المستودع الرئيسي', 'name_en': 'Main warehouse'},
    'sales_count': 0,
    'sales_total': 0.0,
    'load_code': '048213',
    'cash_sales_total': 0.0,
    'created_at': '2026-10-27T07:55:00+03:00',
    'lines': [
      {'line_id': 1, 'sku_id': 1, 'name': 'زيت', 'loaded': 100, 'in_van': 100},
    ],
  };

  group('errors in the new shapes', () {
    test('422 validation_failed {errors} is a validation result, field by field', () async {
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'msg': 'validation_failed',
          'errors': {
            'driver_id': ['The driver field is required.'],
          },
        }, status: 422),
      );
      final result = await FleetRepository(
        client,
        FakeAuthContext(),
      ).createLoadSheet(driverId: 0, warehouseBranchId: 5, lines: const []);

      expect(result, isA<Invalid<VanTrip>>());
      expect((result as Invalid).first('driver_id'), 'The driver field is required.');
    });

    test('a refusal shows the server sentence in the request language', () async {
      const refusal = {
        'msg': 'van_reconcile_refused',
        'error': 'van_return_code_invalid',
        'message_ar': 'رمز العودة غير صحيح',
        'message_en': 'The return code is wrong',
      };
      for (final (locale, expected) in [
        ('en', 'The return code is wrong'),
        ('ar', 'رمز العودة غير صحيح'),
      ]) {
        final context = FakeAuthContext(locale: locale);
        final (client, _) = clientWith(FakeAdapter.json(refusal, status: 422), context: context);
        final result = await FleetRepository(
          client,
          context,
        ).reconcileVanTrip(7, returnCode: '000000', cashHandedOver: 0, lines: const []);

        expect(result, isA<Failed<VanTrip>>());
        final failed = result as Failed<VanTrip>;
        expect(failed.code, 'van_reconcile_refused');
        expect(failed.details?['error'], 'van_return_code_invalid', reason: 'kept for branching');
        expect(failed.message, expected);
      }
    });
  });

  group('van sales', () {
    test('organization_id rides in the query on GET and in the body on POST', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async => jsonBody(const {'trip': tripJson})),
        context: FakeAuthContext(organizationId: 12),
      );
      final repo = FleetRepository(client, FakeAuthContext(organizationId: 12));

      await repo.vanTrips(status: 'on_road');
      expect(adapter.requests.last.queryParameters['organization_id'], 12);
      expect(adapter.requests.last.queryParameters['status'], 'on_road');

      await repo.cancelVanTrip(7);
      expect((adapter.requests.last.data as Map)['organization_id'], 12);
    });

    test('the load code keeps its leading zero, even if a number slips through', () {
      expect(VanTrip.fromJson(tripJson).loadCode, '048213');
      expect(VanTrip.fromJson({...tripJson, 'load_code': 48213}).loadCode, '048213');
      expect(
        VanTrip.fromJson({...tripJson, 'status': 'on_road', 'load_code': null}).loadCode,
        isNull,
      );
    });

    test('the list carries counts, cash on the road and its own pagination block', () {
      final list = VanTripList.fromJson(const {
        'trips': [tripJson],
        'counts': {'draft': 1, 'on_road': 2, 'returning': 0, 'reconciled': 9, 'canceled': 1},
        'cash_on_road': 1240.5,
        'pagination': {'current_page': 1, 'last_page': 2, 'per_page': 20, 'total': 21},
      });

      expect(list.page.items.single.code, 'VT-2026-000007');
      expect(list.counts['reconciled'], 9);
      expect(list.cashOnRoad, 1240.5);
      expect(list.page.hasMore, isTrue);
    });

    test('times with an offset show as Riyadh wall time', () {
      final created = VanTrip.fromJson(tripJson).createdAt!;
      expect((created.hour, created.minute), (7, 55));
    });

    test('the return code is sent as a string', () async {
      final (client, adapter) = clientWith(
        FakeAdapter(
          (options) async => jsonBody({
            'trip': {...tripJson, 'status': 'reconciled'},
          }),
        ),
      );
      await FleetRepository(client, FakeAuthContext()).reconcileVanTrip(
        7,
        returnCode: '012345',
        cashHandedOver: 800,
        varianceReason: '  one bottle broke ',
        lines: const [VanReturnLineInput(skuId: 1, returnedQty: 29, damagedQty: 1)],
      );
      final body = adapter.requests.last.data as Map;

      expect(body['return_code'], '012345');
      expect(body['variance_reason'], 'one bottle broke');
      expect(body['lines'], [
        {'sku_id': 1, 'returned_qty': 29.0, 'damaged_qty': 1.0},
      ]);
    });

    test('a variance needs a reason: count off what is in the van, or cash off the sales', () {
      const lines = [VanTripLine(lineId: 1, skuId: 1, name: 'x', loaded: 100, inVan: 30)];
      bool variance(double returned, double damaged, double cash) => vanReconcileHasVariance(
        lines: lines,
        counted: {1: (returned: returned, damaged: damaged)},
        expectedCash: 805,
        cash: cash,
      );

      expect(variance(29, 1, 805), isFalse, reason: '29 + 1 = 30 in the van');
      expect(variance(29, 0, 805), isTrue);
      expect(variance(30, 0, 800), isTrue, reason: 'cash short');
    });

    test('the load sheet: default vehicle only when free, quantity never above stock', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.path.endsWith('form_options')) {
            return jsonBody(const {
              'drivers': [
                {'id': 4, 'name': 'A', 'default_vehicle_id': 2},
                {'id': 5, 'name': 'B', 'default_vehicle_id': 9},
              ],
              'vehicles': [
                {'id': 2, 'plate_number': 'ABC 1234'},
              ],
              'warehouses': [
                {
                  'id': 5,
                  'name_ar': 'رئيسي',
                  'is_default': true,
                  'stock': [
                    {'sku_id': 1, 'name': 'Oil', 'available_qty': 250},
                  ],
                },
              ],
            });
          }
          return jsonBody(const {'msg': 'van_load_sheet_created', 'trip': tripJson}, status: 201);
        }),
      );
      final cubit = VanLoadSheetCubit(FleetRepository(client, FakeAuthContext()));
      await cubit.load();

      expect(cubit.state.warehouseId, 5, reason: 'the default warehouse');
      cubit.chooseDriver(5);
      expect(cubit.state.vehicleId, isNull, reason: 'vehicle 9 is out on a trip');
      cubit.chooseDriver(4);
      expect(cubit.state.vehicleId, 2);

      cubit.addItem(cubit.state.pickable.single);
      expect(cubit.setQty(1, 300), 250);

      final trip = await cubit.submit(maxDiscountPercent: 5);
      final body = adapter.requests.last.data as Map;
      expect(trip?.loadCode, '048213');
      expect(body['driver_id'], 4);
      expect(body['vehicle_id'], 2);
      expect(body['warehouse_branch_id'], 5);
      expect(body['max_discount_percent'], 5.0);
      expect(body['lines'], [
        {'sku_id': 1, 'qty': 250.0},
      ]);
      await cubit.close();
    });

    test('the poll swaps in live figures, and a status change re-reads the trip', () async {
      var status = 'on_road';
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.path.endsWith('/figures')) {
            return jsonBody({
              'status': status,
              'cash_sales_total': 805.0,
              'sales_count': 3,
              'lines': const [
                {'line_id': 1, 'sku_id': 1, 'name': 'زيت', 'loaded': 100, 'sold': 30, 'in_van': 70},
              ],
            });
          }
          return jsonBody({
            'trip': {...tripJson, 'status': status, 'load_code': null},
            'sales': const [],
            'deliveries': const [],
          });
        }),
      );
      final cubit = VanTripCubit(
        FleetRepository(client, FakeAuthContext()),
        7,
        pollEvery: const Duration(hours: 1),
      );
      await cubit.load();

      await cubit.refreshFigures();
      expect(cubit.state.trip!.cashSalesTotal, 805.0);
      expect(cubit.state.trip!.lines.single.inVan, 70);

      status = 'returning';
      final before = adapter.requests.length;
      await cubit.refreshFigures();
      expect(adapter.requests.length - before, 2, reason: 'figures, then the whole trip');
      expect(cubit.state.trip!.isReturning, isTrue);
      await cubit.close();
    });
  });

  group('delivery contracts', () {
    test('older JSON: decimals as strings, nulls stay null', () {
      final contract = FleetContract.fromJson(const {
        'id': 3,
        'status': 'active',
        'billing_mode': 'per_delivery',
        'rate_per_delivery': '15.00',
        'rate_per_km': null,
        'deliveries_this_month': '42',
        'fleet_company': {
          'id': 8,
          'legal_name_ar': 'شركة',
          'legal_name_en': 'Co',
          // As seen live (2026-10-27): codes, and an empty coverage list.
          'coverage_areas': [],
          'service_types': ['last_mile', 'express'],
          'rating_avg': 0,
        },
      });

      expect(contract.ratePerDelivery, 15.0);
      expect(contract.ratePerKm, isNull);
      expect(contract.deliveriesThisMonth, 42);
      expect(contract.company?.name('en'), 'Co');
      expect(contract.company?.serviceTypes, ['last_mile', 'express']);
      expect(contract.company?.coverageAreas, '');
      expect(contract.canEnd, isTrue);
      expect(FleetContract.fromJson(const {'id': 1, 'status': 'ended'}).canEnd, isFalse);
    });

    test('a retainer request carries only the retainer amount', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.method == 'GET') {
            return jsonBody(const {'contracts': [], 'available_companies': []});
          }
          return jsonBody(const {
            'contract': {'id': 3, 'status': 'pending'},
          }, status: 201);
        }),
        context: FakeAuthContext(organizationId: 12),
      );
      final cubit = DeliveryContractsCubit(
        FleetRepository(client, FakeAuthContext(organizationId: 12)),
      );

      final ok = await cubit.request(
        fleetCompanyId: 8,
        billingMode: FleetContract.monthlyRetainer,
        ratePerDelivery: 15,
        monthlyRetainerAmount: 6000,
      );
      final post = adapter.requests.firstWhere((r) => r.method == 'POST');
      final body = post.data as Map;

      expect(ok, isTrue);
      expect(body['organization_id'], 12);
      expect(body['monthly_retainer_amount'], 6000.0);
      expect(
        body.containsKey('rate_per_delivery'),
        isFalse,
        reason: 'a stale field of the other mode',
      );
      expect(adapter.requests.last.method, 'GET', reason: 'the list is re-read');
      await cubit.close();
    });
  });

  group('internal transfers', () {
    test('the existing model also reads the nested relations', () {
      final transfer = InternalTransfer.fromJson(const {
        'id': 21,
        'code': 'IT-1',
        'status': 'draft',
        'priority': 'urgent',
        'required_by_date': '2026-10-30',
        'source_branch': {'id': 5, 'name_ar': 'أ', 'name_en': 'A'},
        'destination_branch': {'id': 6, 'name_ar': 'ب', 'name_en': 'B'},
        'requested_by': {'id': 40, 'first_name': 'Ahmed', 'last_name': 'Ali'},
        'lines': [
          {
            'id': 1,
            'sku_id': 1,
            'requested_qty': '5.000',
            'sku': {'id': 1, 'sku_code': 'SKU-1'},
          },
        ],
      });

      expect(transfer.sourceBranchId, 5, reason: 'from the nested branch');
      expect(transfer.destinationBranch?.name('en'), 'B');
      expect(transfer.requestedBy, 'Ahmed Ali');
      expect(transfer.lines.single.requestedQty, 5);
      expect(transfer.lines.single.label('ar'), 'SKU-1');
    });

    test('same branch is refused before any request; approve_now only when allowed', () async {
      final (client, adapter) = clientWith(
        FakeAdapter((options) async {
          if (options.path.endsWith('form_options')) {
            return jsonBody(const {
              'branches': [
                {'id': 5, 'name_ar': 'أ', 'is_default': 1},
                {'id': 6, 'name_ar': 'ب', 'is_default': 0},
              ],
              'skus': [
                {'id': 1, 'name': 'Oil', 'code': 'SKU-1'},
              ],
              'priorities': ['normal', 'urgent', 'critical'],
            });
          }
          return jsonBody(const {
            'msg': 'internal_transfer_created',
            'internal_transfer': {'id': 21, 'status': 'draft'},
          });
        }),
      );
      final cubit = InternalTransferFormCubit(
        InternalTransfersRepository(client, FakeAuthContext()),
      );
      await cubit.load();
      expect(cubit.state.sourceId, 5, reason: 'the default branch');

      cubit.chooseDestination(5);
      cubit.addSku(cubit.state.options!.skus.single);
      final count = adapter.requests.length;
      expect(await cubit.submit(mayApprove: true), isNull);
      expect(adapter.requests.length, count, reason: 'never sent');
      expect(cubit.state.submit.fieldError('destination_branch_id'), isNotNull);

      cubit.chooseDestination(6);
      cubit.setApproveNow(true);
      await cubit.submit(mayApprove: false);
      final body = adapter.requests.last.data as Map;
      expect(body.containsKey('approve_now'), isFalse, reason: 'no approve permission');
      expect(body['lines'], [
        {'sku_id': 1, 'requested_qty': 1.0},
      ]);
      await cubit.close();
    });

    test('cancel sends the reason with the status, organization_id in the body', () async {
      final (client, adapter) = clientWith(
        FakeAdapter(
          (options) async => jsonBody(const {
            'internal_transfer': {'id': 21, 'status': 'canceled'},
          }),
        ),
        context: FakeAuthContext(organizationId: 12),
      );
      final cubit = InternalTransferCubit(
        InternalTransfersRepository(client, FakeAuthContext(organizationId: 12)),
        21,
      );

      await cubit.cancel('wrong branch');
      final patch = adapter.requests.firstWhere((r) => r.method == 'PATCH');

      expect(patch.path, endsWith('/v2/internal_transfers/21/status'));
      expect(patch.data, {'organization_id': 12, 'status': 'canceled', 'reason': 'wrong branch'});
      await cubit.close();
    });
  });

  test('numbers typed on an Arabic keyboard', () {
    expect(parseFleetNumber('٣٫٥'), 3.5);
    expect(parseFleetNumber('12,5'), 12.5);
    expect(parseFleetNumber(''), isNull);
  });
}
