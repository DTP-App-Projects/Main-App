import '../../../core/network/coerce.dart';
import 'chain.dart';

/// `relationship_requests` — the request to open a relationship with a
/// supply model, term and limit (template أ). Verified on staging 2026-10-05.
class RelationshipRequest {
  final int id;
  final int relationshipId;
  final String requestNo;

  /// `submitted`, `accepted`, `rejected`, …
  final String status;
  final String statusLabel;
  final String relationshipStatus;

  /// `active`, `supply_suspended`, `accelerated`.
  final String supplyStatus;

  /// `supplier` or `trader` — the viewer's side.
  final String myRole;
  final bool isRequester;
  final bool canDecide;
  final bool canSubmit;
  final bool submitRequiresOtp;
  final String otpDocumentType;

  /// `direct`, `credit`, `consignment`.
  final String requestedModel;
  final String requestedModelLabel;
  final int? requestedCreditTermDays;
  final double? requestedCreditLimit;
  final String debtDocumentation;
  final String debtDocumentationLabel;

  /// What the supplier granted (may be lower than requested).
  final double creditLimit;
  final int creditTermDays;

  final ChainParty? counterparty;
  final ChainRef? frameworkAgreement;
  final double? availableCredit;

  /// The frozen text of the request, as the parties accept it.
  final String bodyText;
  final String documentHash;
  final int? frozenDocumentId;

  /// UTC.
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String decisionNote;

  const RelationshipRequest({
    required this.id,
    this.relationshipId = 0,
    this.requestNo = '',
    this.status = '',
    this.statusLabel = '',
    this.relationshipStatus = '',
    this.supplyStatus = '',
    this.myRole = '',
    this.isRequester = false,
    this.canDecide = false,
    this.canSubmit = false,
    this.submitRequiresOtp = false,
    this.otpDocumentType = 'relationship_request',
    this.requestedModel = '',
    this.requestedModelLabel = '',
    this.requestedCreditTermDays,
    this.requestedCreditLimit,
    this.debtDocumentation = '',
    this.debtDocumentationLabel = '',
    this.creditLimit = 0,
    this.creditTermDays = 0,
    this.counterparty,
    this.frameworkAgreement,
    this.availableCredit,
    this.bodyText = '',
    this.documentHash = '',
    this.frozenDocumentId,
    this.submittedAt,
    this.decidedAt,
    this.decisionNote = '',
  });

  bool get isCredit => requestedModel == 'credit';

  factory RelationshipRequest.fromJson(Map<String, dynamic> j) => RelationshipRequest(
        id: asInt(j['id']),
        relationshipId: asInt(j['relationship_id']),
        requestNo: asStr(j['request_no']),
        status: asStr(j['request_status']),
        statusLabel: unwrap(j['request_status_label']),
        relationshipStatus: asStr(j['relationship_status']),
        supplyStatus: asStr(j['supply_status']),
        myRole: asStr(j['my_role']),
        isRequester: asBool(j['is_requester']),
        canDecide: asBool(j['can_decide']),
        canSubmit: asBool(j['can_submit']),
        submitRequiresOtp: asBool(j['submit_requires_otp']),
        otpDocumentType: asStr(j['otp_document_type']).isEmpty
            ? 'relationship_request'
            : asStr(j['otp_document_type']),
        requestedModel: asStr(j['requested_model']),
        requestedModelLabel: unwrap(j['requested_model_label']),
        requestedCreditTermDays: asIntOrNull(j['requested_credit_term_days']),
        requestedCreditLimit: j['requested_credit_limit'] == null ? null : asNum(j['requested_credit_limit']),
        debtDocumentation: asStr(j['debt_documentation']),
        debtDocumentationLabel: unwrap(j['debt_documentation_label']),
        creditLimit: asNum(j['credit_limit']),
        creditTermDays: asInt(j['credit_term_days']),
        counterparty: ChainParty.maybe(j['counterparty']),
        frameworkAgreement: ChainRef.maybe(j['framework_agreement']),
        availableCredit: j['available_credit'] == null ? null : asNum(j['available_credit']),
        bodyText: unwrap(j['body_text']),
        documentHash: asStr(j['document_hash']),
        frozenDocumentId: asIntOrNull(j['frozen_document_id']),
        submittedAt: asUtcDate(j['submitted_at']),
        decidedAt: asUtcDate(j['decided_at']),
        decisionNote: unwrap(j['decision_note'] ?? j['request_decision_note'] ?? j['note']),
      );
}

/// What the request form collected, for the caller's cubit to send.
class RelationshipRequestDraft {
  /// `direct` (cash), `credit` or `consignment`.
  final String model;
  final int? creditTermDays;
  final double? creditLimit;

  /// `acknowledgment_only`, `promissory_note` or `both`.
  final String? debtDocumentation;
  final String notes;

  const RelationshipRequestDraft({
    required this.model,
    this.creditTermDays,
    this.creditLimit,
    this.debtDocumentation,
    this.notes = '',
  });
}
