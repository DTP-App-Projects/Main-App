import '../../../core/network/coerce.dart';
import 'pricing.dart';

/// A row from `GET /v2/catalog/suppliers` (the `formatted` payload), and the
/// detail from `/catalog/suppliers/{id}`.
class SupplierSummary {
  final int id;
  final String displayName;
  final String businessMode;
  final String supplierNature;
  final String status;
  final String profileStatus;
  final List<NamedRef> sectors;

  final int? relationshipId;

  /// `"none"` when there is no relationship at all — not null.
  final String relationshipStatus;

  final String relationshipClassification;
  final int activeContractsCount;
  final bool hasActiveContract;
  final ContractRef? latestContract;

  final int productsCount;
  final int skusCount;
  final int branchesCount;

  /// **The single boolean that gates the "Create order" button.** True only
  /// when the relationship is approved/active *and* at least one contract is
  /// active. Anything else and ordering will be refused server-side.
  final bool orderEntryReady;

  const SupplierSummary({
    required this.id,
    required this.displayName,
    required this.businessMode,
    required this.supplierNature,
    required this.status,
    required this.profileStatus,
    required this.sectors,
    required this.relationshipId,
    required this.relationshipStatus,
    required this.relationshipClassification,
    required this.activeContractsCount,
    required this.hasActiveContract,
    required this.latestContract,
    required this.productsCount,
    required this.skusCount,
    required this.branchesCount,
    required this.orderEntryReady,
  });

  factory SupplierSummary.fromJson(Map<String, dynamic> j) => SupplierSummary(
        id: asInt(j['id']),
        displayName: unwrap(j['display_name']),
        businessMode: asStr(j['business_mode']),
        supplierNature: asStr(j['supplier_nature']),
        status: asStr(j['status']),
        profileStatus: asStr(j['profile_status']),
        sectors: asList(j['sectors'], NamedRef.fromJson),
        relationshipId: asIntOrNull(j['relationship_id']),
        relationshipStatus: asStr(j['relationship_status']),
        relationshipClassification: asStr(j['relationship_classification']),
        activeContractsCount: asInt(j['active_contracts_count']),
        hasActiveContract: asBool(j['has_active_contract']),
        latestContract: j['latest_contract'] is Map
            ? ContractRef.fromJson(asMap(j['latest_contract']))
            : null,
        productsCount: asInt(j['products_count']),
        skusCount: asInt(j['skus_count']),
        branchesCount: asInt(j['branches_count']),
        orderEntryReady: asBool(j['order_entry_ready']),
      );

  bool get hasRelationship =>
      relationshipStatus.isNotEmpty && relationshipStatus != 'none';

  bool get isBlacklisted => relationshipStatus == 'blacklisted';

  /// The supplier declined the last request (live: the relationship reads
  /// `closed` once its request is `rejected`). Sending a new one reopens the
  /// same relationship as `pending_review`, so asking again is allowed.
  bool get canRequestAgain => relationshipStatus == 'closed' || relationshipStatus == 'rejected';

  /// The trader has asked and the supplier has not answered yet.
  bool get isRequestPending =>
      relationshipStatus == 'pending_review' || relationshipStatus == 'pending';

  bool get isRelationshipApproved =>
      relationshipStatus == 'approved' || relationshipStatus == 'active';

  /// Whether «إنشاء طلب» opens. [orderEntryReady] also needs an active
  /// contract, but that is the **credit** rule only: a cash order goes ahead
  /// without one («لا عقود مطابقة — يمكن المتابعة كاش بدون عقد», guide
  /// Part 8; the submit answers `contract_required_for_payment_mode` for
  /// credit / installment). The guided order then offers credit only where
  /// a contract exists.
  bool get canStartOrder => orderEntryReady || (isRelationshipApproved && !isBlacklisted);

  /// Why ordering is blocked, as a stable code the UI maps to copy. `null`
  /// when [canStartOrder].
  String? get orderBlockedReason {
    if (canStartOrder) return null;
    if (isBlacklisted) return 'blacklisted';
    if (!hasRelationship) return 'no_relationship';
    if (isRequestPending) return 'relationship_pending';
    if (canRequestAgain) return 'relationship_declined';
    if (!isRelationshipApproved) return 'relationship_not_approved';
    return 'not_ready';
  }
}

/// A row of `GET /v2/lookups/traders` — the supplier's traders directory.
class TraderSummary {
  final int id;
  final String displayName;
  final String status;
  final String logo;

  /// `none` without a relationship; otherwise its status, as for suppliers.
  final int? relationshipId;
  final String relationshipStatus;
  final String classification;
  final int activeContractsCount;
  final int openPurchaseOrdersCount;

