import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../../core/workspace/workspace.dart';
import '../api_paths.dart';
import '../models/trade/delivery_note.dart';

/// Incoming shipments and the receipts raised against them.
///
/// The trader reads delivery notes and writes goods receipts; the supplier
/// does the reverse. Same models, opposite verbs.
class ShipmentsRepository {
  final ApiClient _client;

  ShipmentsRepository(this._client);

  // ---------------------------------------------------------- delivery notes

  Future<ApiResult<Paged<DeliveryNote>>> deliveryNotes({
    required Workspace role,
    int page = 1,
    List<String> statuses = const [],
    int? purchaseOrderId,
    bool? excludeClosed,
    int limit = 15,
  }) =>
      _client.get<Paged<DeliveryNote>>(
        ApiPaths.deliveryNotes,
        query: {
          ...PageParams.limit(page, size: limit),
          'role': role.api,
          if (statuses.isNotEmpty) 'status': statuses.join(','),
          'purchase_order_id': ?purchaseOrderId,
          if (excludeClosed == true) 'exclude_closed': 1,
        },
        parse: (body) => Paged.fromJson(asMap(body), DeliveryNote.fromJson),
      );

  Future<ApiResult<DeliveryNote>> deliveryNote(int id) => _client.get<DeliveryNote>(
        ApiPaths.deliveryNote(id),
        parse: (body) => DeliveryNote.fromJson(asMap(asMap(body)['delivery_note'])),
      );

  /// The live snapshot behind "track my order".
  ///
  /// Polled at 5 s while the screen is visible and cancelled on dispose — the
  /// global cap is 60 requests a minute for everything the app does.
  Future<ApiResult<DeliveryNote>> tracking(int id) => _client.get<DeliveryNote>(
        ApiPaths.deliveryNoteTracking(id),
        // Polling must not be collapsed into one stale in-flight answer.
        dedupe: false,
        parse: (body) => DeliveryNote.fromJson(asMap(asMap(body)['delivery_note'])),
      );

  /// Supplier-only **upsert** — send [deliveryNoteId] to update.
  ///
  /// `422 supplier_or_trader_branch_missing` when either end has no branch.
  Future<ApiResult<DeliveryNote>> saveDeliveryNote({
    int? deliveryNoteId,
    required int purchaseOrderId,
    int? supplierBranchId,
    int? traderBranchId,
    String? proofFile,
    String? notes,
    List<DeliveryLineInput> lines = const [],
  }) =>
      _client.post<DeliveryNote>(
        ApiPaths.deliveryNotes,
        body: {
          'delivery_note_id': ?deliveryNoteId,
          'purchase_order_id': purchaseOrderId,
          'supplier_branch_id': ?supplierBranchId,
          'trader_branch_id': ?traderBranchId,
          'proof_file': ?proofFile,
          'notes': ?notes,
          if (lines.isNotEmpty) 'lines': lines.map((l) => l.toJson()).toList(),
        },
        parse: (body) => DeliveryNote.fromJson(asMap(asMap(body)['delivery_note'])),
      );

  /// 1–50 seals, each ≤ 64 characters.
  ///
  /// **`409 seals_can_only_be_set_before_dispatch`** once it is on the road —
  /// a final answer, not a transient failure.
  Future<ApiResult<DeliveryNote>> setSeals({
    required int id,
    required List<String> seals,
  }) =>
      _client.post<DeliveryNote>(
        ApiPaths.deliveryNoteSeals(id),
        body: {'seals': seals},
        parse: (body) => DeliveryNote.fromJson(asMap(asMap(body)['delivery_note'])),
      );

  /// `dispatched` | `delivered` | `rejected`.
  ///
  /// **`422 pickup_seals_required_before_dispatch`** is the one to expect:
  /// the seals have to go on first.
  Future<ApiResult<DeliveryNote>> changeDeliveryStatus({
    required int id,
    required String status,
    String? proofFile,
    String? note,
  }) =>
      _client.patch<DeliveryNote>(
        ApiPaths.deliveryNoteStatus(id),
        body: {'status': status, 'proof_file': ?proofFile, 'note': ?note},
        parse: (body) => DeliveryNote.fromJson(asMap(asMap(body)['delivery_note'])),
      );

  /// Works even mid-route. `reason` is one of [cancelReasons].
  Future<ApiResult<void>> cancelDelivery({
    required int id,
    required String reason,
    String? note,
  }) =>
      _client.post<void>(
        ApiPaths.deliveryNoteCancel(id),
        body: {'reason': reason, 'note': ?note},
      );

