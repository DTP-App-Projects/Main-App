import '../../../core/network/coerce.dart';
import 'supplier_summary.dart';

/// The supplier's shipment. The trader reads it, tracks it, and receives
/// against it — but never writes it.
class DeliveryNote {
  final int id;
  final int purchaseOrderId;
  final String purchaseOrderCode;
  final String code;
  final String status;

  final String cancelReason;
  final String cancelReasonLabel;
  final String cancelNote;
  final DateTime? canceledAt;

  final int? supplierBranchId;
  final int? traderBranchId;
  final NamedRef? supplierBranch;
  final NamedRef? traderBranch;

  final DateTime? dispatchedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? deliveredAt;

  final String proofFile;
  final String notes;

  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final String currency;

  final RouteStop? routeStop;
  final DriverInfo? driver;
  final VehicleInfo? vehicle;

  /// Seals applied at pickup. All-digit seal numbers arrive as numbers.
  final List<String> pickupSealNumbers;

  /// **The tamper check.** False means the seals recorded at delivery do not
  /// match the ones applied at pickup — surfaced prominently, never buried.
  final bool sealsMatch;

  final List<DeliveryLine> lines;
  final int goodsReceiptsCount;

  const DeliveryNote({
    required this.id,
    required this.purchaseOrderId,
    required this.purchaseOrderCode,
    required this.code,
    required this.status,
    required this.cancelReason,
    required this.cancelReasonLabel,
    required this.cancelNote,
    required this.canceledAt,
    required this.supplierBranchId,
    required this.traderBranchId,
    required this.supplierBranch,
    required this.traderBranch,
    required this.dispatchedAt,
    required this.enRouteAt,
    required this.arrivedAt,
    required this.deliveredAt,
    required this.proofFile,
    required this.notes,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.currency,
    required this.routeStop,
    required this.driver,
    required this.vehicle,
    required this.pickupSealNumbers,
    required this.sealsMatch,
    required this.lines,
    required this.goodsReceiptsCount,
  });

  factory DeliveryNote.fromJson(Map<String, dynamic> j) => DeliveryNote(
        id: asInt(j['id']),
        purchaseOrderId: asInt(j['purchase_order_id']),
        purchaseOrderCode: asStr(j['purchase_order_code']),
        code: asStr(j['code']),
        status: asStr(j['status']),
        cancelReason: asStr(j['cancel_reason']),
        cancelReasonLabel: unwrap(j['cancel_reason_label']),
        cancelNote: unwrap(j['cancel_note']),
        canceledAt: asDate(j['canceled_at']),
        supplierBranchId: asIntOrNull(j['supplier_branch_id']),
        traderBranchId: asIntOrNull(j['trader_branch_id']),
        supplierBranch: j['supplier_branch'] is Map
            ? NamedRef.fromJson(asMap(j['supplier_branch']))
            : null,
        traderBranch:
            j['trader_branch'] is Map ? NamedRef.fromJson(asMap(j['trader_branch'])) : null,
        dispatchedAt: asDate(j['dispatched_at']),
        enRouteAt: asDate(j['en_route_at']),
        arrivedAt: asDate(j['arrived_at']),
        deliveredAt: asDate(j['delivered_at']),
        proofFile: asStr(j['proof_file']),
        notes: unwrap(j['notes']),
        subtotal: asNum(j['subtotal']),
        taxTotal: asNum(j['tax_total']),
        grandTotal: asNum(j['grand_total']),
        currency: asStr(j['currency']),
        routeStop: j['route_stop'] is Map ? RouteStop.fromJson(asMap(j['route_stop'])) : null,
        driver: j['driver'] is Map ? DriverInfo.fromJson(asMap(j['driver'])) : null,
        vehicle: j['vehicle'] is Map ? VehicleInfo.fromJson(asMap(j['vehicle'])) : null,
        pickupSealNumbers: asStrList(j['pickup_seal_numbers']),
        // Absent means "nothing to compare yet", which is not a mismatch.
        sealsMatch: j['seals_match'] == null ? true : asBool(j['seals_match']),
        lines: asList(j['lines'], DeliveryLine.fromJson),
        goodsReceiptsCount: asInt(j['goods_receipts_count']),
      );

