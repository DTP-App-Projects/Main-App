import '../../../core/network/coerce.dart';
import '../../../core/network/paged.dart';
import 'fleet_common.dart';

/// «البيع المتجول» — a van load sheet and the trip it becomes.
///
/// `draft` → `on_road` (the driver entered the load code) → `returning` (the
/// driver ended the trip and shows a return code) → `reconciled`; or
/// `draft` → `canceled`. For every line:
/// loaded = sold + delivered + returned + damaged + missing.
class VanTrip {
  final int id;
  final String code;
  final String status;
  final VanDriver? driver;
  final VanVehicle? vehicle;
  final NamedPlace? warehouse;
  final int salesCount;
  final double salesTotal;
  final DateTime? loadedAt;
  final DateTime? reconciledAt;
  final DateTime? createdAt;

  // Detail only.
  final double? maxDiscountPercent;
  final String notes;

  /// Only while `draft`: shown to the driver once the van is loaded.
  final String? loadCode;
  final DateTime? returnStartedAt;

  /// The cash the driver must hand over.
  final double cashSalesTotal;

  /// Set by the reconciliation.
  final double? cashExpected;
  final double? cashHandedOver;
  final String varianceReason;
  final String createdBy;
  final List<VanTripLine> lines;

  const VanTrip({
    required this.id,
    required this.code,
    required this.status,
    this.driver,
    this.vehicle,
    this.warehouse,
    this.salesCount = 0,
    this.salesTotal = 0,
    this.loadedAt,
    this.reconciledAt,
    this.createdAt,
    this.maxDiscountPercent,
    this.notes = '',
    this.loadCode,
    this.returnStartedAt,
    this.cashSalesTotal = 0,
    this.cashExpected,
    this.cashHandedOver,
    this.varianceReason = '',
    this.createdBy = '',
    this.lines = const [],
  });

  factory VanTrip.fromJson(Map<String, dynamic> j) => VanTrip(
    id: asInt(j['id']),
    code: asStr(j['code']),
    status: asStr(j['status']),
    driver: j['driver'] is Map ? VanDriver.fromJson(asMap(j['driver'])) : null,
    vehicle: j['vehicle'] is Map ? VanVehicle.fromJson(asMap(j['vehicle'])) : null,
    warehouse: NamedPlace.maybe(j['warehouse']),
    salesCount: asInt(j['sales_count']),
    salesTotal: asNum(j['sales_total']),
    loadedAt: fleetTime(j['loaded_at']),
    reconciledAt: fleetTime(j['reconciled_at']),
    createdAt: fleetTime(j['created_at']),
    maxDiscountPercent: asNumOrNull(j['max_discount_percent']),
    notes: asStr(j['notes']),
    loadCode: sixDigitCode(j['load_code']),
    returnStartedAt: fleetTime(j['return_started_at']),
    cashSalesTotal: asNum(j['cash_sales_total']),
    cashExpected: asNumOrNull(j['cash_expected']),
    cashHandedOver: asNumOrNull(j['cash_handed_over']),
    varianceReason: asStr(j['variance_reason']),
    createdBy: asStr(j['created_by']),
    lines: asList(j['lines'], VanTripLine.fromJson),
  );

  bool get isDraft => status == 'draft';
  bool get isOnRoad => status == 'on_road';
  bool get isReturning => status == 'returning';
  bool get isClosed => status == 'reconciled' || status == 'canceled';

  /// The cash variance after reconciliation (handed over − expected).
  double? get cashVariance =>
      (cashExpected == null || cashHandedOver == null) ? null : cashHandedOver! - cashExpected!;

  /// The live figures poll replaces the lines and the cash, nothing else.
  VanTrip withFigures(VanTripFigures f) => VanTrip(
    id: id,
    code: code,
    status: status,
    driver: driver,
    vehicle: vehicle,
    warehouse: warehouse,
    salesCount: f.salesCount,
    salesTotal: salesTotal,
    loadedAt: loadedAt,
    reconciledAt: reconciledAt,
    createdAt: createdAt,
    maxDiscountPercent: maxDiscountPercent,
    notes: notes,
    loadCode: loadCode,
    returnStartedAt: returnStartedAt,
    cashSalesTotal: f.cashSalesTotal,
    cashExpected: cashExpected,
    cashHandedOver: cashHandedOver,
    varianceReason: varianceReason,
    createdBy: createdBy,
    lines: f.lines,
  );

