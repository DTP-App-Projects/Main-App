import '../../../core/network/coerce.dart';

/// «إشعار سداد» — the trader's "I paid", as the website sends it. The
/// supplier confirms it (which creates and confirms the collection receipt
/// and moves the invoice balance) or rejects it with a note.
class PaymentNotice {
  final int id;
  final String noticeNo;
  final int? invoiceId;
  final String invoiceNo;
  final int? dueScheduleId;
  final int? supplierBankAccountId;
  final String paymentMethod;
  final double amount;
  final String currencyCode;
  final DateTime? paidAt;
  final String referenceNo;
  final String note;

  /// `submitted` (waiting for the supplier), `confirmed` or `rejected`.
  final String status;

  /// Which side is looking — `trader` or `supplier`.
  final String viewerSide;

  /// The server's answer to "may this viewer confirm or reject it now".
  /// The buttons are built from this, never from the status alone.
  final bool canReview;

  final String proofUrl;
  final String reviewNote;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  /// Set once confirmed: the receipt the confirmation created.
  final int? collectionReceiptId;

  const PaymentNotice({
    required this.id,
    required this.noticeNo,
    required this.invoiceId,
    required this.invoiceNo,
    required this.dueScheduleId,
    required this.supplierBankAccountId,
    required this.paymentMethod,
    required this.amount,
    required this.currencyCode,
    required this.paidAt,
    required this.referenceNo,
    required this.note,
    required this.status,
    required this.viewerSide,
    required this.canReview,
    required this.proofUrl,
    required this.reviewNote,
    required this.reviewedAt,
    required this.createdAt,
    required this.collectionReceiptId,
  });

  factory PaymentNotice.fromJson(Map<String, dynamic> j) {
    final invoice = j['invoice'] is Map ? asMap(j['invoice']) : const <String, dynamic>{};
    return PaymentNotice(
      id: asInt(j['id']),
      noticeNo: asStr(j['notice_no'] ?? j['code'] ?? j['number']),
      invoiceId: asIntOrNull(j['invoice_id'] ?? invoice['id']),
      invoiceNo: asStr(j['invoice_no'] ?? invoice['invoice_no']),
      dueScheduleId: asIntOrNull(j['due_schedule_id']),
      supplierBankAccountId: asIntOrNull(j['supplier_bank_account_id']),
      paymentMethod: asStr(j['payment_method']),
      amount: asNum(j['amount']),
      currencyCode: asStr(j['currency_code'] ?? invoice['currency_code']),
      paidAt: asDate(j['paid_at']),
      referenceNo: asStr(j['reference_no']),
      note: unwrap(j['note']),
      status: asStr(j['status']),
      viewerSide: asStr(j['viewer_side']),
      canReview: asBool(j['can_review']),
      proofUrl: asStr(j['proof_url']),
      reviewNote: unwrap(j['review_note']),
      reviewedAt: asDate(j['reviewed_at']),
      createdAt: asDate(j['created_at']),
      collectionReceiptId: asIntOrNull(j['collection_receipt_id']),
    );
  }

  bool get isPending => status == 'submitted' || status == 'pending';

  /// The number to show: the notice's own, else its id.
  String get label => noticeNo.isNotEmpty ? noticeNo : '#$id';
}
