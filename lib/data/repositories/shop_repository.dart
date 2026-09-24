import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/shop/cart.dart';
import '../models/shop/shop_product.dart';

/// The v1 marketplace.
///
/// This surface predates v2 and behaves differently: no `formatted` wrapper,
/// several required query params, direct multipart uploads, and a `401` that
/// means "business rule rejected" rather than "not signed in".
class ShopRepository {
  final ApiClient _client;

  ShopRepository(this._client);

  // ------------------------------------------------------------------ browse

  Future<ApiResult<ShopHome>> home() => _client.get<ShopHome>(
        ApiPaths.shopHome,
        parse: (body) => ShopHome.fromJson(asMap(body)),
      );

  /// `text` is required. The backend detects Arabic or Latin from the query
  /// and matches `ar_name` or `en_name` accordingly.
  Future<ApiResult<Paged<ShopProduct>>> search(String text, {int page = 1}) =>
      _client.get<Paged<ShopProduct>>(
        ApiPaths.shopSearch,
        query: {'text': text, 'page': page},
        parse: (body) =>
            Paged.fromJson(asMap(body), ShopProduct.fromJson, formattedKey: false),
      );

  /// `parent` is required and numeric — **`0` is the top level**, not "all".
  Future<ApiResult<List<NamedCategory>>> categories({int parent = 0}) =>
      _client.get<List<NamedCategory>>(
        ApiPaths.shopCategories,
        query: {'parent': parent},
        parse: (body) => asList(body, NamedCategory.fromJson),
      );

  /// Only a third-level (`type=sec`) category lists products; the category
  /// screen drills down until it reaches one.
  Future<ApiResult<Paged<ShopProduct>>> categoryProducts(int categoryId, {int page = 1}) =>
      _client.get<Paged<ShopProduct>>(
        ApiPaths.shopCategoryProducts(categoryId),
        query: {'page': page},
        parse: (body) =>
            Paged.fromJson(asMap(body), ShopProduct.fromJson, formattedKey: false),
      );

  /// `type` is required: `best_selling`, `most_viewed` or `discount`.
  Future<ApiResult<Paged<ShopProduct>>> feed(String type, {int page = 1}) =>
      _client.get<Paged<ShopProduct>>(
        ApiPaths.shopProducts,
        query: {'type': type, 'page': page},
        parse: (body) =>
            Paged.fromJson(asMap(body), ShopProduct.fromJson, formattedKey: false),
      );

  /// ⚠️ **This increments the product's view counter.** It is called when a
  /// user opens a product, never to fill in a list.
  Future<ApiResult<ShopProductDetail>> product(int productId) =>
      _client.get<ShopProductDetail>(
        ApiPaths.shopProduct(productId),
        // A view is a side effect; collapsing two of them would be wrong in
        // the other direction, but a re-open should count again.
        dedupe: false,
        parse: (body) => ShopProductDetail.fromJson(asMap(body)),
      );

  // -------------------------------------------------------------- favourites

  Future<ApiResult<Paged<ShopProduct>>> favorites({int page = 1}) =>
      _client.get<Paged<ShopProduct>>(
        ApiPaths.shopFavorites,
        query: {'page': page},
        parse: (body) =>
            Paged.fromJson(asMap(body), ShopProduct.fromJson, formattedKey: false),
      );

  /// A single toggle: adds if absent, removes if present, answers `204`.
  /// The caller flips local state optimistically.
  Future<ApiResult<void>> toggleFavorite(int productId) =>
      _client.post<void>(ApiPaths.shopFavoriteToggle(productId));

  // -------------------------------------------------------------------- cart

  /// **Buyers only.** A seller account gets `400 validation_error`, which is
  /// a permission problem wearing a validation costume.
  Future<ApiResult<Cart>> cart() => _client.get<Cart>(
        ApiPaths.shopCart,
        parse: (body) => Cart.fromJson(asMap(body)),
      );

