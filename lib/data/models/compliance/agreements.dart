import '../../../core/network/coerce.dart';
import 'chain.dart';

/// Framework agreements (`FA-`), addenda and credit acknowledgments (`ACK`):
/// documents both parties' authorized signatories accept with a one-time
/// code.
///
/// UNVERIFIED ROW SHAPE. Staging could not produce one on 2026-10-05: every
/// one of them is created by an OTP-accepted step (relationship request →
/// FA, quotation/PO → ACK), and `POST /acceptance_challenges` answered
/// `422 otp_send_failed` throughout. The keys below follow the conventions
/// every verified document of this release shares (`status_label`,
/// `my_role`, `can_*`, `otp_document_type`, `body_text`, `document_hash`,
/// `frozen_document_id`). Re-check against a live row before release.
class SignableDocument {
  final int id;

  /// `FA-2026-…`, `ADD-…`, `ACK-…`.
  final String number;
  final String status;
  final String statusLabel;
  final String myRole;
  final bool canSign;
  final String otpDocumentType;
  final ChainParty? supplier;
  final ChainParty? trader;
  final int relationshipId;
  final String bodyText;
  final String documentHash;
  final int? frozenDocumentId;

  /// Who has signed and who is still pending, per party.
  final List<DocumentSignature> signatures;

  /// ACK / addendum: the amount or limit it records, when it has one.
  final double? amount;
  final DateTime? createdAt;
  final DateTime? signedAt;

  const SignableDocument({
    required this.id,
    this.number = '',
    this.status = '',
    this.statusLabel = '',
    this.myRole = '',
    this.canSign = false,
    this.otpDocumentType = '',
    this.supplier,
    this.trader,
    this.relationshipId = 0,
    this.bodyText = '',
    this.documentHash = '',
    this.frozenDocumentId,
    this.signatures = const [],
    this.amount,
    this.createdAt,
    this.signedAt,
  });

  ChainParty? get counterparty => myRole == 'supplier' ? trader : supplier;

  factory SignableDocument.fromJson(Map<String, dynamic> j) => SignableDocument(
        id: asInt(j['id']),
        number: asStr(j['agreement_no'] ?? j['addendum_no'] ?? j['ack_no'] ?? j['document_no'] ?? j['number']),
        status: asStr(j['status']),
        statusLabel: unwrap(j['status_label']),
        myRole: asStr(j['my_role']),
        canSign: asBool(j['can_sign'] ?? j['can_accept']),
        otpDocumentType: asStr(j['otp_document_type']),
        supplier: ChainParty.maybe(j['supplier']),
        trader: ChainParty.maybe(j['trader']),
        relationshipId: asInt(j['business_relationship_id'] ?? j['relationship_id']),
        bodyText: unwrap(j['body_text']),
        documentHash: asStr(j['document_hash']),
        frozenDocumentId: asIntOrNull(j['frozen_document_id']),
        signatures: asList(j['signatures'] ?? j['signers'], DocumentSignature.fromJson),
        amount: j['amount'] == null && j['credit_limit'] == null ? null : asNum(j['amount'] ?? j['credit_limit']),
        createdAt: asUtcDate(j['created_at']),
        signedAt: asUtcDate(j['signed_at'] ?? j['accepted_at']),
      );
}

/// One party's signature slot. UNVERIFIED (see [SignableDocument]).
class DocumentSignature {
  /// `supplier` or `trader`.
  final String side;
  final String signerName;
  final bool signed;
  final DateTime? signedAt;

  /// `otp`, `click`, … — never labelled «توقيع إلكتروني معتمد».
  final String method;

  const DocumentSignature({
    required this.side,
    this.signerName = '',
    this.signed = false,
    this.signedAt,
    this.method = '',
  });

  factory DocumentSignature.fromJson(Map<String, dynamic> j) => DocumentSignature(
        side: asStr(j['side'] ?? j['signer_role'] ?? j['party']),
        signerName: unwrap(j['signer_name'] ?? j['name']),
        signed: asBool(j['signed']) || j['signed_at'] != null,
        signedAt: asUtcDate(j['signed_at']),
        method: asStr(j['method'] ?? j['signature_method']),
      );
}
