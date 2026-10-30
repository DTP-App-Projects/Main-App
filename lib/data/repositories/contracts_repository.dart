import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/advanced/contract.dart';
import '../models/advanced/shelf.dart';

/// Contracts, approvals, and the consignment shelf that hangs off them.
///
/// Both workspaces use these — a contract has two sides, and which actions
/// are offered comes from the server, not from the active workspace.
class ContractsRepository {
  final ApiClient _client;

  ContractsRepository(this._client);

  // --------------------------------------------------------------- contracts

  Future<ApiResult<Paged<Contract>>> contracts({
    int page = 1,
    String? status,
    String? contractType,
    int? relationshipId,
    int limit = 15,
  }) =>
      _client.get<Paged<Contract>>(
        ApiPaths.contracts,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'contract_type': ?contractType,
          'relationship_id': ?relationshipId,
        },
        parse: (body) => Paged.fromJson(asMap(body), Contract.fromJson),
      );

  Future<ApiResult<Contract>> contract(int id) => _client.get<Contract>(
        ApiPaths.contract(id),
        parse: (body) => Contract.fromJson(asMap(asMap(body)['contract'])),
      );

  /// Upsert, and quota-gated on `max_contracts` — a refusal there is an
  /// upsell, not a crash.
  Future<ApiResult<Contract>> saveContract({
    int? contractId,
    required int relationshipId,
    required String contractType,
    String? billingPeriod,
    String? nameAr,
    String? nameEn,
    DateTime? startDate,
    DateTime? endDate,
    bool? autoRenew,
    String? status,
  }) =>
      _client.post<Contract>(
        ApiPaths.contracts,
        body: {
          'contract_id': ?contractId,
          'relationship_id': relationshipId,
          'contract_type': contractType,
          'billing_period': ?billingPeriod,
          'name_ar': ?nameAr,
          'name_en': ?nameEn,
          if (startDate != null) 'start_date': day(startDate),
          if (endDate != null) 'end_date': day(endDate),
          'auto_renew': ?autoRenew,
          'status': ?status,
        },
        parse: (body) => Contract.fromJson(asMap(asMap(body)['contract'])),
      );

  Future<ApiResult<Contract>> setContractStatus({
    required int id,
    required String status,
    String? note,
  }) =>
      _client.patch<Contract>(
        ApiPaths.contractStatus(id),
        body: {'status': status, 'note': ?note},
        parse: (body) => Contract.fromJson(asMap(asMap(body)['contract'])),
      );

  /// Needs `contracts.approve`, which is a different permission from
  /// `contracts.manage` — an approver is not necessarily an editor.
  Future<ApiResult<void>> decideContractApproval({
    required int contractId,
    required int approvalId,
    required String status,
    String? note,
  }) =>
      _client.post<void>(
        ApiPaths.contractApproval(contractId, approvalId),
        body: {'status': status, 'note': ?note},
      );

  /// The combined inbox: contracts plus pending purchase-order approvals.
  /// Both kinds of pending approval: contracts and purchase orders. It used
  /// to read `contracts` only and drop the orders.
  Future<ApiResult<ApprovalsInbox>> approvalsInbox() => _client.get<ApprovalsInbox>(
        ApiPaths.approvals,
        dedupe: false,
        parse: (body) => ApprovalsInbox.fromJson(asMap(body)),
      );

  Future<ApiResult<void>> decideOrderApproval({
    required int approvalId,
    required String status,
    String? note,
  }) =>
      _client.post<void>(
        ApiPaths.purchaseOrderApproval(approvalId),
        body: {'status': status, 'note': ?note},
      );

  // ------------------------------------------------------------------- shelf

  Future<ApiResult<Paged<ConsignmentShipment>>> consignmentShipments({
    int page = 1,
    String? status,
    int? contractId,
    int limit = 15,
  }) =>
      _client.get<Paged<ConsignmentShipment>>(
        ApiPaths.consignmentShipments,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'contract_id': ?contractId,
        },
        parse: (body) => Paged.fromJson(asMap(body), ConsignmentShipment.fromJson),
      );

  Future<ApiResult<Paged<SalesReport>>> salesReports({
    int page = 1,
    String? status,
    int? contractId,
    int limit = 15,
  }) =>
      _client.get<Paged<SalesReport>>(
        ApiPaths.salesReports,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'contract_id': ?contractId,
        },
        parse: (body) => Paged.fromJson(asMap(body), SalesReport.fromJson),
      );

  Future<ApiResult<Paged<StockCount>>> stockCounts({
    int page = 1,
    String? status,
    int? contractId,
    int limit = 15,
  }) =>
      _client.get<Paged<StockCount>>(
        ApiPaths.stockCounts,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'contract_id': ?contractId,
        },
        parse: (body) => Paged.fromJson(asMap(body), StockCount.fromJson),
      );

  Future<ApiResult<Paged<ShelfAdjustment>>> shelfAdjustments({
    int page = 1,
    String? status,
    int? contractId,
    int limit = 15,
  }) =>
      _client.get<Paged<ShelfAdjustment>>(
        ApiPaths.shelfAdjustments,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'contract_id': ?contractId,
        },
        parse: (body) => Paged.fromJson(asMap(body), ShelfAdjustment.fromJson),
      );

  /// **Prefill the count form from this.** Asking someone to remember what
  /// was on the shelf last visit is how counts go wrong.
  Future<ApiResult<List<PreviousCount>>> previousCount({
    required int contractId,
    required int branchId,
    required List<int> skuIds,
  }) =>
      _client.get<List<PreviousCount>>(
        ApiPaths.shelfPreviousCount,
        query: {
          'contract_id': contractId,
          'branch_id': branchId,
          // Arrays go as repeated `sku_ids[]` params.
          'sku_ids[]': skuIds,
        },
        parse: (body) {
          final map = asMap(body);
          return asList(map['data'] ?? map['items'], PreviousCount.fromJson);
        },
      );

  /// Upsert. Every `*_photo_path` is a **path from `/v2/uploads`**, never a
  /// file.
  Future<ApiResult<ShelfAdjustment>> saveShelfAdjustment({
    int? shelfAdjustmentId,
    required int contractId,
    required String adjustmentType,
    int? branchId,
    int? targetBranchId,
    String? visitType,
    String? notes,
    required List<ShelfLineInput> lines,
  }) =>
      _client.post<ShelfAdjustment>(
        ApiPaths.shelfAdjustments,
        body: {
          'shelf_adjustment_id': ?shelfAdjustmentId,
          'contract_id': contractId,
          'adjustment_type': adjustmentType,
          'branch_id': ?branchId,
          'target_branch_id': ?targetBranchId,
          'visit_type': ?visitType,
          'notes': ?notes,
          'lines': lines.map((line) => line.toJson()).toList(),
        },
        parse: (body) => ShelfAdjustment.fromJson(asMap(asMap(body)['shelf_adjustment'])),
      );

  Future<ApiResult<ShelfAdjustment>> setShelfAdjustmentStatus({
    required int id,
    required String status,
    String? notes,
  }) =>
      _client.patch<ShelfAdjustment>(
        ApiPaths.shelfAdjustmentStatus(id),
        body: {'status': status, 'notes': ?notes},
        parse: (body) => ShelfAdjustment.fromJson(asMap(asMap(body)['shelf_adjustment'])),
      );

  /// The shelf panel: contracts this organization has shelf duty on.
  Future<ApiResult<List<ShelfContract>>> shelfContracts() => _client.get<List<ShelfContract>>(
        ApiPaths.shelfContracts,
        parse: (body) => asList(asMap(body)['contracts'], ShelfContract.fromJson),
      );

  Future<ApiResult<List<ShelfVisit>>> shelfVisits(int contractId) =>
      _client.get<List<ShelfVisit>>(
        ApiPaths.shelfContractVisits(contractId),
        parse: (body) {
          final map = asMap(body);
          return asList(map['visits'] ?? map['items'], ShelfVisit.fromJson);
        },
      );

  /// Dates on these documents are compared as days, not timestamps.
  static String day(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// One counted SKU on a shelf adjustment.
class ShelfLineInput {
  final int skuId;
  final double? previousCount;
  final double? currentCount;
  final double? addedCount;
  final double? damagedCount;
  final double? expiredCount;

  /// Upload paths, not files.
  final String? currentCountPhotoPath;
  final String? beforePhotoPath;
  final String? afterPhotoPath;

  const ShelfLineInput({
    required this.skuId,
    this.previousCount,
    this.currentCount,
    this.addedCount,
    this.damagedCount,
    this.expiredCount,
    this.currentCountPhotoPath,
    this.beforePhotoPath,
    this.afterPhotoPath,
  });

  Map<String, dynamic> toJson() => {
        'sku_id': skuId,
        'previous_count': ?previousCount,
        'current_count': ?currentCount,
        'added_count': ?addedCount,
        'damaged_count': ?damagedCount,
        'expired_count': ?expiredCount,
        'current_count_photo_path': ?currentCountPhotoPath,
        'before_photo_path': ?beforePhotoPath,
        'after_photo_path': ?afterPhotoPath,
      };
}