  bool get isCanceled => status == 'canceled';
  bool get isDelivered => status == 'delivered';

  /// A shipment on the road is the one worth polling.
  bool get isInTransit =>
      status == 'dispatched' || status == 'en_route' || status == 'arrived';

  /// The trader can only receive what has actually turned up.
  bool get canReceive => (isDelivered || status == 'arrived') && !isCanceled;

  bool get sealsTampered => pickupSealNumbers.isNotEmpty && !sealsMatch;
}

class DeliveryLine {
  final int id;
  final int? purchaseOrderLineId;
  final int skuId;
  final String skuName;
  final int? productId;
  final String productName;
  final double shippedQty;
  final double acceptedQty;
  final double rejectedQty;
  final double unitPrice;
  final double taxValue;
  final double lineTotal;

  const DeliveryLine({
    required this.id,
    required this.purchaseOrderLineId,
    required this.skuId,
    required this.skuName,
    required this.productId,
    required this.productName,
    required this.shippedQty,
    required this.acceptedQty,
    required this.rejectedQty,
    required this.unitPrice,
    required this.taxValue,
    required this.lineTotal,
  });

  factory DeliveryLine.fromJson(Map<String, dynamic> j) => DeliveryLine(
        id: asInt(j['id']),
        purchaseOrderLineId: asIntOrNull(j['purchase_order_line_id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name']),
        productId: asIntOrNull(j['product_id']),
        productName: unwrap(j['product_name']),
        shippedQty: asNum(j['shipped_qty']),
        acceptedQty: asNum(j['accepted_qty']),
        rejectedQty: asNum(j['rejected_qty']),
        unitPrice: asNum(j['unit_price']),
        taxValue: asNum(j['tax_value']),
        lineTotal: asNum(j['line_total']),
      );
}

/// The stop on the driver's route that belongs to this delivery.
class RouteStop {
  final int id;
  final String status;
  final DateTime? plannedArrivalTime;
  final DateTime? actualArrivalTime;
  final DateTime? actualDepartureTime;
  final double? arrivalLatitude;
  final double? arrivalLongitude;
  final String receiverOtpStatus;

  /// The chain of custody: pickup photo and signature at the supplier,
  /// delivery photo and signature at the trader. Rendered as the handoff
  /// timeline rather than a file list.
  final List<DeliveryProof> proofs;

  const RouteStop({
    required this.id,
    required this.status,
    required this.plannedArrivalTime,
    required this.actualArrivalTime,
    required this.actualDepartureTime,
    required this.arrivalLatitude,
    required this.arrivalLongitude,
    required this.receiverOtpStatus,
    required this.proofs,
  });

  factory RouteStop.fromJson(Map<String, dynamic> j) => RouteStop(
        id: asInt(j['id']),
        status: asStr(j['status']),
        plannedArrivalTime: asDate(j['planned_arrival_time']),
        actualArrivalTime: asDate(j['actual_arrival_time']),
        actualDepartureTime: asDate(j['actual_departure_time']),
        arrivalLatitude: j['arrival_latitude'] == null ? null : asNum(j['arrival_latitude']),
        arrivalLongitude:
            j['arrival_longitude'] == null ? null : asNum(j['arrival_longitude']),
        receiverOtpStatus: asStr(j['receiver_otp_status']),
        proofs: asList(j['proofs'], DeliveryProof.fromJson),
      );

  bool get hasArrived => actualArrivalTime != null;
}

class DeliveryProof {
  final int id;
  final String proofType;
  final String proofCategory;
  final String filePath;
  final String fileType;
  final String signerName;
  final String signerRole;
  final DateTime? capturedAt;

  const DeliveryProof({
    required this.id,
    required this.proofType,
    required this.proofCategory,
    required this.filePath,
    required this.fileType,
    required this.signerName,
    required this.signerRole,
    required this.capturedAt,
  });

