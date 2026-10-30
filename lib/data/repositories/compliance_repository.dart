import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/compliance/acceptance.dart';
import '../models/compliance/agreements.dart';
import '../models/compliance/legal.dart';
import '../models/compliance/marketer.dart';
import '../models/compliance/quotation.dart';
import '../models/compliance/relationship_request.dart';
import '../models/compliance/returns_and_evidence.dart';
import '../models/compliance/terms.dart';
import '../models/trade/supplier_summary.dart';

/// The pieces of the contract-compliance release every flow leans on: the
/// level-2 one-time code and the terms gate.
class ComplianceRepository {
  final ApiClient _client;

  ComplianceRepository(this._client);

  // ------------------------------------------------------- one-time code

  /// Sends a code by SMS and/or email. Throttled to 6/min server-side — a
  /// [RateLimited] carries the wait.
  Future<ApiResult<AcceptanceChallenge>> requestChallenge({
    required String documentType,
    required int documentId,
  }) =>
      _client.post<AcceptanceChallenge>(
        ApiPaths.acceptanceChallenges,
        body: {'document_type': documentType, 'document_id': documentId},
        parse: (body) => AcceptanceChallenge.fromJson(asMap(body)),
      );

  // --------------------------------------------------------------- terms

  Future<ApiResult<TermsStatus>> termsStatus() => _client.get<TermsStatus>(
        ApiPaths.termsStatus,
        dedupe: false,
        parse: TermsStatus.fromJson,
      );

  /// `{data: [...], acceptance_required, update_announced}` — the same flags
  /// as [termsStatus], so it parses into the same model.
  Future<ApiResult<TermsStatus>> termsVersions() => _client.get<TermsStatus>(
        ApiPaths.termsVersions,
        parse: TermsStatus.fromJson,
      );

  /// The only call that carries `body_html` and the legal footer.
  Future<ApiResult<TermsVersion>> termsVersion(int id) => _client.get<TermsVersion>(
        ApiPaths.termsVersion(id),
        parse: (body) => TermsVersion.fromJson(asMap(body)),
      );

  /// Level-1 click acceptance: «قبول الشروط — تعبير ملزم عن الإرادة».
  Future<ApiResult<void>> acceptTerms(List<int> versionIds) => _client.post<void>(
        ApiPaths.termsAcceptances,
        body: {'terms_version_ids': versionIds, 'confirm': 1},
      );

  Future<ApiResult<Paged<TermsAcceptance>>> termsAcceptances({int page = 1}) =>
      _client.get<Paged<TermsAcceptance>>(
        ApiPaths.termsAcceptances,
        query: PageParams.limit(page),
        parse: (body) => pagedFrom(body, TermsAcceptance.fromJson, keys: const ['acceptances']),
      );

  // ----------------------------------------------- A: complaints, signatories

  Future<ApiResult<ComplaintList>> complaintTickets({int page = 1}) => _client.get<ComplaintList>(
        ApiPaths.complaintTickets,
        query: PageParams.limit(page),
        dedupe: false,
        parse: (body) => ComplaintList.fromJson(asMap(body)),
      );

  Future<ApiResult<ComplaintTicket>> complaintTicket(int id) => _client.get<ComplaintTicket>(
        ApiPaths.complaintTicket(id),
        dedupe: false,
        parse: (body) => ComplaintTicket.fromJson(asMap(asMap(body)['ticket'])),
      );

  /// Multipart so a file can ride along (`attachments[]`, verified).
  Future<ApiResult<ComplaintTicket>> openComplaint({
    required String category,
    required String subject,
    required String body,
    String? attachmentPath,
  }) async =>
      _client.multipart<ComplaintTicket>(
        ApiPaths.complaintTickets,
        form: FormData.fromMap({
          'category': category,
          'subject': subject,
          'body': body,
          if (attachmentPath != null) 'attachments[]': await MultipartFile.fromFile(attachmentPath),
        }),
        parse: (b) => ComplaintTicket.fromJson(asMap(asMap(b)['ticket'])),
      );

