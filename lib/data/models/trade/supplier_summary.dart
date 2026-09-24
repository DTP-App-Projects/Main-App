import '../../../core/network/coerce.dart';

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

  /// Why ordering is blocked, as a stable code the UI maps to copy. `null`
  /// when [orderEntryReady].
  String? get orderBlockedReason {
    if (orderEntryReady) return null;
    if (isBlacklisted) return 'blacklisted';
    if (!hasRelationship) return 'no_relationship';
    if (relationshipStatus == 'pending_review') return 'relationship_pending';
    if (relationshipStatus != 'approved' && relationshipStatus != 'active') {
      return 'relationship_not_approved';
    }
    if (!hasActiveContract) return 'no_contract';
    return 'not_ready';
  }
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

  const BusinessRelationship({
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
      );

  bool get isApproved => status == 'approved' || status == 'active';
}
