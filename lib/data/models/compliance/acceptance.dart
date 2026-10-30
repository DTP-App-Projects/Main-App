import '../../../core/network/coerce.dart';

/// Every `document_type` the level-2 one-time code accepts
/// (`AcceptanceService::DOCUMENT_TYPES`).
class AcceptanceDocument {
  AcceptanceDocument._();

  static const platformTerms = 'platform_terms';
  static const joiningAgreement = 'joining_agreement';
  static const relationshipRequest = 'relationship_request';
  static const frameworkAgreement = 'framework_agreement';
  static const addendum = 'addendum';
  static const quotation = 'quotation';
  static const purchaseOrder = 'purchase_order';
  static const creditAcknowledgment = 'credit_acknowledgment';
  static const goodsReceipt = 'goods_receipt';
  static const returnNote = 'return_note';
  static const creditLimit = 'credit_limit';
  static const promissoryNote = 'promissory_note';
  static const noticeFirst = 'notice_first';
  static const noticeSecond = 'notice_second';
  static const marketerAssignment = 'marketer_assignment';
}

/// `POST /acceptance_challenges` → a code is on its way.
class AcceptanceChallenge {
  final int id;

  /// `sms`, `email`, or both — shown so the user knows where to look.
  final String channel;

  /// Already masked by the server (`05•••••12`, `a•••@x.com`).
  final String destination;

  /// UTC.
  final DateTime? expiresAt;

  const AcceptanceChallenge({
    required this.id,
    required this.channel,
    required this.destination,
    this.expiresAt,
  });

  factory AcceptanceChallenge.fromJson(Map<String, dynamic> j) {
    // Tolerates a `{challenge: {...}}` envelope as well as the flat body.
    final m = j['challenge'] is Map ? asMap(j['challenge']) : j;
    return AcceptanceChallenge(
      id: asInt(m['challenge_id'] ?? m['id']),
      channel: asStr(m['channel']),
      destination: asStr(m['destination']),
      expiresAt: asUtcDate(m['expires_at']),
    );
  }
}