  /// `product_variation_id` is **`0` for a static product** — the field is
  /// numeric-required, not nullable.
  ///
  /// `401 insufficient_product_count` and `401 product_not_same_country_as_user`
  /// are both business rules, not auth failures.
  Future<ApiResult<Cart>> addToCart({
    required int productId,
    required int count,
    int productVariationId = 0,
  }) =>
      _client.post<Cart>(
        ApiPaths.shopCart,
        body: {
          'product_id': productId,
          'product_variation_id': productVariationId,
          'count': count,
        },
        parse: (body) => Cart.fromJson(asMap(body)),
      );

  Future<ApiResult<Cart>> removeCartLine(int cartId) => _client.delete<Cart>(
        ApiPaths.shopCartLine(cartId),
        parse: (body) => Cart.fromJson(asMap(body)),
      );

  /// ⚠️ **Never auto-retry this.**
  ///
  /// Checkout splits the cart by seller, creates one order per seller,
  /// decrements stock and empties the cart. If it runs out of stock partway
  /// it answers `401 insufficient_product_count` — *after* some orders may
  /// already exist. Whatever the outcome, the caller re-reads the orders list
  /// rather than assuming nothing happened.
  Future<ApiResult<CheckoutResult>> checkout({required int addressId}) =>
      _client.post<CheckoutResult>(
        ApiPaths.shopCheckout,
        body: {'address_id': addressId},
        parse: (body) => CheckoutResult.fromJson(asMap(body)),
      );

  // ------------------------------------------------------------------ orders

  /// `status` is **required**; `all` is how you ask for everything.
  ///
  /// The endpoint works out which side the caller is on from `users.type`,
  /// and `merchant` on each row is the other party.
  Future<ApiResult<Paged<ShopOrder>>> orders({
    String status = 'all',
    int page = 1,
  }) =>
      _client.get<Paged<ShopOrder>>(
        ApiPaths.shopOrders,
        query: {'status': status, 'page': page},
        // After a checkout this must not return a cached answer.
        dedupe: false,
        parse: (body) =>
            Paged.fromJson(asMap(body), ShopOrder.fromJson, formattedKey: false),
      );

  /// `401 user_not_allowed` when the caller is neither the buyer nor seller.
  Future<ApiResult<ShopOrder>> order(int orderId) => _client.get<ShopOrder>(
        ApiPaths.shopOrder(orderId),
        // The detail is a bare object, not wrapped under a key.
        parse: (body) => ShopOrder.fromJson(asMap(body)),
      );

  /// A **direct multipart** upload — v1 does not use the two-step pattern.
  Future<ApiResult<void>> uploadReceipt({
    required int orderId,
    required String filePath,
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    return _client.multipart<void>(
      ApiPaths.shopOrderReceipt(orderId),
      form: form,
      onSendProgress: onProgress,
    );
  }

  /// Seller-only: the route checks `orders.seller_id == caller`.
  Future<ApiResult<void>> setOrderStatus({
    required int orderId,
    required String status,
  }) =>
      _client.patch<void>(ApiPaths.shopOrderStatus(orderId), body: {'status': status});

  // -------------------------------------------------------------------- chat

  /// A plain array, not a paginator.
  Future<ApiResult<List<ChatThread>>> chatThreads() => _client.get<List<ChatThread>>(
        ApiPaths.shopChat,
        parse: (body) => asList(body, ChatThread.fromJson),
      );

  /// Newest first, 20 a page. Fetching also marks them read.
  Future<ApiResult<Paged<ChatMessage>>> messages(int withId, {int page = 1}) =>
      _client.get<Paged<ChatMessage>>(
        ApiPaths.shopChatWith(withId),
        query: {'page': page},
        dedupe: false,
        parse: (body) =>
            Paged.fromJson(asMap(body), ChatMessage.fromJson, formattedKey: false),
      );

  /// ⚠️ **`sender_id` is required and is not auto-filled** — unlike every
  /// other v1 call, the middleware does not supply it here.
  Future<ApiResult<void>> sendMessage({
    required int senderId,
    required int targetId,
    required String text,
  }) =>
      _client.post<void>(
        ApiPaths.shopChat,
        body: {'sender_id': senderId, 'target_id': targetId, 'text': text},
      );
}
