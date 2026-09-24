import '../../../core/network/coerce.dart';
import '../../../core/workspace/workspace.dart';
import '../common/branch.dart';
import 'journey.dart';

class Organization {
  final int id;
  final String displayName;

  /// Legal identity. Present on `/v2/organization` and on the onboarding
  /// save response; absent from the `/v2/bootstrap` summary, where these stay
  /// empty rather than null.
  final String legalNameAr;
  final String legalNameEn;
  final String tradeName;
  final String commercialRegNo;
  final String taxNo;
  final String vatNo;
  final String notes;
  final int? countryId;
  final int? cityId;

  /// `trader` | `supplier` | `hybrid` — this, not `users.type`, decides the shell.
  final String businessMode;

  final String supplierNature;

  /// `draft` | `pending_review` | `active` | `suspended` | `blacklisted`
  final String status;

  final bool isOwner;
  final int? defaultBranchId;

  /// Which profiles passed review. A shell may render before this is filled.
  final List<String> approvedWorkspaces;

  final Journey journey;
  final List<OrgRole> roles;
  final List<String> permissions;
  final List<Branch> branches;
  final OrgStats stats;

  const Organization({
    required this.id,
    required this.displayName,
    this.legalNameAr = '',
    this.legalNameEn = '',
    this.tradeName = '',
    this.commercialRegNo = '',
    this.taxNo = '',
    this.vatNo = '',
    this.notes = '',
    this.countryId,
    this.cityId,
    required this.businessMode,
    required this.supplierNature,
    required this.status,
    required this.isOwner,
    required this.defaultBranchId,
    required this.approvedWorkspaces,
    required this.journey,
    required this.roles,
    required this.permissions,
    required this.branches,
    required this.stats,
  });

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
        id: asInt(j['id']),
        displayName: unwrap(j['display_name']),
        legalNameAr: unwrap(j['legal_name_ar']),
        legalNameEn: unwrap(j['legal_name_en']),
        tradeName: unwrap(j['trade_name']),
        // All-digit registration numbers arrive as numbers.
        commercialRegNo: asStr(j['commercial_reg_no']),
        taxNo: asStr(j['tax_no']),
        vatNo: asStr(j['vat_no']),
        notes: unwrap(j['notes']),
        // `country`/`city` are sometimes ids, sometimes nested rows.
        countryId: _refId(j['country_id'] ?? j['country']),
        cityId: _refId(j['city_id'] ?? j['city']),
        businessMode: asStr(j['business_mode']),
        supplierNature: asStr(j['supplier_nature']),
        status: asStr(j['status']),
        isOwner: asBool(j['is_owner']),
        defaultBranchId: asIntOrNull(j['default_branch_id']),
        approvedWorkspaces: asStrList(j['approved_workspaces']),
        journey: j['journey'] is Map ? Journey.fromJson(asMap(j['journey'])) : Journey.empty,
        roles: asList(j['roles'], OrgRole.fromJson),
        permissions: asStrList(j['permissions']),
        branches: asList(j['branches'], Branch.fromJson),
        stats: OrgStats.fromJson(asMap(j['stats'])),
      );

  /// The legal-identity step is complete when the four required fields of
  /// `PUT /v2/onboarding/organization` are filled.
  bool get hasLegalIdentity =>
      legalNameAr.isNotEmpty && tradeName.isNotEmpty && countryId != null && cityId != null;

  bool get isHybrid => businessMode == BusinessMode.hybrid;
  bool get isActive => status == 'active';

  /// Still in setup or review — route into onboarding rather than the shell.
  bool get needsOnboarding => status == 'draft' || status == 'pending_review';

  /// Which workspaces this org's shell may offer at all.
  List<Workspace> get workspaces {
    switch (businessMode) {
      case BusinessMode.hybrid:
        return const [Workspace.trader, Workspace.supplier];
      case BusinessMode.supplier:
        return const [Workspace.supplier];
      default:
        return const [Workspace.trader];
    }
  }

  /// `trader` → trader, `supplier` → supplier, `hybrid` → remembered choice,
  /// defaulting to trader. Never the server's own hybrid default (supplier).
  Workspace initialWorkspace(Workspace? remembered) {
    switch (businessMode) {
      case BusinessMode.trader:
        return Workspace.trader;
      case BusinessMode.supplier:
        return Workspace.supplier;
      case BusinessMode.hybrid:
        return remembered ?? Workspace.trader;
      default:
        return Workspace.trader;
    }
  }
}

/// A reference that may be a bare id or a `{id, name}` row.
int? _refId(dynamic raw) => raw is Map ? asIntOrNull(raw['id']) : asIntOrNull(raw);

class OrgRole {
  final String code;
  final String name;

  const OrgRole({required this.code, required this.name});

  factory OrgRole.fromJson(Map<String, dynamic> j) =>
      OrgRole(code: asStr(j['code']), name: unwrap(j['name']));
}

class OrgStats {
  final int productsCount;
  final int skusCount;
  final int relationshipsCount;
  final int openDraftsCount;
  final int openOrdersCount;
  final int bankAccountsCount;

  const OrgStats({
    required this.productsCount,
    required this.skusCount,
    required this.relationshipsCount,
    required this.openDraftsCount,
    required this.openOrdersCount,
    required this.bankAccountsCount,
  });

  factory OrgStats.fromJson(Map<String, dynamic> j) => OrgStats(
        productsCount: asInt(j['products_count']),
        skusCount: asInt(j['skus_count']),
        relationshipsCount: asInt(j['relationships_count']),
        openDraftsCount: asInt(j['open_drafts_count']),
        openOrdersCount: asInt(j['open_orders_count']),
        bankAccountsCount: asInt(j['bank_accounts_count']),
      );
}