  static const statuses = ['draft', 'on_road', 'returning', 'reconciled', 'canceled'];
}

class VanDriver {
  final int id;
  final String name;
  final String phone;

  const VanDriver({required this.id, required this.name, this.phone = ''});

  factory VanDriver.fromJson(Map<String, dynamic> j) =>
      VanDriver(id: asInt(j['id']), name: asStr(j['name']), phone: asStr(j['phone']));
}

class VanVehicle {
  final int id;
  final String plateNumber;

  const VanVehicle({required this.id, required this.plateNumber});

  factory VanVehicle.fromJson(Map<String, dynamic> j) =>
      VanVehicle(id: asInt(j['id']), plateNumber: asStr(j['plate_number']));
}

class VanTripLine {
  final int lineId;
  final int skuId;
  final String name;
  final String barcode;
  final double unitPrice;
  final double loaded;
  final double sold;
  final double delivered;

  /// Still on the van.
  final double inVan;

  /// Reserved for a delivery not handed over yet.
  final double inTransit;

  /// What the driver declared when ending the trip.
  final double? driverReturned;
  final double returned;
  final double damaged;
  final double missing;

  const VanTripLine({
    required this.lineId,
    required this.skuId,
    required this.name,
    this.barcode = '',
    this.unitPrice = 0,
    this.loaded = 0,
    this.sold = 0,
    this.delivered = 0,
    this.inVan = 0,
    this.inTransit = 0,
    this.driverReturned,
    this.returned = 0,
    this.damaged = 0,
    this.missing = 0,
  });

  factory VanTripLine.fromJson(Map<String, dynamic> j) => VanTripLine(
    lineId: asInt(j['line_id']),
    skuId: asInt(j['sku_id']),
    name: asStr(j['name']),
    barcode: asStr(j['barcode']),
    unitPrice: asNum(j['unit_price']),
    loaded: asNum(j['loaded']),
    sold: asNum(j['sold']),
    delivered: asNum(j['delivered']),
    inVan: asNum(j['in_van']),
    inTransit: asNum(j['in_transit']),
    driverReturned: asNumOrNull(j['driver_returned']),
    returned: asNum(j['returned']),
    damaged: asNum(j['damaged']),
    missing: asNum(j['missing']),
  );
}

/// A walk-in sale from the van (a simplified tax invoice).
class VanSale {
  final int id;
  final String buyerName;
  final String buyerPhone;
  final String buyerVatNo;
  final String paymentMethod;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final DateTime? createdAt;
  final List<VanSaleLine> lines;
  final VanSaleInvoice? invoice;

  const VanSale({
    required this.id,
    this.buyerName = '',
    this.buyerPhone = '',
    this.buyerVatNo = '',
    this.paymentMethod = '',
    this.subtotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.createdAt,
    this.lines = const [],
    this.invoice,
  });

  factory VanSale.fromJson(Map<String, dynamic> j) => VanSale(
    id: asInt(j['id']),
    buyerName: asStr(j['buyer_name']),
    buyerPhone: asStr(j['buyer_phone']),
    buyerVatNo: asStr(j['buyer_vat_no']),
    paymentMethod: asStr(j['payment_method']),
    subtotal: asNum(j['subtotal']),
    taxTotal: asNum(j['tax_total']),
    grandTotal: asNum(j['grand_total']),
    createdAt: fleetTime(j['created_at']),
    lines: asList(j['lines'], VanSaleLine.fromJson),
    invoice: j['invoice'] is Map ? VanSaleInvoice.fromJson(asMap(j['invoice'])) : null,
  );
}

class VanSaleLine {
  final int skuId;
  final String name;
  final double qty;
  final double unitPrice;
  final double discountValue;
  final double taxValue;
  final double lineTotal;

