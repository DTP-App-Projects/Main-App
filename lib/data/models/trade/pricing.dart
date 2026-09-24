import '../../../core/network/coerce.dart';

/// A supplier's price list.
///
/// `scope_type` decides who it applies to, and **`scope_id` is required for
/// every scope except `default`** — omitting it is `400
/// scope_id_required_for_selected_scope`.
class PriceList {
  final int id;
  final String nameAr;
  final String nameEn;

  /// `default` | `organization` | `relationship` | `contract` | `campaign`.
  final String scopeType;

  final int? scopeId;
  final String currencyCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final int itemsCount;

  const PriceList({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.scopeType,
    required this.scopeId,
    required this.currencyCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.itemsCount,
  });

  factory PriceList.fromJson(Map<String, dynamic> j) => PriceList(
        id: asInt(j['id']),
        nameAr: unwrap(j['name_ar']),
        nameEn: unwrap(j['name_en']),
        scopeType: asStr(j['scope_type']),
        scopeId: asIntOrNull(j['scope_id']),
        currencyCode: asStr(j['currency_code']),
        startDate: asDate(j['start_date']),
        endDate: asDate(j['end_date']),
        status: asStr(j['status']),
        itemsCount: asInt(j['items_count'] ?? j['price_items_count']),
      );

  /// The documented scopes, in the order a supplier thinks about them:
  /// broadest first.
  static const scopes = ['default', 'organization', 'relationship', 'contract', 'campaign'];

  /// Only `default` stands alone; every other scope points at something.
  static bool scopeNeedsId(String scope) => scope != 'default';

  String displayName(String locale) {
    final name = pickLocalized(locale: locale, ar: nameAr, en: nameEn);
    return name.isNotEmpty ? name : '#$id';
  }

  bool get isActive => status == 'active';
}

/// One priced row inside a list: a SKU, a quantity band, and a price.
class PriceItem {
  final int id;
  final int priceListId;
  final int skuId;
  final String skuName;
  final int? paymentTermId;
  final double minQty;
  final double? maxQty;
  final double unitPrice;

  /// `amount` | `percent`.
  final String discountType;

  final double discountValue;
  final bool taxIncluded;

  const PriceItem({
    required this.id,
    required this.priceListId,
    required this.skuId,
    required this.skuName,
    required this.paymentTermId,
    required this.minQty,
    required this.maxQty,
    required this.unitPrice,
    required this.discountType,
    required this.discountValue,
    required this.taxIncluded,
  });

  factory PriceItem.fromJson(Map<String, dynamic> j) => PriceItem(
        id: asInt(j['id']),
        priceListId: asInt(j['price_list_id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name'] ?? j['name']),
        paymentTermId: asIntOrNull(j['payment_term_id']),
        minQty: asNum(j['min_qty']),
        maxQty: j['max_qty'] == null ? null : asNum(j['max_qty']),
        unitPrice: asNum(j['unit_price']),
        discountType: asStr(j['discount_type']),
        discountValue: asNum(j['discount_value']),
        taxIncluded: asBool(j['tax_included']),
      );

  static const discountTypes = ['amount', 'percent'];
}

/// The credit terms a **supplier** sets on a relationship.
///
/// `auto_freeze_on_limit` and `auto_freeze_on_overdue` are what stop the
/// trader's next order — the UI says so rather than leaving them as two
/// unexplained switches.
class CreditProfile {
  final int? id;

  /// `A`–`D`.
  final String grade;

  final double creditLimit;
  final String currencyCode;
  final int maxDueDays;
  final int maxOverdueDays;
  final double upfrontRequiredPercent;
  final bool autoFreezeOnLimit;
  final bool autoFreezeOnOverdue;
  final int reviewCycleDays;
  final String status;

  const CreditProfile({
    required this.id,
    required this.grade,
    required this.creditLimit,
    required this.currencyCode,
    required this.maxDueDays,
    required this.maxOverdueDays,
    required this.upfrontRequiredPercent,
    required this.autoFreezeOnLimit,
    required this.autoFreezeOnOverdue,
    required this.reviewCycleDays,
    required this.status,
  });

  factory CreditProfile.fromJson(Map<String, dynamic> j) => CreditProfile(
        id: asIntOrNull(j['id']),
        grade: asStr(j['grade']),
        creditLimit: asNum(j['credit_limit']),
        currencyCode: asStr(j['currency_code']),
        maxDueDays: asInt(j['max_due_days']),
        maxOverdueDays: asInt(j['max_overdue_days']),
        upfrontRequiredPercent: asNum(j['upfront_required_percent']),
        autoFreezeOnLimit: asBool(j['auto_freeze_on_limit']),
        autoFreezeOnOverdue: asBool(j['auto_freeze_on_overdue']),
        reviewCycleDays: asInt(j['review_cycle_days']),
        status: asStr(j['status']),
      );

  static const grades = ['A', 'B', 'C', 'D'];

  /// True when the next order could be stopped by one of the freeze rules.
  bool get freezesAnything => autoFreezeOnLimit || autoFreezeOnOverdue;
}

/// What the relationship currently owes, as the server calculates it.
class CreditExposure {
  final double openOrdersAmount;
  final double issuedInvoicesAmount;
  final double dueAmount;
  final double overdueAmount;
  final double availableCredit;
  final DateTime? lastCalculatedAt;

  const CreditExposure({
    required this.openOrdersAmount,
    required this.issuedInvoicesAmount,
    required this.dueAmount,
    required this.overdueAmount,
    required this.availableCredit,
    required this.lastCalculatedAt,
  });

  factory CreditExposure.fromJson(Map<String, dynamic> j) => CreditExposure(
        openOrdersAmount: asNum(j['open_orders_amount']),
        issuedInvoicesAmount: asNum(j['issued_invoices_amount']),
        dueAmount: asNum(j['due_amount']),
        overdueAmount: asNum(j['overdue_amount']),
        availableCredit: asNum(j['available_credit']),
        lastCalculatedAt: asDate(j['last_calculated_at']),
      );

  bool get hasOverdue => overdueAmount > 0;
  bool get exhausted => availableCredit <= 0;
}

/// A debit or credit note against an invoice.
class AdjustmentNote {
  final int id;
  final int invoiceId;

  /// `debit` | `credit`.
  final String noteSide;

  final String reasonType;
  final double amount;
  final String noteText;
  final String status;
  final DateTime? createdAt;

  const AdjustmentNote({
    required this.id,
    required this.invoiceId,
    required this.noteSide,
    required this.reasonType,
    required this.amount,
    required this.noteText,
    required this.status,
    required this.createdAt,
  });

  factory AdjustmentNote.fromJson(Map<String, dynamic> j) => AdjustmentNote(
        id: asInt(j['id']),
        invoiceId: asInt(j['invoice_id']),
        noteSide: asStr(j['note_side']),
        reasonType: asStr(j['reason_type']),
        amount: asNum(j['amount']),
        noteText: unwrap(j['note_text']),
        status: asStr(j['status']),
        createdAt: asDate(j['created_at']),
      );

  static const sides = ['debit', 'credit'];
  static const statuses = ['issued', 'approved', 'canceled'];

  /// A credit note reduces what the trader owes.
  bool get isCredit => noteSide == 'credit';
}