  Future<ApiResult<ComplaintTicket>> replyToComplaint(int id, {required String body, String? attachmentPath}) async =>
      _client.multipart<ComplaintTicket>(
        ApiPaths.complaintMessages(id),
        form: FormData.fromMap({
          'body': body,
          if (attachmentPath != null) 'attachments[]': await MultipartFile.fromFile(attachmentPath),
        }),
        parse: (b) => ComplaintTicket.fromJson(asMap(asMap(b)['ticket'])),
      );

  Future<ApiResult<void>> closeComplaint(int id) =>
      _client.patch<void>(ApiPaths.complaintStatus(id), body: const {'status': 'closed'});

  Future<ApiResult<SignatoriesInfo>> signatories() => _client.get<SignatoriesInfo>(
        ApiPaths.signatories,
        dedupe: false,
        parse: (body) => SignatoriesInfo.fromJson(asMap(body)),
      );

  /// Owner only; the authorization document is required.
  Future<ApiResult<void>> addSignatory({required int membershipId, required String documentPath}) async =>
      _client.multipart<void>(
        ApiPaths.signatories,
        form: FormData.fromMap({
          'membership_id': membershipId,
          'authorization_document': await MultipartFile.fromFile(documentPath),
        }),
      );

  /// The last signatory cannot be removed — the server says so with a 422.
  Future<ApiResult<void>> removeSignatory(int membershipId) =>
      _client.delete<void>(ApiPaths.signatory(membershipId));

  // ------------------------------------- B: relationship → FA → quotation

  /// [direction] `incoming` (others asked me) or `outgoing` (I asked);
  /// [requestStatus] e.g. `submitted` — the ones awaiting a decision.
  Future<ApiResult<Paged<RelationshipRequest>>> relationshipRequests({
    int page = 1,
    String? direction,
    String? requestStatus,
  }) =>
      _client.get<Paged<RelationshipRequest>>(
        ApiPaths.relationshipRequests,
        dedupe: false,
        query: {...PageParams.limit(page), 'direction': ?direction, 'request_status': ?requestStatus},
        parse: (body) => pagedFrom(body, RelationshipRequest.fromJson, keys: const ['relationship_requests']),
      );

  Future<ApiResult<RelationshipRequest>> relationshipRequest(int id) => _client.get<RelationshipRequest>(
        ApiPaths.relationshipRequest(id),
        dedupe: false,
        parse: (body) => RelationshipRequest.fromJson(asMap(asMap(body)['relationship_request'])),
      );

  /// `accepted` needs [otpCode]; the supplier may grant a lower limit/term.
  Future<ApiResult<void>> decideRelationshipRequest(
    int id, {
    required String status,
    String? otpCode,
    double? creditLimit,
    int? creditTermDays,
    String? note,
  }) =>
      _client.patch<void>(
        ApiPaths.relationshipRequestStatus(id),
        body: {
          'status': status,
          'otp_code': ?otpCode,
          'credit_limit': ?creditLimit,
          'credit_term_days': ?creditTermDays,
          // Live: the field is `note` — `decision_note` is refused with
          // `bag.note: [reason_required]` on a rejection.
          'note': ?note,
        },
      );

  /// Lower applies now; higher creates an addendum.
  Future<ApiResult<void>> updateCreditTerms(int requestId, {double? creditLimit, int? creditTermDays}) =>
      _client.patch<void>(
        ApiPaths.relationshipRequestCreditTerms(requestId),
        body: {'credit_limit': ?creditLimit, 'credit_term_days': ?creditTermDays},
      );

  Future<ApiResult<Paged<SignableDocument>>> frameworkAgreements({int page = 1}) =>
      _signables(ApiPaths.frameworkAgreements, 'framework_agreements', page);

  Future<ApiResult<SignableDocument>> frameworkAgreement(int id) =>
      _signable(ApiPaths.frameworkAgreement(id), 'framework_agreement');

  Future<ApiResult<void>> signFrameworkAgreement(int id, String otpCode) => _client.patch<void>(
        ApiPaths.frameworkAgreementStatus(id),
        body: {'status': 'signed', 'otp_code': otpCode},
      );

