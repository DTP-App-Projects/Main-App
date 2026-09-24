import '../../../core/network/coerce.dart';
import '../../../core/workspace/workspace.dart';
import 'supplier_summary.dart';

/// A draft is the trader's private basket. It becomes a purchase order on
/// submit, and only then does the supplier see it.
class PurchaseDraft {
  final int id;
  final String status;
  final int supplierOrganizationId;
  final int? businessRelationshipId;
  final int? deliveryBranchId;
  final int? paymentTermId;
  final int? contractId;
  final String notes;

  final double subtotal;
  final double taxTotal;
  final double grandTotal;

  final NamedRef? supplier;
  final PaymentTerm? paymentTerm;
  final int linesCount;
  final List<DraftLine> lines;

  const PurchaseDraft({
    required this.id,
    required this.status,
    required this.supplierOrganizationId,
    required this.businessRelationshipId,
    required this.deliveryBranchId,
    required this.paymentTermId,
    required this.contractId,
    required this.notes,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.supplier,
    required this.paymentTerm,
    required this.linesCount,
    required this.lines,
  });

  factory PurchaseDraft.fromJson(Map<String, dynamic> j) => PurchaseDraft(
        id: asInt(j['id']),
        status: asStr(j['status']),
        supplierOrganizationId: asInt(j['supplier_organization_id']),
        businessRelationshipId: asIntOrNull(j['business_relationship_id']),
        deliveryBranchId: asIntOrNull(j['delivery_branch_id']),
        paymentTermId: asIntOrNull(j['payment_term_id']),
        contractId: asIntOrNull(j['contract_id']),
        notes: unwrap(j['notes']),
        subtotal: asNum(j['subtotal']),
        taxTotal: asNum(j['tax_total']),
        grandTotal: asNum(j['grand_total']),
        supplier: j['supplier'] is Map ? NamedRef.fromJson(asMap(j['supplier'])) : null,
        paymentTerm:
            j['payment_term'] is Map ? PaymentTerm.fromJson(asMap(j['payment_term'])) : null,
        linesCount: asInt(j['lines_count']),
        lines: asList(j['lines'], DraftLine.fromJson),
      );

  bool get isOpen => status.isEmpty || status == 'open' || status == 'draft';
  bool get canSubmit => lines.isNotEmpty;
}

class DraftLine {
  final int id;
  final int skuId;
  final String skuName;
  final String skuCode;
  final double qty;
  final double unitPrice;
  final double lineTotal;

  const DraftLine({
    required this.id,
    required this.skuId,
    required this.skuName,
    required this.skuCode,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory DraftLine.fromJson(Map<String, dynamic> j) => DraftLine(
        id: asInt(j['id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name'] ?? j['name']),
        skuCode: asStr(j['sku_code']),
        qty: asNum(j['qty']),
        unitPrice: asNum(j['unit_price'] ?? j['final_price']),
        lineTotal: asNum(j['line_total'] ?? j['line_subtotal']),
      );
}

/// The submitted order. Both sides read this model; only the *actions* differ.
class PurchaseOrder {
  final int id;
  final String code;
  final String status;
  final String creditCheckStatus;

  final int traderOrganizationId;
  final int supplierOrganizationId;
  final int? businessRelationshipId;
  final int? paymentTermId;
  final int? deliveryBranchId;
  final DateTime? requestedDeliveryDate;
  final String notes;

  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final String currency;

  final int orderedItemsCount;
  final double orderedUnitsTotal;
  final double shippedUnitsTotal;
  final int outstandingItemsCount;
  final double outstandingUnitsTotal;

  final NamedRef? supplier;
  final NamedRef? trader;
  final PaymentTerm? paymentTerm;

  // ---- present on `show` only -------------------------------------------

  /// **Which side this organization is on for this document.** For a hybrid
  /// org it can differ order by order, so it is read, never inferred from the
  /// active workspace.
  final String viewerRole;

  /// The state machine, as the server currently defines it. Buttons are built
  /// from these; nothing about transitions is hardcoded here.
  final List<String> allowedTransitions;
  final List<String> reasonRequiredFor;
  final String nextAction;
  final bool canRequestCancel;
  final CancelRequest? cancelRequest;

  final List<TimelineEvent> timeline;
  final List<PurchaseOrderLine> lines;

  const PurchaseOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.creditCheckStatus,
    required this.traderOrganizationId,
    required this.supplierOrganizationId,
    required this.businessRelationshipId,
    required this.paymentTermId,
    required this.deliveryBranchId,
    required this.requestedDeliveryDate,
    required this.notes,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.currency,
    required this.orderedItemsCount,
    required this.orderedUnitsTotal,
    required this.shippedUnitsTotal,
    required this.outstandingItemsCount,
    required this.outstandingUnitsTotal,
    required this.supplier,
    required this.trader,
    required this.paymentTerm,
    required this.viewerRole,
    required this.allowedTransitions,
    required this.reasonRequiredFor,
    required this.nextAction,
    required this.canRequestCancel,
    required this.cancelRequest,
    required this.timeline,
    required this.lines,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
        id: asInt(j['id']),
        // An all-digit order code would arrive as a number.
        code: asStr(j['code']),
        status: asStr(j['status']),
        creditCheckStatus: asStr(j['credit_check_status']),
        traderOrganizationId: asInt(j['trader_organization_id']),
        supplierOrganizationId: asInt(j['supplier_organization_id']),
        businessRelationshipId: asIntOrNull(j['business_relationship_id']),
        paymentTermId: asIntOrNull(j['payment_term_id']),
        deliveryBranchId: asIntOrNull(j['delivery_branch_id']),
        requestedDeliveryDate: asDate(j['requested_delivery_date']),
        notes: unwrap(j['notes']),
        subtotal: asNum(j['subtotal']),
        taxTotal: asNum(j['tax_total']),
        grandTotal: asNum(j['grand_total']),
        currency: asStr(j['currency'] ?? j['currency_code']),
        orderedItemsCount: asInt(j['ordered_items_count']),
        orderedUnitsTotal: asNum(j['ordered_units_total']),
        shippedUnitsTotal: asNum(j['shipped_units_total']),
        outstandingItemsCount: asInt(j['outstanding_items_count']),
        outstandingUnitsTotal: asNum(j['outstanding_units_total']),
        supplier: j['supplier'] is Map ? NamedRef.fromJson(asMap(j['supplier'])) : null,
        trader: j['trader'] is Map ? NamedRef.fromJson(asMap(j['trader'])) : null,
        paymentTerm:
            j['payment_term'] is Map ? PaymentTerm.fromJson(asMap(j['payment_term'])) : null,
        viewerRole: asStr(j['viewer_role']),
        allowedTransitions: asStrList(j['allowed_transitions']),
        reasonRequiredFor: asStrList(j['reason_required_for']),
        nextAction: asStr(j['next_action']),
        canRequestCancel: asBool(j['can_request_cancel']),
        cancelRequest: j['cancel_request'] is Map
            ? CancelRequest.fromJson(asMap(j['cancel_request']))
            : null,
        timeline: asList(j['timeline'], TimelineEvent.fromJson),
        lines: asList(j['lines'], PurchaseOrderLine.fromJson),
      );

  Workspace? get viewerWorkspace => Workspace.tryParse(viewerRole);

  bool get isTraderView => viewerRole == 'trader';

  /// The server says a note is mandatory for these transitions — 3 to 500
  /// characters, else `400 reason_required`.
  bool requiresNote(String transition) => reasonRequiredFor.contains(transition);

  /// After approval the trader may no longer cancel directly; it may only
  /// *ask*, and the supplier decides.
  bool get mustRequestCancel => canRequestCancel && !allowedTransitions.contains('canceled');

  bool get hasOpenCancelRequest => cancelRequest?.isPending ?? false;
}

class PurchaseOrderLine {
  final int id;
  final int skuId;
  final String skuName;
  final String skuCode;
  final int? productId;
  final String productName;
  final double qty;
  final double unitPrice;
  final double taxValue;
  final double lineTotal;
  final double shippedQty;

