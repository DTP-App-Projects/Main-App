import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../../core/workspace/workspace.dart';
import '../api_paths.dart';
import '../models/trade/invoice.dart';
import '../models/trade/payment_notice.dart';
import '../models/trade/pricing.dart';

/// The money end of the trader flow: what is owed, claiming a payment, and
/// returning goods after the invoice.
class ReceivablesRepository {
  final ApiClient _client;

  ReceivablesRepository(this._client);

  // ---------------------------------------------------------------- invoices

  Future<ApiResult<Paged<Invoice>>> invoices({
    required Workspace role,
    int page = 1,
    List<String> statuses = const [],
    int? purchaseOrderId,
    int limit = 15,
  }) =>
      _client.get<Paged<Invoice>>(
        ApiPaths.invoices,
        query: {
          ...PageParams.limit(page, size: limit),
          'role': role.api,
          if (statuses.isNotEmpty) 'status': statuses.join(','),
          'purchase_order_id': ?purchaseOrderId,
        },
        parse: (body) => Paged.fromJson(asMap(body), Invoice.fromJson),
      );

  Future<ApiResult<Invoice>> invoice(int id) => _client.get<Invoice>(
        ApiPaths.invoice(id),
        parse: (body) => Invoice.fromJson(asMap(asMap(body)['invoice'])),
      );

  /// Supplier-only. Omit [lines] to invoice the whole delivery note.
  ///
  /// Quota-gated (`max_invoices_per_month`) and **not auto-retried** — a
  /// duplicate invoice is a document that then has to be cancelled.
  Future<ApiResult<Invoice>> issueInvoice({
    required int purchaseOrderId,
    int? deliveryNoteId,
    DateTime? invoiceDate,
    String? currencyCode,
    List<InvoiceLineInput>? lines,
  }) =>
      _client.post<Invoice>(
        ApiPaths.invoices,
        body: {
          'purchase_order_id': purchaseOrderId,
          'delivery_note_id': ?deliveryNoteId,
          if (invoiceDate != null) 'invoice_date': _day(invoiceDate),
          'currency_code': ?currencyCode,
          if (lines != null) 'lines': lines.map((l) => l.toJson()).toList(),
        },
        parse: (body) => Invoice.fromJson(asMap(asMap(body)['invoice'])),
      );

  /// A proforma needs no delivery note — it is priced from the order alone.
  Future<ApiResult<Invoice>> issueProforma({
    required int purchaseOrderId,
    DateTime? invoiceDate,
    String? currencyCode,
  }) =>
      _client.post<Invoice>(
        ApiPaths.invoicesProforma,
        body: {
          'purchase_order_id': purchaseOrderId,
          if (invoiceDate != null) 'invoice_date': _day(invoiceDate),
          'currency_code': ?currencyCode,
        },
        parse: (body) => Invoice.fromJson(asMap(asMap(body)['invoice'])),
      );

  /// Supplier-only, `due_schedules.edit`. `due_amount` must be at least 0.01.
  Future<ApiResult<DueSchedule>> updateDueSchedule({
    required int id,
    DateTime? dueDate,
    double? dueAmount,
  }) =>
      _client.patch<DueSchedule>(
        ApiPaths.dueSchedule(id),
        body: {
          if (dueDate != null) 'due_date': _day(dueDate),
          'due_amount': ?dueAmount,
        },
        parse: (body) => DueSchedule.fromJson(asMap(asMap(body)['due_schedule'])),
      );

  // ------------------------------------------------------------- collections