  factory DeliveryProof.fromJson(Map<String, dynamic> j) => DeliveryProof(
        id: asInt(j['id']),
        proofType: asStr(j['proof_type']),
        proofCategory: asStr(j['proof_category']),
        filePath: asStr(j['file_path']),
        fileType: asStr(j['file_type']),
        signerName: unwrap(j['signer_name']),
        signerRole: asStr(j['signer_role']),
        capturedAt: asDate(j['captured_at']),
      );

  bool get isSignature => proofType.contains('signature');
  bool get isPhoto => proofType.contains('photo') || fileType.startsWith('image');
}

class DriverInfo {
  final int id;
  final String name;

  /// `m_p`-guarded so the leading zero survives.
  final String phone;

  const DriverInfo({required this.id, required this.name, required this.phone});

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
        id: asInt(j['id']),
        name: unwrap(j['name']),
        phone: unwrap(j['phone']),
      );
}

class VehicleInfo {
  final int id;
  final String plateNumber;

  const VehicleInfo({required this.id, required this.plateNumber});

  factory VehicleInfo.fromJson(Map<String, dynamic> j) => VehicleInfo(
        id: asInt(j['id']),
        plateNumber: asStr(j['plate_number']),
      );
}

/// The trader's count of what actually arrived.
class GoodsReceipt {
  final int id;
  final int purchaseOrderId;
  final int deliveryNoteId;
  final String status;
  final DateTime? receivedAt;
  final String notes;
  final String proofFile;

  final double driverDeliveredQtyTotal;
  final double traderAccountedQtyTotal;

  /// The "flag this receipt" signal: what the driver handed over and what the
  /// trader counted do not agree.
  final bool qtyMismatchWithDriver;

  final DateTime? disputedAt;
  final String disputeReason;
  final List<GoodsReceiptLine> lines;

  const GoodsReceipt({
    required this.id,
    required this.purchaseOrderId,
    required this.deliveryNoteId,
    required this.status,
    required this.receivedAt,
    required this.notes,
    required this.proofFile,
    required this.driverDeliveredQtyTotal,
    required this.traderAccountedQtyTotal,
    required this.qtyMismatchWithDriver,
    required this.disputedAt,
    required this.disputeReason,
    required this.lines,
  });

  factory GoodsReceipt.fromJson(Map<String, dynamic> j) => GoodsReceipt(
        id: asInt(j['id']),
        purchaseOrderId: asInt(j['purchase_order_id']),
        deliveryNoteId: asInt(j['delivery_note_id']),
        status: asStr(j['status']),
        receivedAt: asDate(j['received_at']),
        notes: unwrap(j['notes']),
        proofFile: asStr(j['proof_file']),
        driverDeliveredQtyTotal: asNum(j['driver_delivered_qty_total']),
        traderAccountedQtyTotal: asNum(j['trader_accounted_qty_total']),
        qtyMismatchWithDriver: asBool(j['qty_mismatch_with_driver']),
        disputedAt: asDate(j['disputed_at']),
        disputeReason: unwrap(j['dispute_reason']),
        lines: asList(j['lines'], GoodsReceiptLine.fromJson),
      );

  bool get isDisputed => disputedAt != null;
}

class GoodsReceiptLine {
  final int id;
  final int? deliveryNoteLineId;
  final int skuId;
  final String skuName;
  final double receivedQty;
  final double rejectedQty;
  final String rejectionReason;

  const GoodsReceiptLine({
    required this.id,
    required this.deliveryNoteLineId,
    required this.skuId,
    required this.skuName,
    required this.receivedQty,
    required this.rejectedQty,
    required this.rejectionReason,
  });

  factory GoodsReceiptLine.fromJson(Map<String, dynamic> j) => GoodsReceiptLine(
        id: asInt(j['id']),
        deliveryNoteLineId: asIntOrNull(j['delivery_note_line_id']),
        skuId: asInt(j['sku_id']),
        skuName: unwrap(j['sku_name']),
        receivedQty: asNum(j['received_qty']),
        rejectedQty: asNum(j['rejected_qty']),
        rejectionReason: unwrap(j['rejection_reason']),
      );
}
