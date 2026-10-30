import '../../../core/network/coerce.dart';
import 'chain.dart';

/// `quotations` (template ب). Verified on staging 2026-10-05.
class Quotation {
  final int id;
  final String quotationNo;
  final int relationshipId;
  final ChainParty? supplier;
  final ChainParty? trader;
  final String supplyModel;
  final String supplyModelLabel;

  /// UTC. Shown as the expiry; [isValidNow] is the server's own answer.
  final DateTime? validUntil;
  final bool isValidNow;

  /// `draft`, `sent`, `accepted`, `cancelled`, `expired`.
  final String status;
  final String statusLabel;
  final String deliveryPlace;
  final int? supplyDays;
  final String notes;
  final String currencyCode;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final int? purchaseOrderId;
  final String myRole;
  final bool canAccept;
  final bool canSend;
  final bool canCancel;
  final String otpDocumentType;
  final int? frozenDocumentId;
  final String bodyText;
  final String documentHash;
  final List<QuotationLine> lines;

  const Quotation({
    required this.id,
    this.quotationNo = '',
    this.relationshipId = 0,
    this.supplier,
    this.trader,
    this.supplyModel = '',
    this.supplyModelLabel = '',
    this.validUntil,
    this.isValidNow = false,
    this.status = '',
    this.statusLabel = '',
    this.deliveryPlace = '',
    this.supplyDays,
    this.notes = '',
    this.currencyCode = 'SAR',
    this.subtotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.sentAt,
    this.acceptedAt,
    this.purchaseOrderId,
    this.myRole = '',
    this.canAccept = false,
    this.canSend = false,
    this.canCancel = false,
    this.otpDocumentType = 'quotation',
    this.frozenDocumentId,
    this.bodyText = '',
    this.documentHash = '',
    this.lines = const [],
  });

  ChainParty? get counterparty => myRole == 'supplier' ? trader : supplier;

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: asInt(j['id']),
        quotationNo: asStr(j['quotation_no']),
        relationshipId: asInt(j['business_relationship_id']),
        supplier: ChainParty.maybe(j['supplier']),
        trader: ChainParty.maybe(j['trader']),
        supplyModel: asStr(j['supply_model']),
        supplyModelLabel: unwrap(j['supply_model_label']),
        validUntil: asUtcDate(j['valid_until']),
        isValidNow: asBool(j['is_valid_now']),
        status: asStr(j['status']),
        statusLabel: unwrap(j['status_label']),
        deliveryPlace: unwrap(j['delivery_place']),
        supplyDays: asIntOrNull(j['supply_days']),
        notes: unwrap(j['notes']),
        currencyCode: asStr(j['currency_code']).isEmpty ? 'SAR' : asStr(j['currency_code']),
        subtotal: asNum(j['subtotal']),
        taxTotal: asNum(j['tax_total']),
        grandTotal: asNum(j['grand_total']),
        sentAt: asUtcDate(j['sent_at']),
        acceptedAt: asUtcDate(j['accepted_at']),
        purchaseOrderId: asIntOrNull(j['purchase_order_id']),
        myRole: asStr(j['my_role']),
        canAccept: asBool(j['can_accept']),
        canSend: asBool(j['can_send']),
        canCancel: asBool(j['can_cancel']),
        otpDocumentType: asStr(j['otp_document_type']).isEmpty ? 'quotation' : asStr(j['otp_document_type']),
        frozenDocumentId: asIntOrNull(j['frozen_document_id']),
        bodyText: unwrap(j['body_text']),
        documentHash: asStr(j['document_hash']),
        lines: asList(j['lines'], QuotationLine.fromJson),
      );
}

class QuotationLine {
  final int id;
  final int skuId;
  final String skuCode;
  final String name;
  final String unit;
  final double qty;
  final double unitPrice;
  final double vatRate;
  final double lineSubtotal;
  final double lineTax;
  final double lineTotal;

  const QuotationLine({
    required this.id,
    required this.skuId,
    this.skuCode = '',
    this.name = '',
    this.unit = '',
    this.qty = 0,
    this.unitPrice = 0,
    this.vatRate = 0,
    this.lineSubtotal = 0,
    this.lineTax = 0,
    this.lineTotal = 0,
  });

  factory QuotationLine.fromJson(Map<String, dynamic> j) => QuotationLine(
        id: asInt(j['id']),
        skuId: asInt(j['sku_id']),
        skuCode: asStr(j['sku_code']),
        name: unwrap(j['name']),
        unit: unwrap(j['unit']),
        qty: asNum(j['qty']),
        unitPrice: asNum(j['unit_price']),
        vatRate: asNum(j['vat_rate']),
        lineSubtotal: asNum(j['line_subtotal']),
        lineTax: asNum(j['line_tax']),
        lineTotal: asNum(j['line_total']),
      );
}

/// A line of `POST /quotations`: `{sku_id, qty, unit_price}` (verified).
class QuotationLineInput {
  final int skuId;
  final double qty;
  final double unitPrice;

  const QuotationLineInput({required this.skuId, required this.qty, required this.unitPrice});

  Map<String, dynamic> toJson() => {'sku_id': skuId, 'qty': qty, 'unit_price': unitPrice};
}
