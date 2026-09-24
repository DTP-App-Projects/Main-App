import '../../../core/network/coerce.dart';
import 'purchase_order.dart';
import 'supplier_summary.dart';

/// The supplier issues it; the trader reads it and pays against it.
class Invoice {
  final int id;
  final int? purchaseOrderId;
  final NamedRef? purchaseOrder;
  final int? deliveryNoteId;
  final int? contractId;
  final int? businessRelationshipId;
  final int? paymentTermId;

  /// Invoice numbers are frequently all digits.
  final String invoiceNo;

  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final String status;

  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final String currencyCode;

  final PaymentTerm? paymentTerm;

  /// Instalments. A term with `installment_count > 1` produces several.
  final List<DueSchedule> dueSchedules;

  /// What is still owed. Displayed as sent — never recomputed from the lines.
  final double outstandingAmount;

  final List<InvoiceLine> lines;

  const Invoice({
    required this.id,
    required this.purchaseOrderId,
    required this.purchaseOrder,
    required this.deliveryNoteId,
    required this.contractId,
    required this.businessRelationshipId,
    required this.paymentTermId,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.dueDate,
    required this.status,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.currencyCode,
    required this.paymentTerm,
    required this.dueSchedules,
    required this.outstandingAmount,
    required this.lines,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: asInt(j['id']),
        purchaseOrderId: asIntOrNull(j['purchase_order_id']),
        purchaseOrder:
            j['purchase_order'] is Map ? NamedRef.fromJson(asMap(j['purchase_order'])) : null,
        deliveryNoteId: asIntOrNull(j['delivery_note_id']),
        contractId: asIntOrNull(j['contract_id']),
        businessRelationshipId: asIntOrNull(j['business_relationship_id']),
        paymentTermId: asIntOrNull(j['payment_term_id']),
        invoiceNo: asStr(j['invoice_no']),
        invoiceDate: asDate(j['invoice_date']),
        dueDate: asDate(j['due_date']),
        status: asStr(j['status']),
        subtotal: asNum(j['subtotal']),
        taxTotal: asNum(j['tax_total']),
        grandTotal: asNum(j['grand_total']),
        currencyCode: asStr(j['currency_code']),
        paymentTerm:
            j['payment_term'] is Map ? PaymentTerm.fromJson(asMap(j['payment_term'])) : null,
        dueSchedules: asList(j['due_schedules'], DueSchedule.fromJson),
        outstandingAmount: asNum(j['outstanding_amount']),
        lines: asList(j['lines'], InvoiceLine.fromJson),
      );

  bool get isPaid => status == 'paid' || outstandingAmount <= 0;

  bool get isOverdue {
    if (isPaid) return false;
    final due = dueDate;
    return due != null && due.isBefore(DateTime.now());
  }

  /// The instalment a trader would naturally pay next: the earliest unpaid
  /// one. Falls back to the whole invoice when there are no schedules.
  DueSchedule? get nextDue {
    final unpaid = dueSchedules.where((s) => !s.isSettled).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
    return unpaid.isEmpty ? null : unpaid.first;
  }
}

class DueSchedule {
  final int id;
  final int installmentNo;
  final DateTime? dueDate;
  final double dueAmount;
  final double paidAmount;
  final String status;

  const DueSchedule({
    required this.id,
    required this.installmentNo,
    required this.dueDate,
    required this.dueAmount,
    required this.paidAmount,
    required this.status,
  });

  factory DueSchedule.fromJson(Map<String, dynamic> j) => DueSchedule(
        id: asInt(j['id']),
        installmentNo: asInt(j['installment_no']),
        dueDate: asDate(j['due_date']),
        dueAmount: asNum(j['due_amount']),
        paidAmount: asNum(j['paid_amount']),
        status: asStr(j['status']),
      );

  bool get isSettled => status == 'paid' || status == 'settled' || paidAmount >= dueAmount;

  double get outstanding {
    final remaining = dueAmount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isOverdue {
    if (isSettled) return false;
    final due = dueDate;
    return due != null && due.isBefore(DateTime.now());
  }
}

class InvoiceLine {
  final int id;
  final int skuId;
  final String skuName;
  final double qty;
  final double unitPrice;
  final double taxValue;
  final double lineTotal;