  const TraderSummary({
    required this.id,
    required this.displayName,
    this.status = '',
    this.logo = '',
    this.relationshipId,
    this.relationshipStatus = 'none',
    this.classification = '',
    this.activeContractsCount = 0,
    this.openPurchaseOrdersCount = 0,
  });

  factory TraderSummary.fromJson(Map<String, dynamic> j) => TraderSummary(
        id: asInt(j['id']),
        displayName: unwrap(j['display_name'] ?? j['label']),
        status: asStr(j['status']),
        logo: asStr(j['logo']),
        // `0` means none on this payload.
        relationshipId: (asIntOrNull(j['relationship_id']) ?? 0) > 0
            ? asIntOrNull(j['relationship_id'])
            : null,
        relationshipStatus: asStr(j['relationship_status']).isEmpty ? 'none' : asStr(j['relationship_status']),
        classification: asStr(j['classification']),
        activeContractsCount: asInt(j['active_contracts_count']),
        openPurchaseOrdersCount: asInt(j['open_purchase_orders_count']),
      );

  bool get hasRelationship => relationshipStatus.isNotEmpty && relationshipStatus != 'none';
  bool get isRequestPending => relationshipStatus == 'pending_review' || relationshipStatus == 'pending';
  bool get canRequestAgain => relationshipStatus == 'closed' || relationshipStatus == 'rejected';
  bool get canRequest => !hasRelationship || canRequestAgain;
}

class NamedRef {
  final int id;
  final String name;

  const NamedRef({required this.id, required this.name});

  factory NamedRef.fromJson(Map<String, dynamic> j) =>
      NamedRef(id: asInt(j['id']), name: unwrap(j['name'] ?? j['display_name']));
}

class ContractRef {
  final int id;
  final String displayName;
  final String contractType;
  final String status;

  const ContractRef({
    required this.id,
    required this.displayName,
    required this.contractType,
    required this.status,
  });

  factory ContractRef.fromJson(Map<String, dynamic> j) => ContractRef(
        id: asInt(j['id']),
        displayName: unwrap(j['display_name']),
        contractType: asStr(j['contract_type']),
        status: asStr(j['status']),
      );
}

/// `GET /v2/relationships/{id}` — the trader's view of the link.
class BusinessRelationship {
  final int id;

  /// **Which side this organization is on for this relationship.** Read it;
  /// never infer the side from the active workspace switch.
  final String myRole;

  final String classification;
  final String status;
  final DateTime? openedAt;
  final NamedRef? counterparty;
  final int contractsCount;
  final int openPurchaseOrdersCount;

  /// `active`, `supply_suspended`, `accelerated` (late-payment path).
  final String supplyStatus;

  /// `REL-…` and its status, when the relationship came through a request.
  final String requestNo;
  final String requestStatus;

  /// The supplier's credit terms on this relationship (`credit` on the
  /// detail). Credit ordering needs a limit and a due policy here.
  final CreditProfile? credit;

  const BusinessRelationship({
    this.credit,
    this.supplyStatus = 'active',
    this.requestNo = '',
    this.requestStatus = '',
    required this.id,
    required this.myRole,
    required this.classification,
    required this.status,
    required this.openedAt,
    required this.counterparty,
    required this.contractsCount,
    required this.openPurchaseOrdersCount,
  });

  factory BusinessRelationship.fromJson(Map<String, dynamic> j) => BusinessRelationship(
        id: asInt(j['id']),
        myRole: asStr(j['my_role']),
        classification: asStr(j['classification']),
        status: asStr(j['status']),
        openedAt: asDate(j['opened_at']),
        counterparty: j['counterparty'] is Map
            ? NamedRef.fromJson(asMap(j['counterparty']))
            : null,
        contractsCount: asInt(j['contracts_count']),
        openPurchaseOrdersCount: asInt(j['open_purchase_orders_count']),
        supplyStatus: asStr(j['supply_status']).isEmpty ? 'active' : asStr(j['supply_status']),
        requestNo: asStr(j['request_no']),
        requestStatus: asStr(j['request_status']),
        credit: j['credit'] is Map ? CreditProfile.fromJson(asMap(j['credit'])) : null,
      );

  bool get isSupplyActive => supplyStatus == 'active';

  bool get isApproved => status == 'approved' || status == 'active';

  /// «حد ائتماني أو سياسة استحقاق»: both set and the profile active — the
  /// website's condition for offering credit on this relationship.
  bool get isCreditEnabled {
    final c = credit;
    if (c == null) return false;
    final active = c.status.isEmpty || c.status == 'active';
    return active && c.creditLimit > 0 && c.maxDueDays > 0;
  }
}