  const VanSaleLine({
    required this.skuId,
    required this.name,
    this.qty = 0,
    this.unitPrice = 0,
    this.discountValue = 0,
    this.taxValue = 0,
    this.lineTotal = 0,
  });

  factory VanSaleLine.fromJson(Map<String, dynamic> j) => VanSaleLine(
    skuId: asInt(j['sku_id']),
    name: asStr(j['name']),
    qty: asNum(j['qty']),
    unitPrice: asNum(j['unit_price']),
    discountValue: asNum(j['discount_value']),
    taxValue: asNum(j['tax_value']),
    lineTotal: asNum(j['line_total']),
  );
}

class VanSaleInvoice {
  final int id;
  final String invoiceNo;
  final String title;
  final String zatcaQr;
  final String shareUrl;

  const VanSaleInvoice({
    required this.id,
    this.invoiceNo = '',
    this.title = '',
    this.zatcaQr = '',
    this.shareUrl = '',
  });

  factory VanSaleInvoice.fromJson(Map<String, dynamic> j) => VanSaleInvoice(
    id: asInt(j['id']),
    invoiceNo: asStr(j['invoice_no']),
    title: asStr(j['title']),
    zatcaQr: asStr(j['zatca_qr']),
    shareUrl: asStr(j['share_url']),
  );
}

/// A delivery note to a registered trader, carried from this van.
class VanDelivery {
  final int id;
  final String code;
  final String status;
  final int? purchaseOrderId;
  final String trader;
  final String traderBranch;
  final DateTime? createdAt;

  const VanDelivery({
    required this.id,
    required this.code,
    required this.status,
    this.purchaseOrderId,
    this.trader = '',
    this.traderBranch = '',
    this.createdAt,
  });

  factory VanDelivery.fromJson(Map<String, dynamic> j) => VanDelivery(
    id: asInt(j['id']),
    code: asStr(j['code']),
    status: asStr(j['status']),
    purchaseOrderId: asIntOrNull(j['purchase_order_id']),
    trader: asStr(j['trader']),
    traderBranch: asStr(j['trader_branch']),
    createdAt: fleetTime(j['created_at']),
  );
}

/// `GET /fleet/van_trips/{id}` → `{trip, sales, deliveries}`.
class VanTripDetail {
  final VanTrip trip;
  final List<VanSale> sales;
  final List<VanDelivery> deliveries;

  const VanTripDetail({required this.trip, this.sales = const [], this.deliveries = const []});

  factory VanTripDetail.fromJson(Map<String, dynamic> j) => VanTripDetail(
    trip: VanTrip.fromJson(asMap(j['trip'])),
    sales: asList(j['sales'], VanSale.fromJson),
    deliveries: asList(j['deliveries'], VanDelivery.fromJson),
  );

  VanTripDetail copyWith({VanTrip? trip}) =>
      VanTripDetail(trip: trip ?? this.trip, sales: sales, deliveries: deliveries);
}

/// `GET /fleet/van_trips/{id}/figures` — the light poll.
class VanTripFigures {
  final String status;
  final double cashSalesTotal;
  final int salesCount;
  final List<VanTripLine> lines;

  const VanTripFigures({
    required this.status,
    this.cashSalesTotal = 0,
    this.salesCount = 0,
    this.lines = const [],
  });

  factory VanTripFigures.fromJson(Map<String, dynamic> j) => VanTripFigures(
    status: asStr(j['status']),
    cashSalesTotal: asNum(j['cash_sales_total']),
    salesCount: asInt(j['sales_count']),
    lines: asList(j['lines'], VanTripLine.fromJson),
  );
}

/// `GET /fleet/van_trips` — not a Laravel paginator: `{trips, counts,
/// cash_on_road, pagination}`.
class VanTripList {
  final Paged<VanTrip> page;
  final Map<String, int> counts;

  /// Cash from walk-in sales on trips still out.
  final double cashOnRoad;

  const VanTripList({required this.page, this.counts = const {}, this.cashOnRoad = 0});

