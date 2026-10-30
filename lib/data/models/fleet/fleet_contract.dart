import '../../../core/network/coerce.dart';
import 'fleet_common.dart';

/// «عقود التوصيل» — the supplier's contract with a delivery company.
///
/// `pending` until the company accepts (`active`) or rejects (`rejected`)
/// from its own panel; the admin can pause (`suspended`). The supplier can
/// end any open one. One open contract per company.
///
/// Older JSON style: decimals arrive as strings (`"15.00"`), counts may be
/// strings or numbers.
class FleetContract {
  final int id;
  final String status;
  final String billingMode;
  final double? ratePerDelivery;
  final double? ratePerKm;
  final double? monthlyRetainerAmount;
  final int? driversCount;
  final int? expectedDeliveriesPerMonth;
  final int deliveriesThisMonth;
  final String currency;
  final String coverageNotes;
  final FleetCompany? company;
  final String requestedBy;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? suspendedAt;
  final DateTime? endedAt;
  final String rejectionReason;
  final String endReason;

  const FleetContract({
    required this.id,
    required this.status,
    this.billingMode = '',
    this.ratePerDelivery,
    this.ratePerKm,
    this.monthlyRetainerAmount,
    this.driversCount,
    this.expectedDeliveriesPerMonth,
    this.deliveriesThisMonth = 0,
    this.currency = 'SAR',
    this.coverageNotes = '',
    this.company,
    this.requestedBy = '',
    this.requestedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.suspendedAt,
    this.endedAt,
    this.rejectionReason = '',
    this.endReason = '',
  });

  factory FleetContract.fromJson(Map<String, dynamic> j) => FleetContract(
    id: asInt(j['id']),
    status: asStr(j['status']),
    billingMode: asStr(j['billing_mode']),
    ratePerDelivery: asNumOrNull(j['rate_per_delivery']),
    ratePerKm: asNumOrNull(j['rate_per_km']),
    monthlyRetainerAmount: asNumOrNull(j['monthly_retainer_amount']),
    driversCount: asIntOrNull(j['drivers_count']),
    expectedDeliveriesPerMonth: asIntOrNull(j['expected_deliveries_per_month']),
    deliveriesThisMonth: asInt(j['deliveries_this_month']),
    currency: asStr(j['currency']).isEmpty ? 'SAR' : asStr(j['currency']),
    coverageNotes: asStr(j['coverage_notes']),
    company: j['fleet_company'] is Map ? FleetCompany.fromJson(asMap(j['fleet_company'])) : null,
    requestedBy: asStr(j['requested_by']),
    requestedAt: fleetTime(j['requested_at']),
    acceptedAt: fleetTime(j['accepted_at']),
    rejectedAt: fleetTime(j['rejected_at']),
    suspendedAt: fleetTime(j['suspended_at']),
    endedAt: fleetTime(j['ended_at']),
    rejectionReason: asStr(j['rejection_reason']),
    endReason: asStr(j['end_reason']),
  );

  /// The supplier may end a contract that is still open.
  bool get canEnd => status == 'pending' || status == 'active' || status == 'suspended';

  bool get isMonthly => billingMode == FleetContract.monthlyRetainer;

  static const perDelivery = 'per_delivery';
  static const monthlyRetainer = 'monthly_retainer';
}

/// An approved delivery company, as listed on a contract or as one the
/// supplier may still ask.
class FleetCompany {
  final int id;
  final String legalNameAr;
  final String legalNameEn;
  final String logo;
  final String coverageAreas;

  /// Codes (`last_mile`, `refrigerated`, …), seen live 2026-10-27.
  final List<String> serviceTypes;
  final int? fleetSize;
  final int? driverCount;
  final double? ratingAvg;

  const FleetCompany({
    required this.id,
    this.legalNameAr = '',
    this.legalNameEn = '',
    this.logo = '',
    this.coverageAreas = '',
    this.serviceTypes = const [],
    this.fleetSize,
    this.driverCount,
    this.ratingAvg,
  });

  factory FleetCompany.fromJson(Map<String, dynamic> j) => FleetCompany(
    id: asInt(j['id']),
    legalNameAr: asStr(j['legal_name_ar']),
    legalNameEn: asStr(j['legal_name_en']),
    logo: asStr(j['logo']),
    coverageAreas: _text(j['coverage_areas']),
    serviceTypes: j['service_types'] is List
        ? asStrList(j['service_types'])
        : [if (asStr(j['service_types']).isNotEmpty) asStr(j['service_types'])],
    fleetSize: asIntOrNull(j['fleet_size']),
    driverCount: asIntOrNull(j['driver_count']),
    ratingAvg: asNumOrNull(j['rating_avg']),
  );

  String name(String locale) => pickLocalized(locale: locale, ar: legalNameAr, en: legalNameEn);

  /// `coverage_areas` / `service_types` are undocumented in shape: a string,
  /// a list of strings, or a list of `{name…}` rows. Flattened for display.
  static String _text(dynamic v) {
    if (v is List) {
      return v
          .map(
            (e) =>
                e is Map ? asStr(e['name'] ?? e['name_ar'] ?? e['name_en'] ?? e['code']) : asStr(e),
          )
          .where((e) => e.isNotEmpty)
          .join('، ');
    }
    return v is Map ? '' : asStr(v);
  }
}

/// `GET /fleet/contracts` → `{contracts, available_companies, billing_modes}`.
class FleetContractsOverview {
  final List<FleetContract> contracts;

  /// Approved and active, with no open contract yet.
  final List<FleetCompany> availableCompanies;
  final List<String> billingModes;

  const FleetContractsOverview({
    this.contracts = const [],
    this.availableCompanies = const [],
    this.billingModes = const [FleetContract.perDelivery, FleetContract.monthlyRetainer],
  });

  factory FleetContractsOverview.fromJson(Map<String, dynamic> j) {
    final modes = asStrList(j['billing_modes']);
    return FleetContractsOverview(
      contracts: asList(j['contracts'], FleetContract.fromJson),
      availableCompanies: asList(j['available_companies'], FleetCompany.fromJson),
      billingModes: modes.isEmpty
          ? const [FleetContract.perDelivery, FleetContract.monthlyRetainer]
          : modes,
    );
  }
}
