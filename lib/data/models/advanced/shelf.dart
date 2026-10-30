import '../../../core/network/coerce.dart';
import '../fleet/fleet_common.dart';

/// Stock moved onto a trader's shelf under a consignment contract — sent, but
/// not sold until the trader reports it.
class ConsignmentShipment {
  final int id;
  final int contractId;
  final int? sourceBranchId;
  final int? destinationBranchId;
  final String code;
  final String status;
  final String notes;
  final DateTime? createdAt;
  final List<ShelfLine> lines;

  const ConsignmentShipment({
    required this.id,
    required this.contractId,
    required this.sourceBranchId,
    required this.destinationBranchId,
    required this.code,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.lines,
  });

  factory ConsignmentShipment.fromJson(Map<String, dynamic> j) => ConsignmentShipment(
        id: asInt(j['id']),
        contractId: asInt(j['contract_id']),
        sourceBranchId: asIntOrNull(j['source_branch_id']),
        destinationBranchId: asIntOrNull(j['destination_branch_id']),
        code: asStr(j['code']),
        status: asStr(j['status']),
        notes: unwrap(j['notes']),
        createdAt: asDate(j['created_at']),
        lines: asList(j['lines'], ShelfLine.fromJson),
      );

  static const statuses = ['draft', 'sent', 'received', 'closed', 'canceled'];
}

/// What actually sold off the shelf in a period.
class SalesReport {
  final int id;
  final int contractId;
  final int? branchId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String status;
  final String notes;
  final double grossSales;
  final List<ShelfLine> lines;

  const SalesReport({
    required this.id,
    required this.contractId,
    required this.branchId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.notes,
    required this.grossSales,
    required this.lines,
  });

  factory SalesReport.fromJson(Map<String, dynamic> j) => SalesReport(
        id: asInt(j['id']),
        contractId: asInt(j['contract_id']),
        branchId: asIntOrNull(j['branch_id']),
        periodStart: asDate(j['period_start']),
        periodEnd: asDate(j['period_end']),
        status: asStr(j['status']),
        notes: unwrap(j['notes']),
        grossSales: asNum(j['gross_sales'] ?? j['total']),
        lines: asList(j['lines'], ShelfLine.fromJson),
      );

  static const statuses = ['draft', 'submitted', 'verified', 'rejected', 'closed'];
}

/// A physical count of what is on the shelf.
class StockCount {
  final int id;
  final int contractId;
  final int? branchId;
  final String countType;
  final DateTime? countDate;
  final String status;
  final String notes;
  final List<ShelfLine> lines;

  const StockCount({
    required this.id,
    required this.contractId,
    required this.branchId,
    required this.countType,
    required this.countDate,
    required this.status,
    required this.notes,
    required this.lines,
  });

  factory StockCount.fromJson(Map<String, dynamic> j) => StockCount(
        id: asInt(j['id']),
        contractId: asInt(j['contract_id']),
        branchId: asIntOrNull(j['branch_id']),
        countType: asStr(j['count_type']),
        countDate: asDate(j['count_date']),
        status: asStr(j['status']),
        notes: unwrap(j['notes']),
        lines: asList(j['lines'], ShelfLine.fromJson),
      );

  static const countTypes = ['opening', 'closing', 'cycle', 'investigation'];
  static const statuses = ['draft', 'submitted', 'verified', 'rejected', 'closed'];
}

/// A correction to the shelf: a return, damage, expiry, or a manual fix.
class ShelfAdjustment {
  final int id;
  final int contractId;
  final int? branchId;
  final int? targetBranchId;
  final String adjustmentType;
  final String visitType;
  final String status;
  final String notes;
  final DateTime? createdAt;
  final List<ShelfLine> lines;

  const ShelfAdjustment({
    required this.id,
    required this.contractId,
    required this.branchId,
    required this.targetBranchId,
    required this.adjustmentType,
    required this.visitType,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.lines,
  });

  factory ShelfAdjustment.fromJson(Map<String, dynamic> j) => ShelfAdjustment(
        id: asInt(j['id']),
        contractId: asInt(j['contract_id']),
        branchId: asIntOrNull(j['branch_id']),
        targetBranchId: asIntOrNull(j['target_branch_id']),
        adjustmentType: asStr(j['adjustment_type']),
        visitType: asStr(j['visit_type']),
        status: asStr(j['status']),
        notes: unwrap(j['notes']),
        createdAt: asDate(j['created_at']),
        lines: asList(j['lines'], ShelfLine.fromJson),
      );

  static const adjustmentTypes = ['return', 'damage', 'expiry', 'manual'];
  static const visitTypes = ['driver_visit', 'supplier_self', 'trader_count'];
  static const statuses = ['draft', 'submitted', 'approved', 'rejected', 'closed'];
}

