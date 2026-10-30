import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/auth_context.dart';
import '../../core/network/coerce.dart';
import '../api_paths.dart';
import '../models/fleet/fleet_contract.dart';
import '../models/fleet/van_trip.dart';

/// The supplier's fleet: van sales («البيع المتجول») and delivery contracts
/// («عقود التوصيل»). Supplier / hybrid organizations only — a trader org
/// gets `403 organization_workspace_not_allowed`.
///
/// Unlike the rest of `/v2`, these read `organization_id` from the request
/// itself (query on GET, body otherwise), not only from `X-Organization-Id`.
/// Reading needs `fleet.view`, writing `fleet.manage`.
///
/// Van sales answer typed JSON: validation is `422 validation_failed
/// {errors}` and refusals are `422 van_*_refused {error, message_ar,
/// message_en}` — the normalizer maps both, and the server's sentence is
/// what the user sees.
class FleetRepository {
  final ApiClient _client;
  final AuthContext _context;

  FleetRepository(this._client, this._context);

  Map<String, dynamic> get _org => {'organization_id': ?_context.organizationId};

  // ------------------------------------------------------------- van trips

  Future<ApiResult<VanTripList>> vanTrips({String? status, int page = 1}) =>
      _client.get<VanTripList>(
        ApiPaths.vanTrips,
        query: {..._org, 'status': ?status, 'page': page},
        parse: (body) => VanTripList.fromJson(asMap(body)),
      );

  Future<ApiResult<VanFormOptions>> vanFormOptions() => _client.get<VanFormOptions>(
    ApiPaths.vanTripFormOptions,
    query: _org,
    parse: (body) => VanFormOptions.fromJson(asMap(body)),
  );

  /// `201 {trip}` in `draft`, with the 6-digit `load_code`.
  Future<ApiResult<VanTrip>> createLoadSheet({
    required int driverId,
    int? vehicleId,
    required int warehouseBranchId,
    double? maxDiscountPercent,
    String? notes,
    required List<VanLoadLineInput> lines,
  }) => _client.post<VanTrip>(
    ApiPaths.vanTrips,
    body: {
      ..._org,
      'driver_id': driverId,
      'vehicle_id': ?vehicleId,
      'warehouse_branch_id': warehouseBranchId,
      'max_discount_percent': ?maxDiscountPercent,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      'lines': lines.map((l) => l.toJson()).toList(),
    },
    parse: (body) => VanTrip.fromJson(asMap(asMap(body)['trip'])),
  );

  Future<ApiResult<VanTripDetail>> vanTrip(int id) => _client.get<VanTripDetail>(
    ApiPaths.vanTrip(id),
    query: _org,
    parse: (body) => VanTripDetail.fromJson(asMap(body)),
  );

  /// The light poll. Never de-duplicated: two polls a frame apart are not the
  /// same question.
  Future<ApiResult<VanTripFigures>> vanTripFigures(int id) => _client.get<VanTripFigures>(
    ApiPaths.vanTripFigures(id),
    query: _org,
    dedupe: false,
    parse: (body) => VanTripFigures.fromJson(asMap(body)),
  );

  /// Only before the load is confirmed (`draft`).
  Future<ApiResult<VanTrip>> cancelVanTrip(int id) => _client.post<VanTrip>(
    ApiPaths.vanTripCancel(id),
    body: _org,
    parse: (body) => VanTrip.fromJson(asMap(asMap(body)['trip'])),
  );

  /// Only while `returning`. [returnCode] stays a string — a leading zero is
  /// part of the code.
  Future<ApiResult<VanTrip>> reconcileVanTrip(
    int id, {
    required String returnCode,
    required double cashHandedOver,
    String? varianceReason,
    required List<VanReturnLineInput> lines,
  }) => _client.post<VanTrip>(
    ApiPaths.vanTripReconcile(id),
    body: {
      ..._org,
      'return_code': returnCode,
      'cash_handed_over': cashHandedOver,
      if ((varianceReason ?? '').trim().isNotEmpty) 'variance_reason': varianceReason!.trim(),
      'lines': lines.map((l) => l.toJson()).toList(),
    },
    parse: (body) => VanTrip.fromJson(asMap(asMap(body)['trip'])),
  );

  // ---------------------------------------------------- delivery contracts

  Future<ApiResult<FleetContractsOverview>> contracts() => _client.get<FleetContractsOverview>(
    ApiPaths.fleetContracts,
    query: _org,
    parse: (body) => FleetContractsOverview.fromJson(asMap(body)),
  );

  /// `per_delivery` needs a rate per delivery and/or per km; a
  /// `monthly_retainer` needs the monthly amount. Refusals are `422
  /// fleet_contract_refused` with the server's sentence.
  Future<ApiResult<FleetContract>> requestContract({
    required int fleetCompanyId,
    required String billingMode,
    double? ratePerDelivery,
    double? ratePerKm,
    double? monthlyRetainerAmount,
    int? driversCount,
    int? expectedDeliveriesPerMonth,
    String? coverageNotes,
  }) {
    final monthly = billingMode == FleetContract.monthlyRetainer;
    return _client.post<FleetContract>(
      ApiPaths.fleetContracts,
      body: {
        ..._org,
        'fleet_company_id': fleetCompanyId,
        'billing_mode': billingMode,
        // Only the fields of the chosen mode: a stale per-delivery rate left
        // in the form must not ride along on a retainer request.
        if (!monthly) 'rate_per_delivery': ?ratePerDelivery,
        if (!monthly) 'rate_per_km': ?ratePerKm,
        if (monthly) 'monthly_retainer_amount': ?monthlyRetainerAmount,
        'drivers_count': ?driversCount,
        'expected_deliveries_per_month': ?expectedDeliveriesPerMonth,
        if ((coverageNotes ?? '').trim().isNotEmpty) 'coverage_notes': coverageNotes!.trim(),
      },
      parse: (body) => FleetContract.fromJson(asMap(asMap(body)['contract'])),
    );
  }

  Future<ApiResult<FleetContract>> endContract(int id, {String? reason}) =>
      _client.post<FleetContract>(
        ApiPaths.fleetContractEnd(id),
        body: {..._org, if ((reason ?? '').trim().isNotEmpty) 'end_reason': reason!.trim()},
        parse: (body) => FleetContract.fromJson(asMap(asMap(body)['contract'])),
      );
}
