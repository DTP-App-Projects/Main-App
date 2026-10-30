import '../../../core/network/coerce.dart';

/// Stream D, marketer (§11, template ل). Verified on staging 2026-10-05.

/// `GET /marketer` → `{marketer, totals}`; `marketer` is null until the
/// organization (activity_type = marketer) registers its profile.
class MarketerProfile {
  final int id;
  final int organizationId;
  final String displayName;

  /// What a supplier enters to assign this marketer.
  final String referralCode;
  final String status;

  const MarketerProfile({
    required this.id,
    this.organizationId = 0,
    this.displayName = '',
    this.referralCode = '',
    this.status = '',
  });

  factory MarketerProfile.fromJson(Map<String, dynamic> j) => MarketerProfile(
        id: asInt(j['id']),
        organizationId: asInt(j['organization_id']),
        displayName: unwrap(j['display_name']),
        referralCode: asStr(j['referral_code']),
        status: asStr(j['status']),
      );
}

class MarketerOverview {
  final MarketerProfile? profile;
  final double earned;
  final double pending;
  final double voided;

  const MarketerOverview({this.profile, this.earned = 0, this.pending = 0, this.voided = 0});

  bool get isRegistered => profile != null;

  factory MarketerOverview.fromJson(Map<String, dynamic> j) {
    final totals = asMap(j['totals']);
    return MarketerOverview(
      profile: j['marketer'] is Map ? MarketerProfile.fromJson(asMap(j['marketer'])) : null,
      earned: asNum(totals['earned']),
      pending: asNum(totals['pending']),
      voided: asNum(totals['void']),
    );
  }
}

/// An `MK-` assignment: a supplier offers, the marketer accepts (level 1).
class MarketerAssignment {
  final int id;
  final String assignmentNo;
  final MarketerProfile? marketer;
  final int supplierOrganizationId;
  final String supplierName;
  final int? traderOrganizationId;
  final String traderName;

  /// `percent`, … with the server's own label (`2.5%`).
  final String rateType;
  final double rateValue;
  final String rateLabel;

  /// `offered`, `active`, `ended`.
  final String status;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  /// `invoice_collected` — commission is earned on collection, not on sale.
  final String earnedOn;
  final String documentHash;
  final DateTime? createdAt;

  const MarketerAssignment({
    required this.id,
    this.assignmentNo = '',
    this.marketer,
    this.supplierOrganizationId = 0,
    this.supplierName = '',
    this.traderOrganizationId,
    this.traderName = '',
    this.rateType = '',
    this.rateValue = 0,
    this.rateLabel = '',
    this.status = '',
    this.acceptedAt,
    this.endedAt,
    this.earnedOn = '',
    this.documentHash = '',
    this.createdAt,
  });

  bool get isOffered => status == 'offered';
  bool get isActive => status == 'active';

  factory MarketerAssignment.fromJson(Map<String, dynamic> j) => MarketerAssignment(
        id: asInt(j['id']),
        assignmentNo: asStr(j['assignment_no']),
        marketer: j['marketer'] is Map ? MarketerProfile.fromJson(asMap(j['marketer'])) : null,
        supplierOrganizationId: asInt(j['supplier_organization_id']),
        supplierName: unwrap(j['supplier_name']),
        traderOrganizationId: asIntOrNull(j['trader_organization_id']),
        traderName: unwrap(j['trader_name']),
        rateType: asStr(j['rate_type']),
        rateValue: asNum(j['rate_value']),
        rateLabel: asStr(j['rate_label']),
        status: asStr(j['status']),
        acceptedAt: asUtcDate(j['accepted_at']),
        endedAt: asUtcDate(j['ended_at']),
        earnedOn: asStr(j['earned_on']),
        documentHash: asStr(j['document_hash']),
        createdAt: asUtcDate(j['created_at']),
      );
}

/// A commission row (verified): `pending` until its invoice is paid
/// («بانتظار تحصيل الفاتورة»), then `earned`; `void` on cancel / full return
/// before collection.
class MarketerCommission {
  final int id;
  final int marketerId;
  final int assignmentId;
  final String assignmentNo;
  final int purchaseOrderId;
  final String purchaseOrderCode;
  final int? invoiceId;
  final String invoiceNo;
  final String rateType;
  final double rateValue;
  final double baseAmount;
  final double commissionAmount;
  final String currencyCode;

  /// `pending`, `earned`, `void`.
  final String status;
  final String statusLabel;
  final String voidReason;
  final DateTime? earnedAt;
  final DateTime? recomputedAt;

  const MarketerCommission({
    required this.id,
    this.marketerId = 0,
    this.assignmentId = 0,
    this.assignmentNo = '',
    this.purchaseOrderId = 0,
    this.purchaseOrderCode = '',
    this.invoiceId,
    this.invoiceNo = '',
    this.rateType = '',
    this.rateValue = 0,
    this.baseAmount = 0,
    this.commissionAmount = 0,
    this.currencyCode = 'SAR',
    this.status = '',
    this.statusLabel = '',
    this.voidReason = '',
    this.earnedAt,
    this.recomputedAt,
  });

  factory MarketerCommission.fromJson(Map<String, dynamic> j) => MarketerCommission(
        id: asInt(j['id']),
        marketerId: asInt(j['marketer_id']),
        assignmentId: asInt(j['assignment_id']),
        assignmentNo: asStr(j['assignment_no']),
        purchaseOrderId: asInt(j['purchase_order_id']),
        purchaseOrderCode: asStr(j['purchase_order_code']),
        invoiceId: asIntOrNull(j['invoice_id']),
        invoiceNo: asStr(j['invoice_no']),
        rateType: asStr(j['rate_type']),
        rateValue: asNum(j['rate_value']),
        baseAmount: asNum(j['base_amount']),
        commissionAmount: asNum(j['commission_amount']),
        currencyCode: asStr(j['currency_code']).isEmpty ? 'SAR' : asStr(j['currency_code']),
        status: asStr(j['status']),
        statusLabel: unwrap(j['status_label']),
        voidReason: unwrap(j['void_reason']),
        earnedAt: asUtcDate(j['earned_at']),
        recomputedAt: asUtcDate(j['recomputed_at']),
      );
}