/// One SKU row on any of the shelf documents. The shapes overlap enough that
/// one model covers them, with the fields a given document does not use
/// simply sitting at zero.
class ShelfLine {
  final int id;
  final int skuId;
  final String skuName;
  final double qty;
  final double previousCount;
  final double currentCount;
  final double addedCount;
  final double damagedCount;
  final double expiredCount;
  final double unitPrice;
  final double lineTotal;

  /// Photo **paths** from `/v2/uploads`, never files.
  final String currentCountPhotoPath;
  final String beforePhotoPath;
  final String afterPhotoPath;

  const ShelfLine({
    required this.id,
    required this.skuId,
    required this.skuName,
    required this.qty,
    required this.previousCount,
    required this.currentCount,
    required this.addedCount,
    required this.damagedCount,
    required this.expiredCount,
    required this.unitPrice,
    required this.lineTotal,
    required this.currentCountPhotoPath,
    required this.beforePhotoPath,
    required this.afterPhotoPath,
  });

  factory ShelfLine.fromJson(Map<String, dynamic> j) => ShelfLine(
        id: asInt(j['id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name'] ?? j['name']),
        qty: asNum(j['qty'] ?? j['sold_qty'] ?? j['counted_qty']),
        previousCount: asNum(j['previous_count']),
        currentCount: asNum(j['current_count']),
        addedCount: asNum(j['added_count']),
        damagedCount: asNum(j['damaged_count']),
        expiredCount: asNum(j['expired_count']),
        unitPrice: asNum(j['unit_price']),
        lineTotal: asNum(j['line_total']),
        currentCountPhotoPath: asStr(j['current_count_photo_path']),
        beforePhotoPath: asStr(j['before_photo_path']),
        afterPhotoPath: asStr(j['after_photo_path']),
      );

  /// What the count says moved since last time, for the operator to sanity
  /// check before submitting.
  double get impliedSold =>
      previousCount + addedCount - currentCount - damagedCount - expiredCount;
}

/// `GET /v2/shelf_adjustments/previous_count` — what the last count left on
/// the shelf, used to **prefill** the form rather than making someone
/// remember it.
class PreviousCount {
  final int skuId;
  final double previousCount;
  final DateTime? countedAt;

  const PreviousCount({
    required this.skuId,
    required this.previousCount,
    required this.countedAt,
  });

  factory PreviousCount.fromJson(Map<String, dynamic> j) => PreviousCount(
        skuId: asInt(j['sku_id']),
        previousCount: asNum(j['previous_count'] ?? j['count']),
        countedAt: asDate(j['counted_at'] ?? j['count_date']),
      );
}

/// A contract as the shelf panel lists it.
class ShelfContract {
  final int id;
  final String displayName;
  final String status;
  final int visitsCount;
  final Map<String, dynamic> raw;

  const ShelfContract({
    required this.id,
    required this.displayName,
    required this.status,
    required this.visitsCount,
    required this.raw,
  });

  factory ShelfContract.fromJson(Map<String, dynamic> j) => ShelfContract(
        id: asInt(j['id']),
        displayName: unwrap(j['display_name'] ?? j['name']),
        status: asStr(j['status']),
        visitsCount: asInt(j['visits_count']),
        raw: j,
      );
}

/// A visit to a shelf. The payload is not published in full, so the row is
/// kept alongside the fields that are.
class ShelfVisit {
  final int id;
  final String visitType;
  final String status;
  final DateTime? visitedAt;
  final String notes;
  final Map<String, dynamic> raw;

  const ShelfVisit({
    required this.id,
    required this.visitType,
    required this.status,
    required this.visitedAt,
    required this.notes,
    required this.raw,
  });

  factory ShelfVisit.fromJson(Map<String, dynamic> j) => ShelfVisit(
        id: asInt(j['id']),
        visitType: asStr(j['visit_type']),
        status: asStr(j['status']),
        visitedAt: asDate(j['visited_at'] ?? j['created_at']),
        notes: unwrap(j['notes']),
        raw: j,
      );
}

/// Branch-to-branch movement inside one organization («النقل الداخلي»).
///
/// `draft` → `approved` → `in_transit` → `received` → `closed`, or
/// `canceled` (with a reason). Dispatch and receipt happen in the warehouse
/// / driver flow; the supplier app creates, approves, cancels and closes.
///
/// Older JSON style: the raw Eloquent row with its relations nested
/// (`source_branch`, `requested_by`, `lines[].sku`), quantities as
/// `"5.000"` strings.
class InternalTransfer {
  final int id;
  final int sourceBranchId;
  final int destinationBranchId;
  final DateTime? requiredByDate;
  final String priority;
  final String status;
  final List<TransferLine> lines;