  const InvoiceLine({
    required this.id,
    required this.skuId,
    required this.skuName,
    required this.qty,
    required this.unitPrice,
    required this.taxValue,
    required this.lineTotal,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        id: asInt(j['id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name'] ?? j['name']),
        qty: asNum(j['qty']),
        unitPrice: asNum(j['unit_price']),
        taxValue: asNum(j['tax_value']),
        lineTotal: asNum(j['line_total']),
      );
}

/// A payment record. The trader **claims** one ("I paid — please confirm");
/// the supplier records and confirms.
class CollectionReceipt {
  final int id;
  final int? businessRelationshipId;
  final int? invoiceId;
  final int? dueScheduleId;
  final String receiptNo;
  final String paymentMethod;
  final double amount;
  final DateTime? receivedAt;
  final DateTime? confirmedAt;
  final String referenceNo;
  final String proofFile;
  final String status;
  final NamedRef? invoice;

  const CollectionReceipt({
    required this.id,
    required this.businessRelationshipId,
    required this.invoiceId,
    required this.dueScheduleId,
    required this.receiptNo,
    required this.paymentMethod,
    required this.amount,
    required this.receivedAt,
    required this.confirmedAt,
    required this.referenceNo,
    required this.proofFile,
    required this.status,
    required this.invoice,
  });

  factory CollectionReceipt.fromJson(Map<String, dynamic> j) => CollectionReceipt(
        id: asInt(j['id']),
        businessRelationshipId: asIntOrNull(j['business_relationship_id']),
        invoiceId: asIntOrNull(j['invoice_id']),
        dueScheduleId: asIntOrNull(j['due_schedule_id']),
        receiptNo: asStr(j['receipt_no']),
        paymentMethod: asStr(j['payment_method']),
        amount: asNum(j['amount']),
        receivedAt: asDate(j['received_at']),
        confirmedAt: asDate(j['confirmed_at']),
        referenceNo: asStr(j['reference_no']),
        proofFile: asStr(j['proof_file']),
        status: asStr(j['status']),
        invoice: j['invoice'] is Map ? NamedRef.fromJson(asMap(j['invoice'])) : null,
      );

  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isPending => !isConfirmed && !isRejected;
}

/// Raised by the trader after an invoice; the supplier approves or rejects it
/// and a credit note follows.
class PostInvoiceReturn {
  final int id;
  final int invoiceId;
  final String reasonType;
  final String reasonNotes;
  final String status;
  final String currencyCode;
  final double totalAmount;
  final DateTime? createdAt;
  final List<ReturnLine> lines;

  const PostInvoiceReturn({
    required this.id,
    required this.invoiceId,
    required this.reasonType,
    required this.reasonNotes,
    required this.status,
    required this.currencyCode,
    required this.totalAmount,
    required this.createdAt,
    required this.lines,
  });

  factory PostInvoiceReturn.fromJson(Map<String, dynamic> j) => PostInvoiceReturn(
        id: asInt(j['id']),
        invoiceId: asInt(j['invoice_id']),
        reasonType: asStr(j['reason_type']),
        reasonNotes: unwrap(j['reason_notes']),
        status: asStr(j['status']),
        currencyCode: asStr(j['currency_code']),
        totalAmount: asNum(j['total_amount'] ?? j['grand_total']),
        createdAt: asDate(j['created_at']),
        lines: asList(j['lines'], ReturnLine.fromJson),
      );

  /// The documented `reason_type` enum.
  static const reasonTypes = [
    'latent_defect',
    'damage',
    'wrong_item',
    'quality',
    'other',
  ];
}

class ReturnLine {
  final int id;
  final int? invoiceLineId;
  final int skuId;
  final String skuName;
  final double qty;
  final String lineReason;

  const ReturnLine({
    required this.id,
    required this.invoiceLineId,
    required this.skuId,
    required this.skuName,
    required this.qty,
    required this.lineReason,
  });

  factory ReturnLine.fromJson(Map<String, dynamic> j) => ReturnLine(
        id: asInt(j['id']),
        invoiceLineId: asIntOrNull(j['invoice_line_id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name']),
        qty: asNum(j['qty']),
        lineReason: unwrap(j['line_reason']),
      );
}