  Future<ApiResult<Paged<SignableDocument>>> addenda({int page = 1}) =>
      _signables(ApiPaths.addenda, 'addenda', page);

  Future<ApiResult<SignableDocument>> addendum(int id) => _signable(ApiPaths.addendum(id), 'addendum');

  Future<ApiResult<void>> signAddendum(int id, String otpCode) => _client.patch<void>(
        ApiPaths.addendumStatus(id),
        body: {'status': 'signed', 'otp_code': otpCode},
      );

  Future<ApiResult<Paged<SignableDocument>>> creditAcknowledgments({int page = 1}) =>
      _signables(ApiPaths.creditAcknowledgments, 'credit_acknowledgments', page);

  Future<ApiResult<SignableDocument>> creditAcknowledgment(int id) =>
      _signable(ApiPaths.creditAcknowledgment(id), 'credit_acknowledgment');

  Future<ApiResult<void>> acceptCreditAcknowledgment(int id, String otpCode) => _client.patch<void>(
        ApiPaths.creditAcknowledgmentStatus(id),
        body: {'status': 'accepted', 'otp_code': otpCode},
      );

  Future<ApiResult<Paged<SignableDocument>>> _signables(String path, String key, int page) =>
      _client.get<Paged<SignableDocument>>(
        path,
        query: PageParams.limit(page),
        parse: (body) => pagedFrom(body, SignableDocument.fromJson, keys: [key]),
      );

  Future<ApiResult<SignableDocument>> _signable(String path, String key) => _client.get<SignableDocument>(
        path,
        dedupe: false,
        parse: (body) {
          final m = asMap(body);
          return SignableDocument.fromJson(m[key] is Map ? asMap(m[key]) : m);
        },
      );

  Future<ApiResult<Paged<Quotation>>> quotations({int page = 1, String? status}) => _client.get<Paged<Quotation>>(
        ApiPaths.quotations,
        query: {...PageParams.limit(page), 'status': ?status},
        parse: (body) => pagedFrom(body, Quotation.fromJson, keys: const ['quotations']),
      );

  Future<ApiResult<Quotation>> quotation(int id) => _client.get<Quotation>(
        ApiPaths.quotation(id),
        dedupe: false,
        parse: (body) => Quotation.fromJson(asMap(asMap(body)['quotation'])),
      );

