import '../../../core/network/coerce.dart';

/// Streams C and D: return notes, returnable quantities, dispute packs,
/// late payment, Nafith. Verified on staging 2026-10-05 unless noted.

/// `return_notes` (template ز), numbered `RN-`.
class ReturnNote {
  final int id;
  final String returnNo;
  final int purchaseOrderId;
  final String purchaseOrderNo;
  final int invoiceId;
  final String invoiceNo;

  /// `requested`, `accepted`, `rejected`, `credit_issued`, `goods_returned`.
  final String status;
  final String statusLabel;

  /// `defect`, `shortage_correction`, `unsold_consignment`, `agreed`.
  final String reason;
  final String reasonLabel;
  final String reasonNotes;

  /// `trader` / `supplier`: who asked, and who accepts (level 2).
  final String requestedBySide;
  final String acceptingSide;
  final DateTime? acceptedAt;
  final DateTime? goodsReturnedAt;
  final DateTime? returnDueAt;
  final int creditNoteId;
  final String creditNoteNo;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final String currencyCode;
  final String documentHash;
  final String pdfUrl;
  final List<ReturnNoteLine> lines;
  final DateTime? createdAt;

  const ReturnNote({
    required this.id,
    this.returnNo = '',
    this.purchaseOrderId = 0,
    this.purchaseOrderNo = '',
    this.invoiceId = 0,
    this.invoiceNo = '',
    this.status = '',
    this.statusLabel = '',
    this.reason = '',
    this.reasonLabel = '',
    this.reasonNotes = '',
    this.requestedBySide = '',
    this.acceptingSide = '',
    this.acceptedAt,
    this.goodsReturnedAt,
    this.returnDueAt,
    this.creditNoteId = 0,
    this.creditNoteNo = '',
    this.subtotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.currencyCode = 'SAR',
    this.documentHash = '',
    this.pdfUrl = '',
    this.lines = const [],
    this.createdAt,
  });

  bool get hasInvoice => invoiceId > 0;
  bool get hasCreditNote => creditNoteId > 0;

  factory ReturnNote.fromJson(Map<String, dynamic> j) => ReturnNote(
        id: asInt(j['id']),
        returnNo: asStr(j['return_no']),
        purchaseOrderId: asInt(j['purchase_order_id']),
        purchaseOrderNo: asStr(j['purchase_order_no']),
        invoiceId: asInt(j['invoice_id']),
        invoiceNo: asStr(j['invoice_no']),
        status: asStr(j['status']),
        statusLabel: unwrap(j['status_label']),
        reason: asStr(j['reason']),
        reasonLabel: unwrap(j['reason_label']),
        reasonNotes: unwrap(j['reason_notes']),
        requestedBySide: asStr(j['requested_by_side']),
        acceptingSide: asStr(j['accepting_side']),
        acceptedAt: asUtcDate(j['accepted_at']),
        goodsReturnedAt: asUtcDate(j['goods_returned_at']),
        returnDueAt: asUtcDate(j['return_due_at']),
        creditNoteId: asInt(j['credit_note_id']),
        creditNoteNo: asStr(j['credit_note_no']),
        subtotal: asNum(j['subtotal']),
        taxTotal: asNum(j['tax_total']),
        grandTotal: asNum(j['grand_total']),
        currencyCode: asStr(j['currency_code']).isEmpty ? 'SAR' : asStr(j['currency_code']),
        documentHash: asStr(j['document_hash']),
        pdfUrl: asStr(j['pdf_url']),
        lines: asList(j['lines'], ReturnNoteLine.fromJson),
        createdAt: asUtcDate(j['created_at']),
      );
}

class ReturnNoteLine {
  final int id;
  final int skuId;
  final String skuName;
  final double qty;
  final String goodsCondition;
  final double unitPrice;
  final double taxValue;
  final double lineTotal;

  const ReturnNoteLine({
    required this.id,
    this.skuId = 0,
    this.skuName = '',
    this.qty = 0,
    this.goodsCondition = '',
    this.unitPrice = 0,
    this.taxValue = 0,
    this.lineTotal = 0,
  });

  factory ReturnNoteLine.fromJson(Map<String, dynamic> j) => ReturnNoteLine(
        id: asInt(j['id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name']),
        qty: asNum(j['qty']),
        goodsCondition: unwrap(j['goods_condition']),
        unitPrice: asNum(j['unit_price']),
        taxValue: asNum(j['tax_value']),
        lineTotal: asNum(j['line_total']),
      );
}

