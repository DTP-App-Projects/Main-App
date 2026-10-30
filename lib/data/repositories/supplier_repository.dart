import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/trade/catalog.dart';
import '../models/trade/pricing.dart';
import '../models/trade/supplier_summary.dart';

/// The supplier's write side: SKU rules, price lists, relationships and credit.
///
/// Everything here is **supplier-workspace only**. Reaching it from a
/// trader-mode organization is `403 organization_workspace_not_allowed`,
/// which is a navigation bug rather than a user-facing condition.
class SupplierRepository {
  final ApiClient _client;

  SupplierRepository(this._client);

  // ------------------------------------------------------------- SKU rules

  /// The settings that produce the trader's order rejections:
  /// `min_order_qty` → `qty_less_than_min_order_qty`,
  /// `order_step_qty` → `qty_not_matching_order_step`.
  Future<ApiResult<Sku>> updateSkuRules({
    required int productId,
    required int skuId,
    double? minOrderQty,
    double? orderStepQty,
    double? packQuantity,
    String? skuStatus,
    String? barcode,
    bool? barcodeRequired,
    List<int>? businessSectorIds,
    List<SkuTierInput>? tiers,
  }) =>
      _client.put<Sku>(
        ApiPaths.skuRules(productId, skuId),
        body: {
          'min_order_qty': ?minOrderQty,
          'order_step_qty': ?orderStepQty,
          'pack_quantity': ?packQuantity,
          'sku_status': ?skuStatus,
          'barcode': ?barcode,
          'barcode_required': ?barcodeRequired,
          'business_sector_ids': ?businessSectorIds,
          if (tiers != null) 'tiers': tiers.map((t) => t.toJson()).toList(),
        },
        parse: (body) => Sku.fromJson(asMap(asMap(body)['sku'])),
      );

  static const skuStatuses = ['active', 'suspended', 'blocked'];

  // ----------------------------------------------------------- price lists

  Future<ApiResult<Paged<PriceList>>> priceLists({int page = 1, int limit = 15}) =>
      _client.get<Paged<PriceList>>(
        ApiPaths.priceLists,
        query: PageParams.limit(page, size: limit),
        parse: (body) => Paged.fromJson(asMap(body), PriceList.fromJson),
      );