  /// Supplier. Verified body: `{relationship_id, supply_model, valid_until,
  /// lines: [{sku_id, qty, unit_price}]}`.
  Future<ApiResult<Quotation>> createQuotation({
    required int relationshipId,
    required String supplyModel,
    required DateTime validUntil,
    required List<QuotationLineInput> lines,
    String? deliveryPlace,
    int? supplyDays,
    String? notes,
  }) =>
      _client.post<Quotation>(
        ApiPaths.quotations,
        body: {
          'relationship_id': relationshipId,
          'supply_model': supplyModel,
          'valid_until': _day(validUntil),
          'lines': lines.map((l) => l.toJson()).toList(),
          if (deliveryPlace != null && deliveryPlace.isNotEmpty) 'delivery_place': deliveryPlace,
          'supply_days': ?supplyDays,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        parse: (body) => Quotation.fromJson(asMap(asMap(body)['quotation'])),
      );

  /// `sent` / `cancelled` (supplier) or `accepted` + [otpCode] (trader).
  Future<ApiResult<void>> setQuotationStatus(int id, String status, {String? otpCode}) =>
      _client.patch<void>(ApiPaths.quotationStatus(id), body: {'status': status, 'otp_code': ?otpCode});

  /// Supplier acceptance of a PO now needs the code (`purchase_order`).
  Future<ApiResult<void>> setPurchaseOrderStatus(int id, String status, {String? otpCode, String? reason}) =>
      _client.patch<void>(
        ApiPaths.purchaseOrderStatus(id),
        body: {'status': status, 'otp_code': ?otpCode, 'reason': ?reason},
      );

  // --------------------------------------- C: receipt, returns, consignment

  /// Level 2: the code. Recording a receipt is never the trader's acceptance.
  Future<ApiResult<void>> confirmReceiptWithOtp(int goodsReceiptId, String otpCode) =>
      _client.post<void>(ApiPaths.goodsReceiptConfirmation(goodsReceiptId), body: {'otp_code': otpCode});

  /// The alternative: a photo of the goods plus the declaration.
  Future<ApiResult<void>> confirmReceiptWithPhoto(int goodsReceiptId, String photoPath) async =>
      _client.multipart<void>(
        ApiPaths.goodsReceiptConfirmation(goodsReceiptId),
        form: FormData.fromMap({
          'confirm_photo': await MultipartFile.fromFile(photoPath),
          'declaration_accepted': 1,
        }),
      );

  Future<ApiResult<Paged<ReturnNote>>> returnNotes({int page = 1, String? status}) => _client.get<Paged<ReturnNote>>(
        ApiPaths.returnNotes,
        query: {...PageParams.limit(page), 'status': ?status},
        parse: (body) => pagedFrom(body, ReturnNote.fromJson, keys: const ['return_notes']),
      );

  Future<ApiResult<ReturnNote>> returnNote(int id) => _client.get<ReturnNote>(
        ApiPaths.returnNote(id),
        dedupe: false,
        parse: (body) => ReturnNote.fromJson(asMap(asMap(body)['data'])),
      );

  Future<ApiResult<Returnable>> returnable(int purchaseOrderId) => _client.get<Returnable>(
        ApiPaths.returnableQuantities(purchaseOrderId),
        dedupe: false,
        parse: (body) => Returnable.fromJson(asMap(body)),
      );

  /// Verified body: `{purchase_order_id, reason_type, lines: [{sku_id, qty}],
  /// notes}`.
  Future<ApiResult<ReturnNote>> createReturnNote({
    required int purchaseOrderId,
    required String reason,
    required Map<int, double> qtyBySku,
    int? invoiceId,
    String? notes,
  }) =>
      _client.post<ReturnNote>(
        ApiPaths.returnNotes,
        body: {
          'purchase_order_id': purchaseOrderId,
          'invoice_id': ?invoiceId,
          'reason_type': reason,
          'lines': [
            for (final e in qtyBySku.entries)
              if (e.value > 0) {'sku_id': e.key, 'qty': e.value},
          ],
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        parse: (body) => ReturnNote.fromJson(asMap(asMap(body)['data'])),
      );

  /// `accepted` + code, `rejected` + reason, or `goods_returned`.
  Future<ApiResult<void>> setReturnNoteStatus(int id, String status, {String? otpCode, String? reason}) =>
      _client.patch<void>(
        ApiPaths.returnNoteStatus(id),
        body: {'status': status, 'otp_code': ?otpCode, 'reason': ?reason},
      );

  Future<ApiResult<List<CustodyRow>>> custodyLedger() => _client.get<List<CustodyRow>>(
        ApiPaths.custodyLedger,
        parse: (body) => asList(asMap(body)['data'], CustodyRow.fromJson),
      );

  /// Only before the order is accepted; defaults 14 / 14 / 60.
  Future<ApiResult<void>> setConsignmentTerms(int purchaseOrderId, ConsignmentTerms terms) =>
      _client.patch<void>(ApiPaths.consignmentTerms(purchaseOrderId), body: terms.toJson());

  // ------------------------- D: late payment, packs, marketer, Nafith, fees

  Future<ApiResult<LatePaymentStatus>> invoiceLatePayment(int invoiceId) => _client.get<LatePaymentStatus>(
        ApiPaths.invoiceLatePayment(invoiceId),
        dedupe: false,
        parse: (body) => LatePaymentStatus.fromJson(asMap(body)),
      );

  Future<ApiResult<Paged<LatePaymentNotice>>> latePaymentNotices({int page = 1}) =>
      _client.get<Paged<LatePaymentNotice>>(
        ApiPaths.latePaymentNotices,
        query: PageParams.limit(page),
        parse: (body) => pagedFrom(body, LatePaymentNotice.fromJson, keys: const ['notices', 'late_payment_notices']),
      );

  Future<ApiResult<LatePaymentNotice>> latePaymentNotice(int id) => _client.get<LatePaymentNotice>(
        ApiPaths.latePaymentNotice(id),
        parse: (body) {
          final m = asMap(body);
          final inner = m['notice'] ?? m['late_payment_notice'] ?? m['data'];
          return LatePaymentNotice.fromJson(inner is Map ? asMap(inner) : m);
        },
      );

  /// `first` (NTC1) or `second` (NTC2). Not before the due date has passed:
  /// `422 late_payment_not_overdue` (verified).
  Future<ApiResult<void>> issueLatePaymentNotice(int invoiceId, String kind) =>
      _client.post<void>(ApiPaths.invoiceLatePaymentNotices(invoiceId), body: {'kind': kind});

  /// The relationship with its `supply_status` (verified on the detail).
  Future<ApiResult<BusinessRelationship>> relationship(int id) => _client.get<BusinessRelationship>(
        ApiPaths.relationship(id),
        dedupe: false,
        parse: (body) => BusinessRelationship.fromJson(asMap(asMap(body)['relationship'])),
      );

  Future<ApiResult<void>> restoreSupply(int relationshipId) => _client.patch<void>(
        ApiPaths.relationshipSupplyStatus(relationshipId),
        body: const {'supply_status': 'active'},
      );

  Future<ApiResult<DisputePack>> generateDisputePack(String scopeType, int scopeId) => _client.post<DisputePack>(
        ApiPaths.disputePacks,
        body: {'scope_type': scopeType, 'scope_id': scopeId},
        parse: (body) => DisputePack.fromJson(asMap(asMap(body)['dispute_pack'])),
      );

  Future<ApiResult<Paged<DisputePack>>> disputePacks({int page = 1}) => _client.get<Paged<DisputePack>>(
        ApiPaths.disputePacks,
        query: PageParams.limit(page),
        parse: (body) => pagedFrom(body, DisputePack.fromJson),
      );

  Future<ApiResult<DisputePack>> disputePack(int id) => _client.get<DisputePack>(
        ApiPaths.disputePack(id),
        parse: (body) => DisputePack.fromJson(asMap(asMap(body)['dispute_pack'])),
      );

  Future<ApiResult<MarketerOverview>> marketerOverview() => _client.get<MarketerOverview>(
        ApiPaths.marketer,
        dedupe: false,
        parse: (body) => MarketerOverview.fromJson(asMap(body)),
      );

  /// Needs an organization whose `activity_type` is `marketer`
  /// (`422 marketer_activity_type_required` otherwise).
  Future<ApiResult<MarketerProfile>> registerMarketer() => _client.post<MarketerProfile>(
        ApiPaths.marketer,
        body: const <String, dynamic>{},
        parse: (body) => MarketerProfile.fromJson(asMap(asMap(body)['marketer'])),
      );

  Future<ApiResult<Paged<MarketerAssignment>>> myMarketerAssignments({int page = 1}) =>
      _client.get<Paged<MarketerAssignment>>(
        ApiPaths.marketerOwnAssignments,
        query: PageParams.limit(page),
        dedupe: false,
        parse: (body) => pagedFrom(body, MarketerAssignment.fromJson, keys: const ['assignments']),
      );

  /// Level 1 (click) acceptance of an offered assignment.
  Future<ApiResult<void>> acceptMarketerAssignment(int id) =>
      _client.patch<void>(ApiPaths.marketerOwnAssignmentStatus(id), body: const {'status': 'active'});

  Future<ApiResult<Paged<MarketerCommission>>> myMarketerCommissions({int page = 1}) =>
      _client.get<Paged<MarketerCommission>>(
        ApiPaths.marketerOwnCommissions,
        query: PageParams.limit(page),
        parse: (body) => pagedFrom(body, MarketerCommission.fromJson, keys: const ['commissions']),
      );

  Future<ApiResult<Paged<MarketerAssignment>>> supplierMarketerAssignments({int page = 1}) =>
      _client.get<Paged<MarketerAssignment>>(
        ApiPaths.marketerAssignments,
        query: PageParams.limit(page),
        dedupe: false,
        parse: (body) => pagedFrom(body, MarketerAssignment.fromJson, keys: const ['assignments']),
      );

  /// Verified body: `{marketer_code, rate_type, rate_value}`.
  Future<ApiResult<MarketerAssignment>> offerMarketerAssignment({
    required String marketerCode,
    required String rateType,
    required double rateValue,
  }) =>
      _client.post<MarketerAssignment>(
        ApiPaths.marketerAssignments,
        body: {'marketer_code': marketerCode, 'rate_type': rateType, 'rate_value': rateValue},
        parse: (body) => MarketerAssignment.fromJson(asMap(asMap(body)['assignment'])),
      );

  Future<ApiResult<void>> endMarketerAssignment(int id) =>
      _client.patch<void>(ApiPaths.marketerAssignmentStatus(id), body: const {'status': 'ended'});

  Future<ApiResult<void>> linkMarketerPurchaseOrder(int assignmentId, int purchaseOrderId) => _client.post<void>(
        ApiPaths.marketerAssignmentPurchaseOrders(assignmentId),
        body: {'purchase_order_id': purchaseOrderId},
      );

  Future<ApiResult<Paged<MarketerCommission>>> supplierMarketerCommissions({int page = 1}) =>
      _client.get<Paged<MarketerCommission>>(
        ApiPaths.marketerCommissions,
        query: PageParams.limit(page),
        parse: (body) => pagedFrom(body, MarketerCommission.fromJson, keys: const ['commissions']),
      );

  Future<ApiResult<PromissoryNotes>> promissoryNotes(int invoiceId) => _client.get<PromissoryNotes>(
        ApiPaths.invoicePromissoryNotes(invoiceId),
        dedupe: false,
        parse: (body) => PromissoryNotes.fromJson(asMap(body)),
      );

  /// With the Nafith API off: the number Nafith issued on its own site.
  Future<ApiResult<void>> recordPromissoryNote(int invoiceId, String instrumentNo) => _client.post<void>(
        ApiPaths.invoicePromissoryNotes(invoiceId),
        body: {'nafith_instrument_no': instrumentNo},
      );

  /// The header (`free_period`, `new_orders_restricted`, …) comes with every
  /// page; the order screens read it with `limit: 1` to stay light.
  Future<ApiResult<ServiceInvoices>> serviceInvoices({int page = 1, int limit = 20}) =>
      _client.get<ServiceInvoices>(
        ApiPaths.serviceInvoices,
        query: PageParams.limit(page, size: limit),
        parse: (body) => ServiceInvoices.fromJson(asMap(body)),
      );

  Future<ApiResult<ServiceInvoice>> serviceInvoice(int id) => _client.get<ServiceInvoice>(
        ApiPaths.serviceInvoice(id),
        parse: (body) {
          final m = asMap(body);
          final inner = asMap(m['service_invoice'] ?? m['data']);
          return ServiceInvoice.fromJson(inner.isEmpty ? m : inner);
        },
      );

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The compliance endpoints answer lists in more than one envelope: a bare
/// array, a Laravel paginator, or a paginator under a named key. One reader
/// for all of them.
Paged<T> pagedFrom<T>(
  dynamic body,
  T Function(Map<String, dynamic>) f, {
  List<String> keys = const [],
}) {
  if (body is List) {
    final rows = asList(body, f);
    return Paged(items: rows, currentPage: 1, lastPage: 1, perPage: rows.length, total: rows.length);
  }
  final m = asMap(body);
  if (m['data'] is List) return Paged.fromJson(m, f);
  // The compliance lists: `{<plural>: [...], pagination: {current_page, …}}`.
  final pagination = asMap(m['pagination']);
  if (pagination.isNotEmpty) {
    for (final key in keys) {
      if (m[key] is List) return Paged.fromJson({...pagination, 'data': m[key]}, f, formattedKey: false);
    }
  }
  for (final key in [...keys, 'items']) {
    final inner = m[key];
    if (inner is List || inner is Map) return pagedFrom(inner, f);
  }
  return Paged<T>.empty();
}