/// `GET purchase_orders/{id}/returnable_quantities` — the caps for a new
/// return, and the reasons this order's supply model allows.
class Returnable {
  final int purchaseOrderId;
  final String supplyModel;
  final List<ReturnReason> reasons;
  final Map<int, double> qtyBySku;

  /// Consignment only: what is still in the trader's custody per SKU.
  final Map<int, double> custodyBySku;

  const Returnable({
    required this.purchaseOrderId,
    this.supplyModel = '',
    this.reasons = const [],
    this.qtyBySku = const {},
    this.custodyBySku = const {},
  });

  factory Returnable.fromJson(Map<String, dynamic> raw) {
    final j = raw['data'] is Map ? asMap(raw['data']) : raw;
    final lines = asList(j['lines'], (m) => m);
    return Returnable(
      purchaseOrderId: asInt(j['purchase_order_id']),
      supplyModel: asStr(j['supply_model']),
      reasons: asList(j['reasons'], ReturnReason.fromJson),
      qtyBySku: {for (final l in lines) asInt(l['sku_id']): asNum(l['returnable_qty'])},
      custodyBySku: {
        for (final l in lines)
          if (l['custody_remaining_qty'] != null) asInt(l['sku_id']): asNum(l['custody_remaining_qty']),
      },
    );
  }
}

class ReturnReason {
  final String key;
  final String label;

  const ReturnReason({required this.key, required this.label});

  factory ReturnReason.fromJson(Map<String, dynamic> j) =>
      ReturnReason(key: asStr(j['key']), label: unwrap(j['label']));
}

/// `dispute_packs` (template م): one ZIP with a PDF, the JSON of every
/// document and a SHA-256 per item.
class DisputePack {
  final int id;
  final String packNo;

  /// `purchase_order`, `invoice`, `relationship`.
  final String scopeType;
  final int scopeId;
  final int relationshipId;
  final String requesterSide;
  final String zipSha256;
  final String pdfSha256;
  final int itemsCount;

  /// Items that were never frozen («مستند حي — غير مجمد»).
  final int liveItemsCount;

  /// UTC (`generated_at_utc` is offset-less UTC).
  final DateTime? generatedAt;
  final double principalOutstanding;
  final List<DisputePackItem> items;

  const DisputePack({
    required this.id,
    this.packNo = '',
    this.scopeType = '',
    this.scopeId = 0,
    this.relationshipId = 0,
    this.requesterSide = '',
    this.zipSha256 = '',
    this.pdfSha256 = '',
    this.itemsCount = 0,
    this.liveItemsCount = 0,
    this.generatedAt,
    this.principalOutstanding = 0,
    this.items = const [],
  });

  factory DisputePack.fromJson(Map<String, dynamic> j) => DisputePack(
        id: asInt(j['id']),
        packNo: asStr(j['pack_no']),
        scopeType: asStr(j['scope_type']),
        scopeId: asInt(j['scope_id']),
        relationshipId: asInt(j['business_relationship_id']),
        requesterSide: asStr(j['requester_side']),
        zipSha256: asStr(j['zip_sha256']),
        pdfSha256: asStr(j['pdf_sha256']),
        itemsCount: asInt(j['items_count']),
        liveItemsCount: asInt(j['live_items_count']),
        generatedAt: asUtcNaive(j['generated_at_utc']),
        principalOutstanding: asNum(j['principal_outstanding']),
        items: asList(j['items'], DisputePackItem.fromJson),
      );
}

class DisputePackItem {
  final String type;
  final String label;
  final String number;
  final String sha256;

  /// `frozen`, `live` or `log`.
  final String source;
  final int? frozenDocumentId;
  final int? revision;

  const DisputePackItem({
    required this.type,
    this.label = '',
    this.number = '',
    this.sha256 = '',
    this.source = '',
    this.frozenDocumentId,
    this.revision,
  });

  bool get isLive => source == 'live';

  factory DisputePackItem.fromJson(Map<String, dynamic> j) => DisputePackItem(
        type: asStr(j['type']),
        label: unwrap(j['label']),
        number: asStr(j['number']),
        sha256: asStr(j['sha256']),
        source: asStr(j['source']),
        frozenDocumentId: asIntOrNull(j['frozen_document_id']),
        revision: asIntOrNull(j['revision']),
      );
}