  final String code;
  final String notes;
  final DateTime? createdAt;
  final NamedPlace? sourceBranch;
  final NamedPlace? destinationBranch;
  final String requestedBy;
  final String approvedBy;
  final String driverName;
  final String vehiclePlate;
  final String cancellationReason;

  const InternalTransfer({
    required this.id,
    required this.sourceBranchId,
    required this.destinationBranchId,
    required this.requiredByDate,
    required this.priority,
    required this.status,
    required this.lines,
    this.code = '',
    this.notes = '',
    this.createdAt,
    this.sourceBranch,
    this.destinationBranch,
    this.requestedBy = '',
    this.approvedBy = '',
    this.driverName = '',
    this.vehiclePlate = '',
    this.cancellationReason = '',
  });

  factory InternalTransfer.fromJson(Map<String, dynamic> j) {
    final source = NamedPlace.maybe(j['source_branch']);
    final destination = NamedPlace.maybe(j['destination_branch']);
    final driver = asMap(j['driver']);
    return InternalTransfer(
      id: asInt(j['id']),
      sourceBranchId: asIntOrNull(j['source_branch_id']) ?? source?.id ?? 0,
      destinationBranchId: asIntOrNull(j['destination_branch_id']) ?? destination?.id ?? 0,
      // A bare `Y-m-d`: a calendar day, not an instant.
      requiredByDate: asDate(j['required_by_date']),
      priority: asStr(j['priority']),
      status: asStr(j['status']),
      lines: asList(j['lines'], TransferLine.fromJson),
      code: asStr(j['code']),
      notes: unwrap(j['notes']),
      createdAt: fleetTime(j['created_at']),
      sourceBranch: source,
      destinationBranch: destination,
      requestedBy: personName(j['requested_by']),
      approvedBy: personName(j['approved_by']),
      driverName: driver.isEmpty
          ? ''
          : (asStr(driver['name']).isNotEmpty ? asStr(driver['name']) : personName(driver['user'])),
      vehiclePlate: asStr(asMap(j['vehicle'])['plate_number']),
      cancellationReason: unwrap(j['cancellation_reason']),
    );
  }

  bool get isDraft => status == 'draft';

  /// Once the goods have arrived; the server has the final say.
  bool get canClose => status == 'received';

  /// `{first_name, last_name}` (a user row), or a plain `name`.
  static String personName(dynamic v) {
    if (v is! Map) return asStr(v);
    final m = asMap(v);
    final full = '${asStr(m['first_name'])} ${asStr(m['last_name'])}'.trim();
    return full.isNotEmpty ? full : asStr(m['name']);
  }

  static const priorities = ['normal', 'urgent', 'critical'];

  static const statuses = ['draft', 'approved', 'in_transit', 'received', 'closed', 'canceled'];
}

class TransferLine {
  final int id;
  final int skuId;
  final String skuName;
  final double requestedQty;
  final double fulfilledQty;

  /// From the nested `sku` (`sku_code`); the list loads it without the
  /// product, the detail with it (`sku.product`).
  final String skuCode;
  final String skuNameAr;
  final String skuNameEn;

  const TransferLine({
    required this.id,
    required this.skuId,
    required this.skuName,
    required this.requestedQty,
    required this.fulfilledQty,
    this.skuCode = '',
    this.skuNameAr = '',
    this.skuNameEn = '',
  });

  factory TransferLine.fromJson(Map<String, dynamic> j) {
    final sku = asMap(j['sku']);
    final product = asMap(sku['product']);
    String pick(String key) {
      final own = unwrap(sku[key]);
      return own.isNotEmpty ? own : unwrap(product[key]);
    }

    return TransferLine(
      id: asInt(j['id']),
      skuId: asInt(j['sku_id']),
      skuName: unwrap(j['sku_name'] ?? j['name'] ?? sku['name'] ?? product['name']),
      requestedQty: asNum(j['requested_qty']),
      fulfilledQty: asNum(j['fulfilled_qty']),
      skuCode: asStr(sku['sku_code']).isNotEmpty ? asStr(sku['sku_code']) : asStr(sku['code']),
      skuNameAr: pick('name_ar'),
      skuNameEn: pick('name_en'),
    );
  }

  /// A readable label: the localized name, the plain name, else the code.
  String label(String locale) {
    final localized = pickLocalized(locale: locale, ar: skuNameAr, en: skuNameEn);
    if (localized.isNotEmpty) return localized;
    if (skuName.isNotEmpty) return skuName;
    return skuCode.isNotEmpty ? skuCode : '#$skuId';
  }
}
