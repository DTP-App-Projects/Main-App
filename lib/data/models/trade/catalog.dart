import '../../../core/network/coerce.dart';
import 'supplier_summary.dart';

/// A catalogue product. The trader reads these; only the supplier writes them.
class Product {
  final int id;
  final int organizationId;
  final String name;
  final String nameAr;
  final String nameEn;
  final String type;
  final String status;

  /// Already an absolute URL — do not prepend the base.
  final String image;
  final String thumbImage;

  final double discount;
  final bool isNegotiated;
  final NamedRef? supplier;
  final int? relationshipId;
  final String relationshipStatus;
  final List<NamedRef> categories;
  final int skusCount;
  final Sku? primarySku;

  /// Present on `show`.
  final List<Sku> skus;

  const Product({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    required this.status,
    required this.image,
    required this.thumbImage,
    required this.discount,
    required this.isNegotiated,
    required this.supplier,
    required this.relationshipId,
    required this.relationshipStatus,
    required this.categories,
    required this.skusCount,
    required this.primarySku,
    required this.skus,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: asInt(j['id']),
        organizationId: asInt(j['organization_id']),
        name: unwrap(j['name']),
        nameAr: unwrap(j['ar_name']),
        nameEn: unwrap(j['en_name']),
        type: asStr(j['type']),
        status: asStr(j['status']),
        image: asStr(j['image']),
        thumbImage: asStr(j['thumb_image']),
        discount: asNum(j['discount']),
        isNegotiated: asBool(j['is_negotiated']),
        supplier: j['supplier'] is Map ? NamedRef.fromJson(asMap(j['supplier'])) : null,
        relationshipId: asIntOrNull(j['relationship_id']),
        relationshipStatus: asStr(j['relationship_status']),
        categories: asList(j['categories'], NamedRef.fromJson),
        skusCount: asInt(j['skus_count']),
        primarySku: j['primary_sku'] is Map ? Sku.fromJson(asMap(j['primary_sku'])) : null,
        skus: asList(j['skus'], Sku.fromJson),
      );

  String displayName(String locale) {
    final localized = pickLocalized(locale: locale, ar: nameAr, en: nameEn);
    return localized.isNotEmpty ? localized : name;
  }
}

/// A sellable unit. Its **rules are what produce the trader's order
/// rejections** — minimum quantity, order step, pack size.
class Sku {
  final int id;
  final String skuCode;
  final String name;
  final String displayNameAr;
  final String displayNameEn;
  final String packagingType;
  final String unitLabelAr;
  final String unitLabelEn;

  final double packQuantity;
  final double minOrderQty;
  final double orderStepQty;

  /// All-digit barcodes lose their leading zeros as numbers, so this is text.
  final String barcode;
  final bool barcodeRequired;

  final String status;
  final bool trackInventory;
  final double availableQty;
  final SkuPricing? pricing;

  const Sku({
    required this.id,
    required this.skuCode,
    required this.name,
    required this.displayNameAr,
    required this.displayNameEn,
    required this.packagingType,
    required this.unitLabelAr,
    required this.unitLabelEn,
    required this.packQuantity,
    required this.minOrderQty,
    required this.orderStepQty,
    required this.barcode,
    required this.barcodeRequired,
    required this.status,
    required this.trackInventory,
    required this.availableQty,
    required this.pricing,
  });

  factory Sku.fromJson(Map<String, dynamic> j) => Sku(
        id: asInt(j['id']),
        skuCode: asStr(j['sku_code']),
        name: unwrap(j['name']),
        displayNameAr: unwrap(j['display_name_ar']),
        displayNameEn: unwrap(j['display_name_en']),
        packagingType: asStr(j['packaging_type']),
        unitLabelAr: unwrap(j['unit_label_ar']),
        unitLabelEn: unwrap(j['unit_label_en']),
        packQuantity: asNum(j['pack_quantity']),
        minOrderQty: asNum(j['min_order_qty']),
        orderStepQty: asNum(j['order_step_qty']),
        barcode: asStr(j['barcode']),
        barcodeRequired: asBool(j['barcode_required']),
        status: asStr(j['status']),
        trackInventory: asBool(j['track_inventory']),
        availableQty: asNum(j['available_qty']),
        pricing: j['pricing'] is Map ? SkuPricing.fromJson(asMap(j['pricing'])) : null,
      );

  String displayName(String locale) {
    final localized = pickLocalized(locale: locale, ar: displayNameAr, en: displayNameEn);
    if (localized.isNotEmpty) return localized;
    return name.isNotEmpty ? name : skuCode;
  }