  /// Upsert. One of `name_ar` / `name_en` is required, and **`scope_id` is
  /// required for every scope except `default`**.
  Future<ApiResult<PriceList>> savePriceList({
    int? priceListId,
    required String scopeType,
    int? scopeId,
    String? nameAr,
    String? nameEn,
    String? currencyCode,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) =>
      _client.post<PriceList>(
        ApiPaths.priceLists,
        body: {
          'price_list_id': ?priceListId,
          'scope_type': scopeType,
          'scope_id': ?scopeId,
          'name_ar': ?nameAr,
          'name_en': ?nameEn,
          'currency_code': ?currencyCode,
          if (startDate != null) 'start_date': _day(startDate),
          if (endDate != null) 'end_date': _day(endDate),
          'status': ?status,
        },
        parse: (body) => PriceList.fromJson(asMap(asMap(body)['price_list'])),
      );

  /// `400 max_qty_must_be_greater_than_or_equal_min_qty` when the band is
  /// inverted; the form checks that first.
  Future<ApiResult<PriceItem>> savePriceItem({
    required int priceListId,
    required int skuId,
    required double minQty,
    required double unitPrice,
    double? maxQty,
    int? paymentTermId,
    String? discountType,
    double? discountValue,
    bool? taxIncluded,
  }) =>
      _client.post<PriceItem>(
        ApiPaths.priceItems,
        body: {
          'price_list_id': priceListId,
          'sku_id': skuId,
          'min_qty': minQty,
          'unit_price': unitPrice,
          'max_qty': ?maxQty,
          'payment_term_id': ?paymentTermId,
          'discount_type': ?discountType,
          'discount_value': ?discountValue,
          'tax_included': ?taxIncluded,
        },
        parse: (body) => PriceItem.fromJson(asMap(asMap(body)['price_item'])),
      );

  // --------------------------------------------------------- relationships

  Future<ApiResult<Paged<BusinessRelationship>>> relationships({
    int page = 1,
    String? status,
    int limit = 15,
  }) =>
      _client.get<Paged<BusinessRelationship>>(
        ApiPaths.relationships,
        query: {...PageParams.limit(page, size: limit), 'status': ?status},
        parse: (body) => Paged.fromJson(asMap(body), BusinessRelationship.fromJson),
      );

  Future<ApiResult<BusinessRelationship>> setRelationshipStatus({
    required int id,
    required String status,
    String? notes,
  }) =>
      _client.patch<BusinessRelationship>(
        ApiPaths.relationshipStatus(id),
        body: {'status': status, 'notes': ?notes},
        parse: (body) => BusinessRelationship.fromJson(asMap(asMap(body)['relationship'])),
      );

  /// The traders directory: who this supplier could trade with, and where
  /// each relationship stands. A lookup, so `{items}` rather than a page.
  Future<ApiResult<List<TraderSummary>>> traders({String? search, int limit = 50}) =>
      _client.get<List<TraderSummary>>(
        ApiPaths.lookupTraders,
        query: {'limit': limit, if (search != null && search.isNotEmpty) 'search': search},
        parse: (body) => asList(asMap(body)['items'], TraderSummary.fromJson),
      );

  static const relationshipStatuses = [
    'pending_review',
    'approved',
    'suspended',
    'blacklisted',
    'closed',
  ];

  // ----------------------------------------------------------------- credit

  Future<ApiResult<CreditSnapshot>> credit(int relationshipId) =>
      _client.get<CreditSnapshot>(
        ApiPaths.relationshipCredit(relationshipId),
        parse: (body) => CreditSnapshot.fromJson(asMap(body)),
      );

  /// **Supplier side only** — a trader gets
  /// `403 credit_profile_can_only_be_managed_by_supplier_side`.
  ///
  /// `auto_freeze_on_limit` / `auto_freeze_on_overdue` are what stop the
  /// trader's next order.
  Future<ApiResult<CreditProfile>> saveCredit({
    required int relationshipId,
    required String grade,
    required double creditLimit,
    String? currencyCode,
    int? maxDueDays,
    int? maxOverdueDays,
    double? upfrontRequiredPercent,
    bool? autoFreezeOnLimit,
    bool? autoFreezeOnOverdue,
    int? reviewCycleDays,
    String? status,
  }) =>
      _client.put<CreditProfile>(
        ApiPaths.relationshipCredit(relationshipId),
        body: {
          'grade': grade,
          'credit_limit': creditLimit,
          'currency_code': ?currencyCode,
          'max_due_days': ?maxDueDays,
          'max_overdue_days': ?maxOverdueDays,
          'upfront_required_percent': ?upfrontRequiredPercent,
          'auto_freeze_on_limit': ?autoFreezeOnLimit,
          'auto_freeze_on_overdue': ?autoFreezeOnOverdue,
          'review_cycle_days': ?reviewCycleDays,
          'status': ?status,
        },
        parse: (body) => CreditProfile.fromJson(asMap(asMap(body)['credit_profile'])),
      );

  static String _day(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// One quantity band in a SKU's inline tier table.
class SkuTierInput {
  final int? paymentTermId;
  final double minQty;
  final double? maxQty;
  final double finalPrice;

  const SkuTierInput({
    required this.minQty,
    required this.finalPrice,
    this.maxQty,
    this.paymentTermId,
  });

  Map<String, dynamic> toJson() => {
        'payment_term_id': ?paymentTermId,
        'min_qty': minQty,
        'max_qty': ?maxQty,
        'final_price': finalPrice,
      };
}

/// `GET /v2/relationships/{id}/credit` → `{relationship_id, credit_profile,
/// credit_exposure}`.
class CreditSnapshot {
  final int relationshipId;
  final CreditProfile? profile;
  final CreditExposure? exposure;

  const CreditSnapshot({
    required this.relationshipId,
    required this.profile,
    required this.exposure,
  });

  factory CreditSnapshot.fromJson(Map<String, dynamic> j) => CreditSnapshot(
        relationshipId: asInt(j['relationship_id']),
        profile: j['credit_profile'] is Map
            ? CreditProfile.fromJson(asMap(j['credit_profile']))
            : null,
        exposure: j['credit_exposure'] is Map
            ? CreditExposure.fromJson(asMap(j['credit_exposure']))
            : null,
      );
}