  factory VanTripList.fromJson(Map<String, dynamic> j) {
    final p = asMap(j['pagination']);
    final counts = <String, int>{};
    asMap(j['counts']).forEach((k, v) => counts[k] = asInt(v));
    final trips = asList(j['trips'], VanTrip.fromJson);
    return VanTripList(
      page: Paged(
        items: trips,
        currentPage: p.isEmpty ? 1 : asInt(p['current_page']),
        lastPage: p.isEmpty ? 1 : asInt(p['last_page']),
        perPage: p.isEmpty ? trips.length : asInt(p['per_page']),
        total: p.isEmpty ? trips.length : asInt(p['total']),
      ),
      counts: counts,
      cashOnRoad: asNum(j['cash_on_road']),
    );
  }
}

/// `GET /fleet/van_trips/form_options`. Drivers and vehicles already on an
/// open trip are left out by the server.
class VanFormOptions {
  final List<VanDriverOption> drivers;
  final List<VanVehicleOption> vehicles;
  final List<VanWarehouse> warehouses;

  const VanFormOptions({
    this.drivers = const [],
    this.vehicles = const [],
    this.warehouses = const [],
  });

  factory VanFormOptions.fromJson(Map<String, dynamic> j) => VanFormOptions(
    drivers: asList(j['drivers'], VanDriverOption.fromJson),
    vehicles: asList(j['vehicles'], VanVehicleOption.fromJson),
    warehouses: asList(j['warehouses'], VanWarehouse.fromJson),
  );
}

class VanDriverOption {
  final int id;
  final String name;
  final String phone;
  final int? defaultVehicleId;

  const VanDriverOption({
    required this.id,
    required this.name,
    this.phone = '',
    this.defaultVehicleId,
  });

  factory VanDriverOption.fromJson(Map<String, dynamic> j) => VanDriverOption(
    id: asInt(j['id']),
    name: asStr(j['name']),
    phone: asStr(j['phone']),
    defaultVehicleId: asIntOrNull(j['default_vehicle_id']),
  );
}

class VanVehicleOption {
  final int id;
  final String plateNumber;
  final String vehicleType;
  final String status;

  const VanVehicleOption({
    required this.id,
    required this.plateNumber,
    this.vehicleType = '',
    this.status = '',
  });

  factory VanVehicleOption.fromJson(Map<String, dynamic> j) => VanVehicleOption(
    id: asInt(j['id']),
    plateNumber: asStr(j['plate_number']),
    vehicleType: asStr(j['vehicle_type']),
    status: asStr(j['status']),
  );
}

class VanWarehouse {
  final NamedPlace place;
  final List<VanStockItem> stock;

  const VanWarehouse({required this.place, this.stock = const []});

  int get id => place.id;

  factory VanWarehouse.fromJson(Map<String, dynamic> j) =>
      VanWarehouse(place: NamedPlace.fromJson(j), stock: asList(j['stock'], VanStockItem.fromJson));
}

class VanStockItem {
  final int skuId;
  final String name;
  final String code;
  final String barcode;
  final double availableQty;

  const VanStockItem({
    required this.skuId,
    required this.name,
    this.code = '',
    this.barcode = '',
    this.availableQty = 0,
  });

  factory VanStockItem.fromJson(Map<String, dynamic> j) => VanStockItem(
    skuId: asInt(j['sku_id']),
    name: asStr(j['name']),
    code: asStr(j['code']),
    barcode: asStr(j['barcode']),
    availableQty: asNum(j['available_qty']),
  );
}

/// One line of a new load sheet.
class VanLoadLineInput {
  final int skuId;
  final double qty;

  /// Before VAT; omitted → the server's price.
  final double? unitPrice;

  const VanLoadLineInput({required this.skuId, required this.qty, this.unitPrice});

  Map<String, dynamic> toJson() => {'sku_id': skuId, 'qty': qty, 'unit_price': ?unitPrice};
}

/// One line of the warehouse count at reconciliation.
class VanReturnLineInput {
  final int skuId;
  final double returnedQty;
  final double damagedQty;

  const VanReturnLineInput({
    required this.skuId,
    required this.returnedQty,
    required this.damagedQty,
  });

  Map<String, dynamic> toJson() => {
    'sku_id': skuId,
    'returned_qty': returnedQty,
    'damaged_qty': damagedQty,
  };
}