  String unitLabel(String locale) =>
      pickLocalized(locale: locale, ar: unitLabelAr, en: unitLabelEn);

  bool get isActive => status == 'active';

  /// The same three rules the server enforces, checked locally so a rejection
  /// is explained before the round trip rather than after it.
  ///
  /// Returns the server's own error code, so the message is identical either
  /// way; `null` when the quantity is acceptable.
  String? validateQty(double qty) {
    if (qty <= 0) return 'qty_less_than_min_order_qty';
    if (minOrderQty > 0 && qty < minOrderQty) return 'qty_less_than_min_order_qty';
    if (orderStepQty > 0) {
      final steps = qty / orderStepQty;
      if ((steps - steps.roundToDouble()).abs() > 1e-6) return 'qty_not_matching_order_step';
    }
    if (trackInventory && availableQty > 0 && qty > availableQty) {
      return 'insufficient_supplier_inventory';
    }
    return null;
  }

  /// The next quantity at or above [qty] that satisfies the step rule.
  double snapQty(double qty) {
    final floor = minOrderQty > 0 ? minOrderQty : 0.0;
    var value = qty < floor ? floor : qty;
    if (orderStepQty > 0) {
      final steps = (value / orderStepQty).ceil();
      value = steps * orderStepQty;
    }
    return value;
  }
}

/// The price block embedded in a SKU row, as `/lookups/skus` returns it.
class SkuPricing {
  final bool matched;
  final String currencyCode;
  final double unitPrice;
  final double finalPrice;
  final int? paymentTermId;

  const SkuPricing({
    required this.matched,
    required this.currencyCode,
    required this.unitPrice,
    required this.finalPrice,
    required this.paymentTermId,
  });

  factory SkuPricing.fromJson(Map<String, dynamic> j) => SkuPricing(
        matched: asBool(j['matched']),
        currencyCode: asStr(j['currency_code']),
        unitPrice: asNum(j['unit_price']),
        finalPrice: asNum(j['final_price']),
        paymentTermId: asIntOrNull(j['payment_term_id']),
      );
}

/// `GET /v2/pricing/resolve?sku_id=&qty=&payment_term_id=&relationship_id=`
///
/// Called **before every add to a draft**: a SKU with no matching price rule
/// cannot be ordered, and finding that out server-side costs the user a line.
class PriceResolution {
  final int skuId;
  final int? relationshipId;
  final double availableQty;

  final bool matched;
  final String source;
  final String scopeType;
  final String currencyCode;
  final double unitPrice;
  final double finalPrice;
  final double unitDiscount;
  final String discountType;
  final double discountValue;
  final bool taxIncluded;
  final double lineSubtotal;
  final int? paymentTermId;
  final String priceListName;

  const PriceResolution({
    required this.skuId,
    required this.relationshipId,
    required this.availableQty,
    required this.matched,
    required this.source,
    required this.scopeType,
    required this.currencyCode,
    required this.unitPrice,
    required this.finalPrice,
    required this.unitDiscount,
    required this.discountType,
    required this.discountValue,
    required this.taxIncluded,
    required this.lineSubtotal,
    required this.paymentTermId,
    required this.priceListName,
  });

  factory PriceResolution.fromJson(Map<String, dynamic> j) {
    final pricing = asMap(j['pricing']);
    return PriceResolution(
      skuId: asInt(j['sku_id']),
      relationshipId: asIntOrNull(j['relationship_id']),
      availableQty: asNum(j['available_qty']),
      matched: asBool(pricing['matched']),
      source: asStr(pricing['source']),
      scopeType: asStr(pricing['scope_type']),
      currencyCode: asStr(pricing['currency_code']),
      unitPrice: asNum(pricing['unit_price']),
      finalPrice: asNum(pricing['final_price']),
      unitDiscount: asNum(pricing['unit_discount']),
      discountType: asStr(pricing['discount_type']),
      discountValue: asNum(pricing['discount_value']),
      taxIncluded: asBool(pricing['tax_included']),
      lineSubtotal: asNum(pricing['line_subtotal']),
      paymentTermId: asIntOrNull(pricing['payment_term_id']),
      priceListName: unwrap(pricing['price_list_name']),
    );
  }

  /// `matched == false` (source `legacy_fallback`) means no price rule
  /// applies — the add must be blocked, not attempted.
  bool get canOrder => matched;

  bool get hasDiscount => unitDiscount > 0;
}