  Future<ApiResult<Paged<CollectionReceipt>>> collections({
    int page = 1,
    String? status,
    int? invoiceId,
    int limit = 15,
  }) =>
      _client.get<Paged<CollectionReceipt>>(
        ApiPaths.collections,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'invoice_id': ?invoiceId,
        },
        parse: (body) => Paged.fromJson(asMap(body), CollectionReceipt.fromJson),
      );

  /// **"I paid — please confirm."** Trader-only, and one of `invoiceId` or
  /// `dueScheduleId` is required (else `400 invoice_or_due_schedule_required`).
  ///
  /// Not auto-retried: a duplicate claim is a real problem for a supplier
  /// reconciling payments.
  Future<ApiResult<CollectionReceipt>> claimPayment({
    required double amount,
    int? invoiceId,
    int? dueScheduleId,
    String? paymentMethod,
    DateTime? receivedAt,
    String? referenceNo,
    String? proofFile,
    String? note,
  }) =>
      _client.post<CollectionReceipt>(
        ApiPaths.collectionsClaim,
        body: {
          'amount': amount,
          'invoice_id': ?invoiceId,
          'due_schedule_id': ?dueScheduleId,
          'payment_method': ?paymentMethod,
          if (receivedAt != null) 'received_at': _day(receivedAt),
          'reference_no': ?referenceNo,
          'proof_file': ?proofFile,
          'note': ?note,
        },
        parse: (body) => CollectionReceipt.fromJson(asMap(asMap(body)['collection_receipt'])),
      );

  /// The methods a **trader** may claim with. The supplier side allows more.
  static const traderPaymentMethods = ['transfer', 'cash', 'cheque'];

  static const supplierPaymentMethods = [
    'transfer',
    'cash',
    'cheque',
    'gateway',
    'adjustment',
  ];

  /// Supplier-only: recording a payment received directly.
  Future<ApiResult<CollectionReceipt>> recordCollection({
    required double amount,
    int? invoiceId,
    int? dueScheduleId,
    String? paymentMethod,
    DateTime? receivedAt,
    int? bankAccountId,
    String? referenceNo,
    String? proofFile,
  }) =>
      _client.post<CollectionReceipt>(
        ApiPaths.collections,
        body: {
          'amount': amount,
          'invoice_id': ?invoiceId,
          'due_schedule_id': ?dueScheduleId,
          'payment_method': ?paymentMethod,
          if (receivedAt != null) 'received_at': _day(receivedAt),
          'bank_account_id': ?bankAccountId,
          'reference_no': ?referenceNo,
          'proof_file': ?proofFile,
        },
        parse: (body) =>
            CollectionReceipt.fromJson(asMap(asMap(body)['collection_receipt'])),
      );

  /// **This is how a trader claim gets settled.** `confirmed` or `rejected`;
  /// a full settlement fires `invoice.paid`.
  Future<ApiResult<CollectionReceipt>> decideCollection({
    required int id,
    required String status,
  }) =>
      _client.patch<CollectionReceipt>(
        ApiPaths.collectionStatus(id),
        body: {'status': status},
        parse: (body) =>
            CollectionReceipt.fromJson(asMap(asMap(body)['collection_receipt'])),
      );

  // --------------------------------------------------------- payment notices

  /// Both sides. `status` is comma-separated multi-value
  /// (`submitted,confirmed,rejected`); each row's payload is under
  /// `formatted`.
  Future<ApiResult<Paged<PaymentNotice>>> paymentNotices({
    int page = 1,
    List<String> statuses = const [],
    int? invoiceId,
    int limit = 15,
  }) =>
      _client.get<Paged<PaymentNotice>>(
        ApiPaths.paymentNotices,
        query: {
          ...PageParams.limit(page, size: limit),
          if (statuses.isNotEmpty) 'status': statuses.join(','),
          'invoice_id': ?invoiceId,
        },
        parse: (body) => Paged.fromJson(asMap(body), PaymentNotice.fromJson),
      );

  Future<ApiResult<PaymentNotice>> paymentNotice(int id) => _client.get<PaymentNotice>(
        ApiPaths.paymentNotice(id),
        parse: _noticeOf,
      );

  /// **The trader's "I paid"** — the website's flow, which replaces
  /// `collections/claim` in the app. [proofFile] is a path from
  /// `/v2/uploads`. Not auto-retried: a duplicate notice is a second payment
  /// for the supplier to reconcile.
  Future<ApiResult<PaymentNotice>> sendPaymentNotice({
    required int invoiceId,
    required String paymentMethod,
    required double amount,
    required DateTime paidAt,
    int? dueScheduleId,
    int? supplierBankAccountId,
    String? referenceNo,
    String? proofFile,
    String? note,
  }) =>
      _client.post<PaymentNotice>(
        ApiPaths.paymentNotices,
        body: {
          'invoice_id': invoiceId,
          'due_schedule_id': ?dueScheduleId,
          'supplier_bank_account_id': ?supplierBankAccountId,
          'payment_method': paymentMethod,
          'amount': amount,
          'paid_at': _day(paidAt),
          'reference_no': ?referenceNo,
          'proof_file': ?proofFile,
          'note': ?note,
        },
        parse: _noticeOf,
      );

  /// Supplier: `confirmed` or `rejected`. A rejection needs [reviewNote]
  /// (3–1000 characters). Confirming creates and confirms the collection
  /// receipt, and the invoice balance moves.
  Future<ApiResult<PaymentNotice>> reviewPaymentNotice({
    required int id,
    required String status,
    String? reviewNote,
  }) =>
      _client.patch<PaymentNotice>(
        ApiPaths.paymentNoticeStatus(id),
        body: {'status': status, 'review_note': ?reviewNote},
        parse: _noticeOf,
      );

  /// The methods a payment notice accepts.
  static const noticePaymentMethods = ['transfer', 'cash', 'cheque', 'gateway', 'adjustment'];

  /// `{payment_notice: {...}}`, possibly with the payload under `formatted`.
  static PaymentNotice _noticeOf(dynamic body) {
    final root = asMap(body);
    var notice = asMap(root['payment_notice'] ?? root['notice'] ?? root['data']);
    if (notice['formatted'] is Map) notice = asMap(notice['formatted']);
    return PaymentNotice.fromJson(notice);
  }

  // ------------------------------------------------------------- adjustments

  Future<ApiResult<Paged<AdjustmentNote>>> adjustments({
    int page = 1,
    String? status,
    int? invoiceId,
    String? noteSide,
    int limit = 15,
  }) =>
      _client.get<Paged<AdjustmentNote>>(
        ApiPaths.adjustments,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'invoice_id': ?invoiceId,
          'note_side': ?noteSide,
        },
        parse: (body) => Paged.fromJson(asMap(body), AdjustmentNote.fromJson),
      );

  /// Supplier-only. `debit` raises what is owed, `credit` reduces it.
  Future<ApiResult<AdjustmentNote>> createAdjustment({
    required int invoiceId,
    required String noteSide,
    required double amount,
    String? reasonType,
    String? noteText,
    String? status,
  }) =>
      _client.post<AdjustmentNote>(
        ApiPaths.adjustments,
        body: {
          'invoice_id': invoiceId,
          'note_side': noteSide,
          'amount': amount,
          'reason_type': ?reasonType,
          'note_text': ?noteText,
          'status': ?status,
        },
        parse: (body) => AdjustmentNote.fromJson(asMap(asMap(body)['adjustment_note'])),
      );

  Future<ApiResult<AdjustmentNote>> setAdjustmentStatus({
    required int id,
    required String status,
  }) =>
      _client.patch<AdjustmentNote>(
        ApiPaths.adjustmentStatus(id),
        body: {'status': status},
        parse: (body) => AdjustmentNote.fromJson(asMap(asMap(body)['adjustment_note'])),
      );

  /// Approving a return issues the credit note. The transitions each side may
  /// make differ, hence `403 post_invoice_return_transition_not_allowed_for_role`.
  Future<ApiResult<PostInvoiceReturn>> decideReturn({
    required int id,
    required String status,
    String? reason,
  }) =>
      _client.patch<PostInvoiceReturn>(
        ApiPaths.postInvoiceReturnStatus(id),
        body: {'status': status, 'reason': ?reason},
        parse: (body) =>
            PostInvoiceReturn.fromJson(asMap(asMap(body)['post_invoice_return'])),
      );

  // ----------------------------------------------------------------- returns

  Future<ApiResult<Paged<PostInvoiceReturn>>> returns({
    int page = 1,
    String? status,
    int? invoiceId,
    int limit = 15,
  }) =>
      _client.get<Paged<PostInvoiceReturn>>(
        ApiPaths.postInvoiceReturns,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'invoice_id': ?invoiceId,
        },
        parse: (body) => Paged.fromJson(asMap(body), PostInvoiceReturn.fromJson),
      );

  Future<ApiResult<PostInvoiceReturn>> returnDetail(int id) => _client.get<PostInvoiceReturn>(
        ApiPaths.postInvoiceReturn(id),
        parse: (body) =>
            PostInvoiceReturn.fromJson(asMap(asMap(body)['post_invoice_return'])),
      );

  /// Trader-only. At least one line is required.
  Future<ApiResult<PostInvoiceReturn>> submitReturn({
    required int invoiceId,
    required String reasonType,
    required List<ReturnLineInput> lines,
    String? reasonNotes,
    String? currencyCode,
  }) =>
      _client.post<PostInvoiceReturn>(
        ApiPaths.postInvoiceReturns,
        body: {
          'invoice_id': invoiceId,
          'reason_type': reasonType,
          'reason_notes': ?reasonNotes,
          'currency_code': ?currencyCode,
          'lines': lines.map((line) => line.toJson()).toList(),
        },
        parse: (body) =>
            PostInvoiceReturn.fromJson(asMap(asMap(body)['post_invoice_return'])),
      );

  /// The server compares dates, not timestamps.
  static String _day(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// One line of an invoice as the supplier bills it.
class InvoiceLineInput {
  final int skuId;
  final double qty;

  const InvoiceLineInput({required this.skuId, required this.qty});

  Map<String, dynamic> toJson() => {'sku_id': skuId, 'qty': qty};
}

class ReturnLineInput {
  final int? invoiceLineId;
  final int skuId;
  final double qty;
  final String? lineReason;

  const ReturnLineInput({
    required this.skuId,
    required this.qty,
    this.invoiceLineId,
    this.lineReason,
  });

  Map<String, dynamic> toJson() => {
        'invoice_line_id': ?invoiceLineId,
        'sku_id': skuId,
        'qty': qty,
        'line_reason': ?lineReason,
      };
}
