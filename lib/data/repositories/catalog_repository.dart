import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/trade/catalog.dart';
import '../models/trade/purchase_order.dart';
import '../models/trade/supplier_summary.dart';

/// Discovery and browsing: suppliers, the relationship that unlocks ordering,
/// products, SKUs, and the price that actually applies.
class CatalogRepository {
  final ApiClient _client;

  CatalogRepository(this._client);

  // --------------------------------------------------------------- suppliers

  Future<ApiResult<Paged<SupplierSummary>>> suppliers({
    int page = 1,
    String? search,
    String? status,
    int limit = 15,
  }) =>
      _client.get<Paged<SupplierSummary>>(
        ApiPaths.catalogSuppliers,
        query: {
          ...PageParams.limit(page, size: limit),
          'search': ?search,
          'status': ?status,
        },
        parse: (body) => Paged.fromJson(asMap(body), SupplierSummary.fromJson),
      );

  Future<ApiResult<SupplierSummary>> supplier(int supplierOrganizationId) =>
      _client.get<SupplierSummary>(
        ApiPaths.catalogSupplier(supplierOrganizationId),
        parse: (body) => SupplierSummary.fromJson(asMap(asMap(body)['supplier'])),
      );

  /// Browsable **before** a relationship exists — this is what a trader sees
  /// on a supplier they have not been approved by yet.
  Future<ApiResult<List<Product>>> publicCatalog(
    int supplierOrganizationId, {
    String? search,
    int limit = 20,
  }) =>
      _client.get<List<Product>>(
        ApiPaths.publicCatalog(supplierOrganizationId),
        query: {'limit': limit.clamp(1, 50), 'search': ?search},
        parse: (body) => asList(asMap(body)['items'], Product.fromJson),
      );

  /// Toggling is two verbs on one path, so the caller says which.
  Future<ApiResult<bool>> setFollowing(int supplierOrganizationId, bool follow) {
    final path = ApiPaths.followSupplier(supplierOrganizationId);
    bool parse(dynamic body) => asBool(asMap(body)['is_following']);
    return follow
        ? _client.post<bool>(path, parse: parse)
        : _client.delete<bool>(path, parse: parse);
  }

  Future<ApiResult<bool>> isFollowing(int supplierOrganizationId) => _client.get<bool>(
        ApiPaths.followSupplier(supplierOrganizationId),
        parse: (body) => asBool(asMap(body)['is_following']),
      );

  // ----------------------------------------------------------- relationships

  /// Asks the supplier for a trading relationship. `as: trader` because this
  /// is the buying side requesting it.
  ///
  /// Quota-gated, and a blacklisted counterparty is refused outright.
  Future<ApiResult<BusinessRelationship>> requestRelationship({
    required int supplierOrganizationId,
    String? notes,
  }) =>
      _client.post<BusinessRelationship>(
        ApiPaths.relationships,
        body: {
          'counterparty_organization_id': supplierOrganizationId,
          'as': 'trader',
          'notes': ?notes,
        },
        parse: (body) => BusinessRelationship.fromJson(asMap(asMap(body)['relationship'])),
      );

  Future<ApiResult<BusinessRelationship>> relationship(int id) =>
      _client.get<BusinessRelationship>(
        ApiPaths.relationship(id),
        parse: (body) => BusinessRelationship.fromJson(asMap(asMap(body)['relationship'])),
      );

  // ---------------------------------------------------------------- products

  Future<ApiResult<Paged<Product>>> products({
    int page = 1,
    String? search,
    int? categoryId,
    int? paymentTermId,
    String? status,
    int limit = 15,
  }) =>
      _client.get<Paged<Product>>(
        ApiPaths.catalogProducts,
        query: {
          ...PageParams.limit(page, size: limit),
          'search': ?search,
          'category_id': ?categoryId,
          'payment_term_id': ?paymentTermId,
          'status': ?status,
        },
        parse: (body) => Paged.fromJson(asMap(body), Product.fromJson),
      );

  /// The detail carries `skus[]`, which is what the order-entry screen needs.
  Future<ApiResult<Product>> product(int productId) => _client.get<Product>(
        ApiPaths.catalogProduct(productId),
        parse: (body) => Product.fromJson(asMap(asMap(body)['product'])),
      );

  // ----------------------------------------------------------------- pricing

  /// **Called before every add to a draft.** A SKU whose `pricing.matched` is
  /// false has no applicable rule and cannot be ordered — finding that out
  /// here costs a round trip, finding it out on submit costs the user a line.
  Future<ApiResult<PriceResolution>> resolvePrice({
    required int skuId,
    double? qty,
    int? paymentTermId,
    int? relationshipId,
  }) =>
      _client.get<PriceResolution>(
        ApiPaths.pricingResolve,
        query: {
          'sku_id': skuId,
          'qty': ?qty,
          'payment_term_id': ?paymentTermId,
          'relationship_id': ?relationshipId,
        },
        parse: (body) => PriceResolution.fromJson(asMap(body)),
      );

  Future<ApiResult<List<PaymentTerm>>> paymentTerms() => _client.get<List<PaymentTerm>>(
        ApiPaths.paymentTerms,
        parse: (body) => asList(asMap(body)['payment_terms'], PaymentTerm.fromJson),
      );
}