  /// `422 delivery_note_not_reschedulable_in_status_<x>` when it is too late.
  Future<ApiResult<DeliveryNote>> reschedule({
    required int id,
    required DateTime routeDate,
  }) =>
      _client.post<DeliveryNote>(
        ApiPaths.deliveryNoteReschedule(id),
        body: {'route_date': _day(routeDate)},
        parse: (body) => DeliveryNote.fromJson(asMap(asMap(body)['delivery_note'])),
      );

  /// The supplier's dispatch board. Supplier workspace only.
  Future<ApiResult<List<DeliveryNote>>> supplierFleet() => _client.get<List<DeliveryNote>>(
        ApiPaths.supplierFleet,
        dedupe: false,
        parse: (body) => asList(asMap(body)['deliveries'], DeliveryNote.fromJson),
      );

  /// The documented cancellation reasons. Free text is not accepted.
  static const cancelReasons = [
    'out_of_stock',
    'order_canceled',
    'order_error',
    'vehicle_issue',
    'trader_request',
    'other',
  ];

  static const deliveryStatuses = ['dispatched', 'delivered', 'rejected'];

  static String _day(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  // ----------------------------------------------------------- goods receipts

  Future<ApiResult<Paged<GoodsReceipt>>> goodsReceipts({
    int page = 1,
    String? status,
    int? purchaseOrderId,
    int? deliveryNoteId,
    int limit = 15,
  }) =>
      _client.get<Paged<GoodsReceipt>>(
        ApiPaths.goodsReceipts,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'purchase_order_id': ?purchaseOrderId,
          'delivery_note_id': ?deliveryNoteId,
        },
        parse: (body) => Paged.fromJson(asMap(body), GoodsReceipt.fromJson),
      );

  Future<ApiResult<GoodsReceipt>> goodsReceipt(int id) => _client.get<GoodsReceipt>(
        ApiPaths.goodsReceipt(id),
        parse: (body) => GoodsReceipt.fromJson(asMap(asMap(body)['goods_receipt'])),
      );

  /// Trader-only. [proofFile] is a **path from `/v2/uploads`**, not a file —
  /// this is the two-step pattern, unlike onboarding documents.
  ///
  /// Not auto-retried: a receipt is not an upsert.
  Future<ApiResult<GoodsReceipt>> createGoodsReceipt({
    required int deliveryNoteId,
    required List<GoodsReceiptLineInput> lines,
    String? proofFile,
    String? notes,
  }) =>
      _client.post<GoodsReceipt>(
        ApiPaths.goodsReceipts,
        body: {
          'delivery_note_id': deliveryNoteId,
          'proof_file': ?proofFile,
          'notes': ?notes,
          'lines': lines.map((line) => line.toJson()).toList(),
        },
        parse: (body) => GoodsReceipt.fromJson(asMap(asMap(body)['goods_receipt'])),
      );

  /// `reason` is 10–1000 characters. A `410 goods_receipt_edit_window_closed`
  /// means the window has passed — a real answer, not a transient failure.
  Future<ApiResult<void>> dispute({required int id, required String reason}) =>
      _client.post<void>(ApiPaths.goodsReceiptDispute(id), body: {'reason': reason});
}

/// One line of a delivery note as the supplier ships it.
class DeliveryLineInput {
  final int? purchaseOrderLineId;
  final int skuId;
  final double shippedQty;

  const DeliveryLineInput({
    required this.skuId,
    required this.shippedQty,
    this.purchaseOrderLineId,
  });

  Map<String, dynamic> toJson() => {
        'purchase_order_line_id': ?purchaseOrderLineId,
        'sku_id': skuId,
        'shipped_qty': shippedQty,
      };
}

/// One line of a goods receipt as the trader counts it.
class GoodsReceiptLineInput {
  final int deliveryNoteLineId;
  final int skuId;
  final double receivedQty;
  final double rejectedQty;
  final String? rejectionReason;

  const GoodsReceiptLineInput({
    required this.deliveryNoteLineId,
    required this.skuId,
    required this.receivedQty,
    this.rejectedQty = 0,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'delivery_note_line_id': deliveryNoteLineId,
        'sku_id': skuId,
        'received_qty': receivedQty,
        'rejected_qty': rejectedQty,
        'rejection_reason': ?rejectionReason,
      };
}