/// `GET invoices/{id}/late_payment`. **No amount here is a penalty**: the
/// outstanding is principal only (`amount_basis: principal_only`).
class LatePaymentStatus {
  /// `active`, `supply_suspended`, `accelerated`.
  final String supplyStatus;
  final String supplyStatusLabel;
  final DateTime? supplyStatusChangedAt;
  final String side;
  final double outstanding;
  final bool isPastDue;
  final DateTime? originalDueDate;
  final DateTime? acceleratedAt;
  final bool canIssueFirst;
  final bool canIssueSecond;
  final bool canRestore;
  final List<LatePaymentNotice> notices;

  const LatePaymentStatus({
    this.supplyStatus = 'active',
    this.supplyStatusLabel = '',
    this.supplyStatusChangedAt,
    this.side = '',
    this.outstanding = 0,
    this.isPastDue = false,
    this.originalDueDate,
    this.acceleratedAt,
    this.canIssueFirst = false,
    this.canIssueSecond = false,
    this.canRestore = false,
    this.notices = const [],
  });

  factory LatePaymentStatus.fromJson(Map<String, dynamic> raw) {
    final j = raw['late_payment'] is Map ? asMap(raw['late_payment']) : raw;
    return LatePaymentStatus(
      supplyStatus: asStr(j['supply_status']).isEmpty ? 'active' : asStr(j['supply_status']),
      supplyStatusLabel: unwrap(j['supply_status_label']),
      supplyStatusChangedAt: asUtcDate(j['supply_status_changed_at']),
      side: asStr(j['side']),
      outstanding: asNum(j['outstanding']),
      isPastDue: asBool(j['is_past_due']),
      originalDueDate: asDate(j['original_due_date']),
      acceleratedAt: asUtcDate(j['accelerated_at']),
      canIssueFirst: asBool(j['can_issue_first']),
      canIssueSecond: asBool(j['can_issue_second']),
      canRestore: asBool(j['can_restore']),
      notices: asList(j['notices'], LatePaymentNotice.fromJson),
    );
  }
}

/// A notice (NTC1 / NTC2, templates ي/ك). UNVERIFIED row shape — no invoice on
/// staging was past due, so none could be issued (`late_payment_not_overdue`).
/// Deliberately has **no amount field**: notices never show a penalty.
class LatePaymentNotice {
  final int id;
  final String noticeNo;

  /// `first` or `second`.
  final String kind;
  final String status;
  final String statusLabel;
  final int invoiceId;
  final String invoiceNo;
  final DateTime? issuedAt;
  final DateTime? graceEndsAt;

  const LatePaymentNotice({
    required this.id,
    this.noticeNo = '',
    this.kind = '',
    this.status = '',
    this.statusLabel = '',
    this.invoiceId = 0,
    this.invoiceNo = '',
    this.issuedAt,
    this.graceEndsAt,
  });

  factory LatePaymentNotice.fromJson(Map<String, dynamic> j) => LatePaymentNotice(
        id: asInt(j['id'] ?? j['notice_id']),
        noticeNo: asStr(j['notice_no'] ?? j['number']),
        kind: asStr(j['kind']),
        status: asStr(j['status']),
        statusLabel: unwrap(j['status_label']),
        invoiceId: asInt(j['invoice_id']),
        invoiceNo: asStr(j['invoice_no']),
        issuedAt: asUtcDate(j['issued_at'] ?? j['created_at']),
        graceEndsAt: asUtcDate(j['grace_ends_at'] ?? j['grace_until']),
      );
}

/// `GET invoices/{id}/promissory_notes` — Nafith only; no PDF upload.
class PromissoryNotes {
  final List<PromissoryNote> notes;

  /// When false, open [fallbackUrl] and record the instrument number.
  final bool apiEnabled;
  final String fallbackUrl;

  /// Credit invoices only; cash ones answer `eligible: false`.
  final bool eligible;

  /// Pre-filled Article 87 elements; the amount equals the invoice's
  /// outstanding to the halala (`amount_rule: invoice_outstanding_exact`).
  final double amount;
  final String currency;
  final DateTime? maturityDate;
  final String beneficiaryName;
  final String drawerName;

  const PromissoryNotes({
    this.notes = const [],
    this.apiEnabled = false,
    this.fallbackUrl = '',
    this.eligible = false,
    this.amount = 0,
    this.currency = 'SAR',
    this.maturityDate,
    this.beneficiaryName = '',
    this.drawerName = '',
  });

