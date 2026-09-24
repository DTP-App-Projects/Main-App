import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../../core/workspace/workspace.dart';
import '../api_paths.dart';
import '../models/trade/purchase_order.dart';

/// Drafts and purchase orders.
///
/// Drafts are **trader-workspace only** — calling them from a supplier-mode
/// organization is a `403 organization_workspace_not_allowed`, which is a
/// navigation bug on our side, not a user-facing condition.
class OrdersRepository {
  final ApiClient _client;

  OrdersRepository(this._client);

  // ------------------------------------------------------------------ drafts

  Future<ApiResult<Paged<PurchaseDraft>>> drafts({
    int page = 1,
    String? status,
    int limit = 15,
  }) =>
      _client.get<Paged<PurchaseDraft>>(
        ApiPaths.purchaseDrafts,
        query: {...PageParams.limit(page, size: limit), 'status': ?status},
        parse: (body) => Paged.fromJson(asMap(body), PurchaseDraft.fromJson),
      );

  Future<ApiResult<PurchaseDraft>> draft(int id) => _client.get<PurchaseDraft>(
        ApiPaths.purchaseDraft(id),
        parse: (body) => PurchaseDraft.fromJson(asMap(asMap(body)['draft'])),
      );

  /// Upsert — pass [draftId] to update. Safe to retry, which matters because
  /// this is the first call in the order flow.
  Future<ApiResult<PurchaseDraft>> saveDraft({
    int? draftId,
    required int supplierOrganizationId,
    int? relationshipId,
    int? deliveryBranchId,
    int? paymentTermId,
    int? contractId,
    String? notes,
  }) =>
      _client.post<PurchaseDraft>(
        ApiPaths.purchaseDrafts,
        body: {
          'draft_id': ?draftId,
          'supplier_organization_id': supplierOrganizationId,
          'relationship_id': ?relationshipId,
          'delivery_branch_id': ?deliveryBranchId,
          'payment_term_id': ?paymentTermId,
          'contract_id': ?contractId,
          'notes': ?notes,
        },
        parse: (body) => PurchaseDraft.fromJson(asMap(asMap(body)['draft'])),
      );

  /// Rejections here are per-line and specific — `qty_less_than_min_order_qty`,
  /// `qty_not_matching_order_step`, `insufficient_supplier_inventory`,
  /// `pricing_not_found_for_sku`, `sku_not_belong_to_draft_supplier`. Each one
  /// is shown against the line that caused it.
  Future<ApiResult<PurchaseDraft>> addLine({
    required int draftId,
    required int skuId,
    required double qty,
  }) =>
      _client.post<PurchaseDraft>(
        ApiPaths.purchaseDraftLines(draftId),
        body: {'sku_id': skuId, 'qty': qty},
        parse: (body) {
          final map = asMap(body);
          // The endpoint answers with the draft when it can, and with the
          // bare line when it cannot.
          return PurchaseDraft.fromJson(asMap(map['draft']));
        },
      );

  Future<ApiResult<void>> removeLine({required int draftId, required int lineId}) =>
      _client.delete<void>(ApiPaths.purchaseDraftLine(draftId, lineId));

  /// **Never auto-retried.** A submit that times out may have succeeded; the
  /// user re-checks the order list rather than sending a second one.
  Future<ApiResult<PurchaseOrder>> submitDraft(int draftId) => _client.post<PurchaseOrder>(
        ApiPaths.purchaseDraftSubmit(draftId),
        parse: (body) => PurchaseOrder.fromJson(asMap(asMap(body)['purchase_order'])),
      );

  // ------------------------------------------------------------------ orders

  /// `?role=` is **always** sent: omitting it merges both sides of a hybrid
  /// organization's orders into one list.
  ///
  /// `status` is comma-separated multi-value (`submitted,under_review`).
  Future<ApiResult<Paged<PurchaseOrder>>> orders({
    required Workspace role,
    int page = 1,
    List<String> statuses = const [],
    int? businessRelationshipId,
    String? creditCheckStatus,
    int limit = 15,
  }) =>
      _client.get<Paged<PurchaseOrder>>(
        ApiPaths.purchaseOrders,
        query: {
          ...PageParams.limit(page, size: limit),
          'role': role.api,
          if (statuses.isNotEmpty) 'status': statuses.join(','),
          'business_relationship_id': ?businessRelationshipId,
          'credit_check_status': ?creditCheckStatus,
        },
        parse: (body) => Paged.fromJson(asMap(body), PurchaseOrder.fromJson),
      );

  /// The detail is what carries `allowed_transitions`, `reason_required_for`,
  /// `next_action`, `viewer_role` and `can_request_cancel` — everything the
  /// action bar is built from.
  Future<ApiResult<PurchaseOrder>> order(int id) => _client.get<PurchaseOrder>(
        ApiPaths.purchaseOrder(id),
        parse: (body) => PurchaseOrder.fromJson(asMap(asMap(body)['purchase_order'])),
      );

  /// A note is required (3–500 chars) on `rejected` and `canceled`, else
  /// `400 reason_required`. The caller reads `reason_required_for` rather
  /// than assuming which ones.
  Future<ApiResult<PurchaseOrder>> changeStatus({
    required int id,
    required String status,
    String? note,
  }) =>
      _client.patch<PurchaseOrder>(
        ApiPaths.purchaseOrderStatus(id),
        body: {'status': status, 'note': ?note},
        parse: (body) => PurchaseOrder.fromJson(asMap(asMap(body)['purchase_order'])),
      );

  /// After approval the trader may only **ask** to cancel; the supplier
  /// decides. Not auto-retried.
  Future<ApiResult<void>> requestCancel({required int id, required String reason}) =>
      _client.post<void>(
        ApiPaths.purchaseOrderCancelRequest(id),
        body: {'reason': reason},
      );

  /// The answer to a cancellation request. A note is required on a rejection.
  Future<ApiResult<void>> decideCancelRequest({
    required int id,
    required String decision,
    String? note,
  }) =>
      _client.post<void>(
        ApiPaths.purchaseOrderCancelDecision(id),
        body: {'decision': decision, 'note': ?note},
      );

  Future<ApiResult<List<TimelineEvent>>> timeline(int id) => _client.get<List<TimelineEvent>>(
        ApiPaths.purchaseOrderTimeline(id),
        parse: (body) {
          final map = asMap(body);
          return asList(map['timeline'] ?? map['events'] ?? body, TimelineEvent.fromJson);
        },
      );
}