  const PurchaseOrderLine({
    required this.id,
    required this.skuId,
    required this.skuName,
    required this.skuCode,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.taxValue,
    required this.lineTotal,
    required this.shippedQty,
  });

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> j) => PurchaseOrderLine(
        id: asInt(j['id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name'] ?? j['name']),
        skuCode: asStr(j['sku_code']),
        productId: asIntOrNull(j['product_id']),
        productName: unwrap(j['product_name']),
        qty: asNum(j['qty'] ?? j['ordered_qty']),
        unitPrice: asNum(j['unit_price']),
        taxValue: asNum(j['tax_value']),
        lineTotal: asNum(j['line_total']),
        shippedQty: asNum(j['shipped_qty']),
      );
}

class CancelRequest {
  final int? id;
  final String status;
  final String reason;
  final String decisionNote;
  final DateTime? requestedAt;
  final DateTime? decidedAt;

  const CancelRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.decisionNote,
    required this.requestedAt,
    required this.decidedAt,
  });

  factory CancelRequest.fromJson(Map<String, dynamic> j) => CancelRequest(
        id: asIntOrNull(j['id']),
        status: asStr(j['status']),
        reason: unwrap(j['reason']),
        decisionNote: unwrap(j['decision_note'] ?? j['note']),
        requestedAt: asDate(j['requested_at'] ?? j['created_at']),
        decidedAt: asDate(j['decided_at']),
      );

  bool get isPending => status.isEmpty || status == 'pending' || status == 'requested';
}

/// One row of a document's `timeline[]`.
class TimelineEvent {
  final String event;
  final String title;
  final String description;
  final String status;
  final String actorName;
  final DateTime? at;

  const TimelineEvent({
    required this.event,
    required this.title,
    required this.description,
    required this.status,
    required this.actorName,
    required this.at,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        event: asStr(j['event'] ?? j['event_code'] ?? j['type']),
        title: unwrap(j['title'] ?? j['label']),
        description: unwrap(j['description'] ?? j['text'] ?? j['note']),
        status: asStr(j['status']),
        actorName: unwrap(j['actor_name'] ?? j['user_name']),
        at: asDate(j['at'] ?? j['created_at'] ?? j['date']),
      );
}

class PaymentTerm {
  final int id;
  final String displayName;
  final String name;
  final String code;
  final String termMode;
  final int dueDays;
  final int installmentCount;
  final int installmentIntervalDays;

  const PaymentTerm({
    required this.id,
    required this.displayName,
    required this.name,
    required this.code,
    required this.termMode,
    required this.dueDays,
    required this.installmentCount,
    required this.installmentIntervalDays,
  });

  factory PaymentTerm.fromJson(Map<String, dynamic> j) => PaymentTerm(
        id: asInt(j['id']),
        displayName: unwrap(j['display_name']),
        name: unwrap(j['name']),
        code: asStr(j['code']),
        termMode: asStr(j['term_mode']),
        dueDays: asInt(j['due_days']),
        installmentCount: asInt(j['installment_count']),
        installmentIntervalDays: asInt(j['installment_interval_days']),
      );

  String get label => displayName.isNotEmpty ? displayName : (name.isNotEmpty ? name : code);
}