  factory PromissoryNotes.fromJson(Map<String, dynamic> j) {
    final d = asMap(j['defaults']);
    return PromissoryNotes(
      notes: asList(j['promissory_notes'], PromissoryNote.fromJson),
      apiEnabled: asBool(j['api_enabled']),
      fallbackUrl: asStr(j['fallback_url']),
      eligible: asBool(j['eligible']),
      amount: asNum(d['amount']),
      currency: asStr(d['currency']).isEmpty ? 'SAR' : asStr(d['currency']),
      maturityDate: asDate(d['maturity_date']),
      beneficiaryName: unwrap(d['beneficiary_name']),
      drawerName: unwrap(d['drawer_name']),
    );
  }
}

/// UNVERIFIED row shape (no credit invoice on staging to issue one against).
class PromissoryNote {
  final int id;
  final String instrumentNo;
  final String status;
  final double amount;
  final DateTime? createdAt;

  const PromissoryNote({required this.id, this.instrumentNo = '', this.status = '', this.amount = 0, this.createdAt});

  factory PromissoryNote.fromJson(Map<String, dynamic> j) => PromissoryNote(
        id: asInt(j['id'] ?? j['promissory_note_id']),
        instrumentNo: asStr(j['nafith_instrument_no'] ?? j['instrument_no']),
        status: asStr(j['status']),
        amount: asNum(j['amount']),
        createdAt: asUtcDate(j['created_at']),
      );
}

/// Consignment («توريد أماني») terms on an order. Verified field names (from
/// the validator); defaults 14 / 14 / 60, cost on the buyer.
class ConsignmentTerms {
  final int stocktakeCycleDays;
  final int remittanceDaysAfterSale;
  final int unsoldReturnDays;

  /// `buyer` or `supplier`.
  final String returnCostBearer;

  const ConsignmentTerms({
    this.stocktakeCycleDays = 14,
    this.remittanceDaysAfterSale = 14,
    this.unsoldReturnDays = 60,
    this.returnCostBearer = 'buyer',
  });

  static const defaults = ConsignmentTerms();

  factory ConsignmentTerms.fromJson(Map<String, dynamic> j) => ConsignmentTerms(
        stocktakeCycleDays: asIntOrNull(j['stocktake_cycle_days']) ?? 14,
        remittanceDaysAfterSale: asIntOrNull(j['remittance_days_after_sale']) ?? 14,
        unsoldReturnDays: asIntOrNull(j['unsold_return_days']) ?? 60,
        returnCostBearer: asStr(j['return_cost_bearer']).isEmpty ? 'buyer' : asStr(j['return_cost_bearer']),
      );

  Map<String, dynamic> toJson() => {
        'stocktake_cycle_days': stocktakeCycleDays,
        'remittance_days_after_sale': remittanceDaysAfterSale,
        'unsold_return_days': unsoldReturnDays,
        'return_cost_bearer': returnCostBearer,
      };
}

/// A row of the custody ledger: received − sold − returned − losses.
/// UNVERIFIED row keys (no consignment order on staging; `{data: []}`).
class CustodyRow {
  final int skuId;
  final String skuName;
  final String supplierName;
  final double received;
  final double sold;
  final double returned;
  final double losses;
  final double balance;

  /// «مهلة الإعادة» — by when the unsold balance goes back (guide 14.2).
  final DateTime? returnDeadline;

  const CustodyRow({
    this.returnDeadline,
    required this.skuId,
    this.skuName = '',
    this.supplierName = '',
    this.received = 0,
    this.sold = 0,
    this.returned = 0,
    this.losses = 0,
    this.balance = 0,
  });

  factory CustodyRow.fromJson(Map<String, dynamic> j) {
    final received = asNum(j['received_qty'] ?? j['received']);
    final sold = asNum(j['sold_qty'] ?? j['sold']);
    final returned = asNum(j['returned_qty'] ?? j['returned']);
    final losses = asNum(j['loss_qty'] ?? j['losses']);
    return CustodyRow(
      skuId: asInt(j['sku_id']),
      skuName: unwrap(j['sku_name'] ?? j['name']),
      supplierName: unwrap(j['supplier_name']),
      received: received,
      sold: sold,
      returned: returned,
      losses: losses,
      balance: j['balance_qty'] != null || j['balance'] != null
          ? asNum(j['balance_qty'] ?? j['balance'])
          : received - sold - returned - losses,
      returnDeadline: asDate(j['return_deadline'] ?? j['return_due_date'] ?? j['return_by'] ?? j['return_due_at']),
    );
  }
}
