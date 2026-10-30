import '../../../core/network/coerce.dart';
import 'catalog.dart';

/// One orderable SKU on «أمر شراء جديد», as `/lookups/skus` returns it for a
/// supplier, relationship, payment term, contract and delivery branch:
/// the quantity rules, the stock that branch can be served from, and the
/// price that applies — `price_preview` / `inventory_preview`, live shape
/// (2026-10-11):
/// `{id, name, sku_code, product_id, product_name, min_order_qty,
/// order_step_qty, packaging_type, pack_quantity, inventory_preview:
/// {available_qty, …}, price_preview: {matched, source, price_list_name,
/// currency_code, unit_price, final_price, …}}`.
class OrderEntryItem {
  /// Quantity rules and validation (same codes the server answers with).
  final Sku sku;

  final String name;
  final String productName;
  final int? productId;

  final double? availableQty;
  final bool priceMatched;
  final double unitPrice;
  final double finalPrice;
  final String currencyCode;

  /// Where the price came from: `contract`, `relationship`, `supplier_tier`,
  /// `legacy_fallback`, … — the website's «From …» line.
  final String priceSource;
  final String priceListName;

  const OrderEntryItem({
    required this.sku,
    required this.name,
    required this.productName,
    required this.productId,
    required this.availableQty,
    required this.priceMatched,
    required this.unitPrice,
    required this.finalPrice,
    required this.currencyCode,
    required this.priceSource,
    required this.priceListName,
  });

  factory OrderEntryItem.fromJson(Map<String, dynamic> j) {
    final price = j['price_preview'] is Map
        ? asMap(j['price_preview'])
        : (j['pricing'] is Map ? asMap(j['pricing']) : const <String, dynamic>{});
    final stock = j['inventory_preview'] is Map
        ? asMap(j['inventory_preview'])
        : const <String, dynamic>{};
    final available = stock['available_qty'] ?? j['available_qty'];
    return OrderEntryItem(
      sku: Sku.fromJson(j),
      name: unwrap(j['name'] ?? j['label']),
      productName: unwrap(j['product_name']),
      productId: asIntOrNull(j['product_id']),
      availableQty: available == null ? null : asNum(available),
      priceMatched: asBool(price['matched']),
      unitPrice: asNum(price['unit_price']),
      finalPrice: asNum(price['final_price'] ?? price['unit_price']),
      currencyCode: asStr(price['currency_code']),
      priceSource: asStr(price['source']),
      priceListName: unwrap(price['price_list_name']),
    );
  }

  int get skuId => sku.id;

  /// The most that can be ordered: the stock the supplier has available.
  /// `null` when the server sent no stock figure — then nothing caps it.
  double? get maxQty {
    final available = availableQty;
    return available == null || available < 0 ? null : available;
  }

  /// A SKU with no price rule cannot be ordered — the server would refuse
  /// the line with `pricing_not_found_for_sku`.
  bool get orderable => priceMatched;

  String displayName(String locale) {
    final fromSku = sku.displayName(locale);
    return name.isNotEmpty ? name : fromSku;
  }
}
