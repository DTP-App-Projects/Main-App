import '../../../core/network/coerce.dart';
import 'chain.dart';

/// The additive fields the compliance release put on existing payloads
/// (`ChainPayloads`). Each existing model carries one of these, parsed from
/// the same JSON, so the older screens keep working untouched.
///
/// Verified against staging on 2026-10-05 unless a field says otherwise.

/// Invoice: the ZATCA phase-1 block, the chain references, the frozen hash.
class InvoiceCompliance {
  /// «فاتورة ضريبية».
  final String documentTitle;

  /// `goods`, …
  final String invoiceKind;
  final String supplyModel;
  final InvoiceParty? seller;
  final InvoiceParty? buyer;
  final double? vatRate;

  /// Base64 of the ZATCA TLV — rendered as the QR as-is.
  final String zatcaQr;
  final String poNo;
  final String faNo;
  final List<String> grnNos;

  /// UTC.
  final DateTime? issuedAt;
  final String documentHash;
  final String legalFooter;
  final String pdfUrl;

  const InvoiceCompliance({
    this.documentTitle = '',
    this.invoiceKind = '',
    this.supplyModel = '',
    this.seller,
    this.buyer,
    this.vatRate,
    this.zatcaQr = '',
    this.poNo = '',
    this.faNo = '',
    this.grnNos = const [],
    this.issuedAt,
    this.documentHash = '',
    this.legalFooter = '',
    this.pdfUrl = '',
  });

  static const empty = InvoiceCompliance();

  bool get hasZatca => zatcaQr.isNotEmpty;

  factory InvoiceCompliance.fromJson(Map<String, dynamic> j) {
    final refs = asMap(j['refs']);
    return InvoiceCompliance(
      documentTitle: unwrap(j['document_title']),
      invoiceKind: asStr(j['invoice_kind']),
      supplyModel: asStr(j['supply_model']),
      seller: InvoiceParty.maybe(j['seller']),
      buyer: InvoiceParty.maybe(j['buyer']),
      vatRate: j['vat_rate'] == null ? null : asNum(j['vat_rate']),
      zatcaQr: asStr(j['zatca_qr']),
      poNo: asStr(refs['po_no']),
      faNo: asStr(refs['fa_no']),
      grnNos: asStrList(refs['grn_nos']),
      // `issued_at_utc` is offset-less **UTC** — unlike other bare times.
      issuedAt: asUtcNaive(j['issued_at_utc']),
      documentHash: asStr(j['document_hash']),
      legalFooter: unwrap(j['legal_footer']),
      pdfUrl: asStr(j['pdf_url']),
    );
  }
}

class InvoiceParty {
  final int organizationId;
  final String name;

  /// Numeric on the wire; kept as text so leading zeros survive.
  final String vatNo;

  const InvoiceParty({required this.organizationId, required this.name, required this.vatNo});

  static InvoiceParty? maybe(dynamic raw) {
    final j = asMap(raw);
    if (j.isEmpty) return null;
    return InvoiceParty(
      organizationId: asInt(j['organization_id']),
      name: unwrap(j['name']),
      vatNo: asStr(j['vat_no']),
    );
  }
}

/// Goods receipt: who recorded it, how delivery was proven, and whether the
/// trader has confirmed it (recording is never the trader's acceptance).
class ReceiptCompliance {
  final String receiptNo;

  /// `photo`, `signature`, `otp`, `scan` — empty on legacy receipts.
  final String podMethod;
  final DateTime? podAt;

  /// `carrier`, `trader`, `supplier`.
  final String recordedByRole;

  /// `confirmed`, `received_unconfirmed`, … with the server's label
  /// («وصل ولم يُؤكَّد»).
  final String confirmationStatus;
  final String confirmationLabel;

  /// `otp`, `photo`, `legacy`, …
  final String buyerConfirmMethod;
  final DateTime? buyerConfirmedAt;
  final bool requiresTraderConfirmation;
  final String receiverName;
  final String carrierNote;
  final String documentHash;
  final String pdfUrl;

  /// Per line id: the split of what was not accepted.
  final Map<int, ReceiptLineCompliance> lines;

  const ReceiptCompliance({
    this.receiptNo = '',
    this.podMethod = '',
    this.podAt,
    this.recordedByRole = '',
    this.confirmationStatus = '',
    this.confirmationLabel = '',
    this.buyerConfirmMethod = '',
    this.buyerConfirmedAt,
    this.requiresTraderConfirmation = false,
    this.receiverName = '',
    this.carrierNote = '',
    this.documentHash = '',
    this.pdfUrl = '',
    this.lines = const {},
  });

  static const empty = ReceiptCompliance();

  bool get isConfirmed => confirmationStatus == 'confirmed';

