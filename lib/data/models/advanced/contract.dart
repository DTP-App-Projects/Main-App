import '../../../core/network/coerce.dart';
import '../trade/supplier_summary.dart';

/// A trading contract. An **active** one is half of what
/// `order_entry_ready` checks — without it a trader cannot order at all.
class Contract {
  final int id;
  final int? businessRelationshipId;

  /// The server-side enum is not readable from the validators, so the value
  /// is carried through as text rather than mapped to a client-side list.
  final String contractType;

  final String code;
  final String nameAr;
  final String nameEn;
  final String displayName;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool autoRenew;
  final String status;
  final DateTime? approvedAt;
  final BusinessRelationship? relationship;

  final List<ContractTerm> terms;
  final List<ContractApproval> approvals;

  const Contract({
    required this.id,
    required this.businessRelationshipId,
    required this.contractType,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.displayName,
    required this.startDate,
    required this.endDate,
    required this.autoRenew,
    required this.status,
    required this.approvedAt,
    required this.relationship,
    required this.terms,
    required this.approvals,
  });

  factory Contract.fromJson(Map<String, dynamic> j) => Contract(
        id: asInt(j['id']),
        businessRelationshipId: asIntOrNull(j['business_relationship_id']),
        contractType: asStr(j['contract_type']),
        code: asStr(j['code']),
        nameAr: unwrap(j['name_ar']),
        nameEn: unwrap(j['name_en']),
        displayName: unwrap(j['display_name']),
        startDate: asDate(j['start_date']),
        endDate: asDate(j['end_date']),
        autoRenew: asBool(j['auto_renew']),
        status: asStr(j['status']),
        approvedAt: asDate(j['approved_at']),
        relationship: j['relationship'] is Map
            ? BusinessRelationship.fromJson(asMap(j['relationship']))
            : null,
        terms: asList(j['terms'], ContractTerm.fromJson),
        approvals: asList(j['approvals'], ContractApproval.fromJson),
      );

  static const statuses = [
    'draft',
    'under_review',
    'approved',
    'active',
    'suspended',
    'expired',
    'terminated',
  ];

  static const billingPeriods = ['weekly', 'monthly'];

  String label(String locale) {
    if (displayName.isNotEmpty) return displayName;
    final name = pickLocalized(locale: locale, ar: nameAr, en: nameEn);
    return name.isNotEmpty ? name : code;
  }

  bool get isActive => status == 'active';

  /// Approvals still waiting on someone.
  List<ContractApproval> get pendingApprovals =>
      approvals.where((approval) => approval.isPending).toList();
}

class ContractTerm {
  final int id;
  final String key;
  final String label;
  final String value;

  const ContractTerm({
    required this.id,
    required this.key,
    required this.label,
    required this.value,
  });

  factory ContractTerm.fromJson(Map<String, dynamic> j) => ContractTerm(
        id: asInt(j['id']),
        key: asStr(j['key'] ?? j['term_key']),
        label: unwrap(j['label'] ?? j['name']),
        // A term value can be a number, a date or free text.
        value: unwrap(j['value'] ?? j['term_value']),
      );
}

class ContractApproval {
  final int id;
  final String status;
  final String note;
  final String approverName;
  final DateTime? decidedAt;

  const ContractApproval({
    required this.id,
    required this.status,
    required this.note,
    required this.approverName,
    required this.decidedAt,
  });

  factory ContractApproval.fromJson(Map<String, dynamic> j) => ContractApproval(
        id: asInt(j['id']),
        status: asStr(j['status']),
        note: unwrap(j['note']),
        approverName: unwrap(j['approver_name'] ?? j['user_name']),
        decidedAt: asDate(j['decided_at'] ?? j['updated_at']),
      );

  bool get isPending => status.isEmpty || status == 'pending';

  static const decisions = ['approved', 'rejected', 'pending'];
}

/// A rating one side gives the other.
///
/// The `dimension` enum lives server-side and is not readable from the
/// validators, so the values are discovered from the aggregate rather than
/// hardcoded here.
class Rating {
  final int id;
  final int? businessRelationshipId;
  final String dimension;
  final int score;
  final String note;
  final String source;
  final DateTime? createdAt;

  const Rating({
    required this.id,
    required this.businessRelationshipId,
    required this.dimension,
    required this.score,
    required this.note,
    required this.source,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> j) => Rating(
        id: asInt(j['id']),
        businessRelationshipId: asIntOrNull(j['business_relationship_id']),
        dimension: asStr(j['dimension']),
        score: asInt(j['score']),
        note: unwrap(j['note']),
        source: asStr(j['source']),
        createdAt: asDate(j['created_at']),
      );
}

/// `GET /v2/ratings/aggregate` — the averages, and the only published source
/// of the dimension vocabulary.
class RatingAggregate {
  final int? ratedOrganizationId;
  final int? businessRelationshipId;
  final double average;
  final int count;

  /// dimension → average.
  final Map<String, double> byDimension;

  const RatingAggregate({
    required this.ratedOrganizationId,
    required this.businessRelationshipId,
    required this.average,
    required this.count,
    required this.byDimension,
  });

  factory RatingAggregate.fromJson(Map<String, dynamic> j) {
    final aggregate = asMap(j['aggregate']);
    final dimensions = <String, double>{};

    // The shape is not published; both a keyed map and a list of rows are
    // accepted rather than guessing at one.
    final raw = aggregate['dimensions'] ?? aggregate['by_dimension'];
    if (raw is Map) {
      raw.forEach((key, value) {
        dimensions['$key'] = value is Map ? asNum(value['average']) : asNum(value);
      });
    } else if (raw is List) {
      for (final row in raw.whereType<Map>()) {
        final map = row.cast<String, dynamic>();
        dimensions[asStr(map['dimension'])] = asNum(map['average'] ?? map['score']);
      }
    }

    return RatingAggregate(
      ratedOrganizationId: asIntOrNull(j['rated_organization_id']),
      businessRelationshipId: asIntOrNull(j['business_relationship_id']),
      average: asNum(aggregate['average'] ?? aggregate['score']),
      count: asInt(aggregate['count'] ?? aggregate['total']),
      byDimension: dimensions,
    );
  }

  /// The dimensions this organization has actually been rated on — used to
  /// populate the picker instead of a hardcoded list.
  List<String> get knownDimensions => byDimension.keys.toList()..sort();
}