  factory ReceiptCompliance.fromJson(Map<String, dynamic> j) => ReceiptCompliance(
        receiptNo: asStr(j['receipt_no']),
        podMethod: asStr(j['pod_method']),
        podAt: asUtcDate(j['pod_at']),
        recordedByRole: asStr(j['recorded_by_role']),
        confirmationStatus: asStr(j['confirmation_status']),
        confirmationLabel: unwrap(j['confirmation_label']),
        buyerConfirmMethod: asStr(j['buyer_confirm_method']),
        buyerConfirmedAt: asUtcDate(j['buyer_confirmed_at']),
        requiresTraderConfirmation: asBool(j['requires_trader_confirmation']),
        receiverName: unwrap(j['receiver_name']),
        carrierNote: unwrap(j['carrier_note']),
        documentHash: asStr(j['document_hash']),
        pdfUrl: asStr(j['pdf_url']),
        lines: {
          for (final line in asList(j['lines'], (m) => m))
            asInt(line['id']): ReceiptLineCompliance.fromJson(line),
        },
      );
}

class ReceiptLineCompliance {
  final double expectedQty;
  final double shortageQty;
  final double defectQty;
  final String defectNote;

  const ReceiptLineCompliance({
    this.expectedQty = 0,
    this.shortageQty = 0,
    this.defectQty = 0,
    this.defectNote = '',
  });

  bool get hasIssue => shortageQty > 0 || defectQty > 0 || defectNote.isNotEmpty;

  factory ReceiptLineCompliance.fromJson(Map<String, dynamic> j) => ReceiptLineCompliance(
        expectedQty: asNum(j['expected_qty']),
        shortageQty: asNum(j['shortage_qty']),
        defectQty: asNum(j['defect_qty']),
        defectNote: unwrap(j['defect_note']),
      );
}

/// Purchase order: the chain FA → quotation → PO → ACK, the supply model,
/// and which transitions need a one-time code.
class PurchaseOrderCompliance {
  /// `direct`, `credit`, `consignment`.
  final String supplyModel;
  final String supplyModelLabel;

  /// The spec's status vocabulary, next to the legacy `status`.
  final String specStatus;
  final String specStatusLabel;

  /// Transitions (`accepted`, …) that open the OTP sheet.
  final List<String> otpRequiredFor;
  final String otpDocumentType;
  final DateTime? acceptedAt;
  final int? frozenDocumentId;
  final ChainRef? frameworkAgreement;
  final ChainRef? quotation;
  final ChainRef? creditAcknowledgment;

  /// Set by the late-payment sweep: the order is held, never cancelled.
  /// The handbook lists it, but staging's PO payload did not carry the key
  /// on 2026-10-05 — `null` means "not held" either way.
  final DateTime? supplyHoldAt;

  const PurchaseOrderCompliance({
    this.supplyModel = '',
    this.supplyModelLabel = '',
    this.specStatus = '',
    this.specStatusLabel = '',
    this.otpRequiredFor = const [],
    this.otpDocumentType = 'purchase_order',
    this.acceptedAt,
    this.frozenDocumentId,
    this.frameworkAgreement,
    this.quotation,
    this.creditAcknowledgment,
    this.supplyHoldAt,
  });

  static const empty = PurchaseOrderCompliance();

  bool get isHeld => supplyHoldAt != null;

  /// The supplier's acceptance is named `approved` by the legacy status
  /// machine and `accepted` by the spec vocabulary `otp_required_for` uses —
  /// the same binding act (guide Part 9.2). Matching only the exact name let
  /// an `approved` go out without its code.
  static const _acceptance = {'approved', 'accepted'};

  bool needsOtp(String transition) {
    if (otpRequiredFor.contains(transition)) return true;
    return _acceptance.contains(transition) && otpRequiredFor.any(_acceptance.contains);
  }

  /// A refusal that means "this needs a verification code" — the safety net
  /// when `otp_required_for` did not say so up front. A wrong or expired code
  /// is a different answer, shown as is.
  static bool isCodeRequired(String failureCode) {
    final code = failureCode.toLowerCase();
    if (!code.contains('otp')) return false;
    return !code.contains('invalid') && !code.contains('expired') && !code.contains('attempt');
  }

  factory PurchaseOrderCompliance.fromJson(Map<String, dynamic> j) => PurchaseOrderCompliance(
        supplyModel: asStr(j['supply_model']),
        supplyModelLabel: unwrap(j['supply_model_label']),
        specStatus: asStr(j['spec_status']),
        specStatusLabel: unwrap(j['spec_status_label']),
        otpRequiredFor: asStrList(j['otp_required_for']),
        otpDocumentType: asStr(j['otp_document_type']).isEmpty
            ? 'purchase_order'
            : asStr(j['otp_document_type']),
        acceptedAt: asUtcDate(j['accepted_at']),
        frozenDocumentId: asIntOrNull(j['frozen_document_id']),
        frameworkAgreement: ChainRef.maybe(j['framework_agreement']),
        quotation: ChainRef.maybe(j['quotation']),
        creditAcknowledgment: ChainRef.maybe(j['credit_acknowledgment']),
        supplyHoldAt: asUtcDate(j['supply_hold_at']),
      );
}
