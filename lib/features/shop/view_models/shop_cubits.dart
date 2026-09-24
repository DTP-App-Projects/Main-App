import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paged.dart';
import '../../../core/session/session_store.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/paged_cubit.dart';
import '../../../data/models/shop/cart.dart';
import '../../../data/models/shop/shop_product.dart';
import '../../../data/repositories/shop_repository.dart';

// ---------------------------------------------------------------------------
// Home and browsing
// ---------------------------------------------------------------------------

@immutable
class ShopHomeState {
  final bool loading;
  final ShopHome? home;
  final String? errorMessage;
  final bool offline;

  const ShopHomeState({
    this.loading = true,
    this.home,
    this.errorMessage,
    this.offline = false,
  });

  ShopHomeState copyWith({
    bool? loading,
    ShopHome? home,
    String? errorMessage,
    bool? offline,
    bool clearError = false,
  }) =>
      ShopHomeState(
        loading: loading ?? this.loading,
        home: home ?? this.home,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
      );
}

class ShopHomeCubit extends Cubit<ShopHomeState> {
  final ShopRepository _repo;

  ShopHomeCubit(this._repo) : super(const ShopHomeState());

  /// One call fills the whole landing page — sliders, categories and all
  /// three rails. No fan-out.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.home();
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, home: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }
}

/// Search, one of the three feeds, or a category's products — all the same
/// paginated shape.
class ProductListCubit extends PagedCubit<ShopProduct> {
  final ShopRepository _repo;

  /// Exactly one of these decides where the rows come from.
  final String? feedType;
  final int? categoryId;

  String search = '';

  ProductListCubit(this._repo, {this.feedType, this.categoryId});

  @override
  Future<ApiResult<Paged<ShopProduct>>> fetchPage(int page) {
    if (categoryId != null) return _repo.categoryProducts(categoryId!, page: page);
    if (feedType != null) return _repo.feed(feedType!, page: page);
    // `text` is required, so an empty search asks for nothing.
    if (search.isEmpty) return Future.value(const Ok(Paged<ShopProduct>.empty()));
    return _repo.search(search, page: page);
  }

  Future<void> setSearch(String value) => applyFilter(() => search = value.trim());

  /// Favourite state is cheap to flip and cheap to put back.
  Future<void> toggleFavorite(ShopProduct product) async {
    _replace(product.withFavorite(!product.isFavorite));

    final result = await _repo.toggleFavorite(product.id);
    if (result is Ok<void> || result is NoContent<void>) return;
    _replace(product);
    emit(state.copyWith(errorMessage: result.failureMessage));
  }

  void _replace(ShopProduct updated) => emit(state.copyWith(
        page: Paged(
          items: [
            for (final item in state.items) item.id == updated.id ? updated : item,
          ],
          currentPage: state.page.currentPage,
          lastPage: state.page.lastPage,
          perPage: state.page.perPage,
          total: state.page.total,
        ),
      ));
}

class FavoritesCubit extends PagedCubit<ShopProduct> {
  final ShopRepository _repo;

  FavoritesCubit(this._repo);

  @override
  Future<ApiResult<Paged<ShopProduct>>> fetchPage(int page) => _repo.favorites(page: page);

  /// Un-favouriting from this list removes the row, so the list is re-read
  /// rather than patched.
  Future<void> remove(ShopProduct product) async {
    final result = await _repo.toggleFavorite(product.id);
    if (result is Ok<void> || result is NoContent<void>) {
      await load();
      return;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
  }
}

@immutable
class CategoriesState {
  final bool loading;
  final List<NamedCategory> categories;

  /// The drill-down trail, so Back means "up one level".
  final List<NamedCategory> trail;

  final String? errorMessage;
  final bool offline;

  const CategoriesState({
    this.loading = true,
    this.categories = const [],
    this.trail = const [],
    this.errorMessage,
    this.offline = false,
  });

  CategoriesState copyWith({
    bool? loading,
    List<NamedCategory>? categories,
    List<NamedCategory>? trail,
    String? errorMessage,
    bool? offline,
    bool clearError = false,
  }) =>
      CategoriesState(
        loading: loading ?? this.loading,
        categories: categories ?? this.categories,
        trail: trail ?? this.trail,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
      );
}

/// Categories are three levels deep, and **only the deepest lists products**.
class CategoriesCubit extends Cubit<CategoriesState> {
  final ShopRepository _repo;

  CategoriesCubit(this._repo) : super(const CategoriesState());

  Future<void> load({int parent = 0}) async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.categories(parent: parent);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, categories: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<void> drillInto(NamedCategory category) async {
    emit(state.copyWith(trail: [...state.trail, category]));
    await load(parent: category.id);
  }

  /// Returns true when there was a level to go back to.
  Future<bool> goUp() async {
    if (state.trail.isEmpty) return false;
    final trail = [...state.trail]..removeLast();
    emit(state.copyWith(trail: trail));
    await load(parent: trail.isEmpty ? 0 : trail.last.id);
    return true;
  }
}

@immutable
class ProductDetailState {
  final bool loading;
  final ShopProductDetail? detail;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;
  final ProductVariation? variation;
  final int quantity;

  const ProductDetailState({
    this.loading = true,
    this.detail,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
    this.variation,
    this.quantity = 1,
  });

  ShopProduct? get product => detail?.product;

  ProductDetailState copyWith({
    bool? loading,
    ShopProductDetail? detail,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    ProductVariation? variation,
    int? quantity,
    bool clearError = false,
  }) =>
      ProductDetailState(
        loading: loading ?? this.loading,
        detail: detail ?? this.detail,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
        variation: variation ?? this.variation,
        quantity: quantity ?? this.quantity,
      );
}

/// One product.
///
/// Opening this screen **increments the product's view counter**, which is
/// why nothing prefetches it from a list.
class ProductDetailCubit extends Cubit<ProductDetailState> {
  final ShopRepository _repo;
  final int productId;

  ProductDetailCubit(this._repo, this.productId) : super(const ProductDetailState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.product(productId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(
        loading: false,
        detail: data,
        variation: data.product.variations.isEmpty ? null : data.product.variations.first,
      ));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  void setVariation(ProductVariation value) => emit(state.copyWith(variation: value));

  void setQuantity(int value) => emit(state.copyWith(quantity: value.clamp(1, 999)));

  Future<bool> addToCart() async {
    final product = state.product;
    if (product == null || state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.addToCart(
      productId: product.id,
      count: state.quantity,
      // A static product takes `0`; the field is required either way.
      productVariationId: product.variationIdFor(state.variation),
    );
    emit(state.copyWith(action: result.failureState));
    return result is Ok<Cart> || result is NoContent<Cart>;
  }

  Future<void> toggleFavorite() async {
    final detail = state.detail;
    if (detail == null) return;

    final flipped = ShopProductDetail(
      product: detail.product.withFavorite(!detail.product.isFavorite),
      seller: detail.seller,
      similars: detail.similars,
    );
    emit(state.copyWith(detail: flipped));

    final result = await _repo.toggleFavorite(detail.product.id);
    if (result is Ok<void> || result is NoContent<void>) return;
    emit(state.copyWith(detail: detail));
  }
}

// ---------------------------------------------------------------------------
// Cart and checkout
// ---------------------------------------------------------------------------

@immutable
class CartState {
  final bool loading;
  final Cart cart;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;
  final int? addressId;

  /// Set once checkout has run — whatever its outcome, the orders list is
  /// the only truthful record of what was created.
  final bool checkedOut;

  const CartState({
    this.loading = true,
    this.cart = Cart.empty,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
    this.addressId,
    this.checkedOut = false,
  });

  CartState copyWith({
    bool? loading,
    Cart? cart,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    int? addressId,
    bool? checkedOut,
    bool clearError = false,
  }) =>
      CartState(
        loading: loading ?? this.loading,
        cart: cart ?? this.cart,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
        addressId: addressId ?? this.addressId,
        checkedOut: checkedOut ?? this.checkedOut,
      );
}

class CartCubit extends Cubit<CartState> {
  final ShopRepository _repo;

  CartCubit(this._repo) : super(const CartState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.cart();
    if (result case Ok(:final data)) {
      emit(state.copyWith(
        loading: false,
        cart: data,
        addressId: state.addressId ??
            (data.addresses.isEmpty ? null : data.addresses.first.id),
      ));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  void setAddress(int id) => emit(state.copyWith(addressId: id));

  Future<void> removeLine(int cartId) async {
    final result = await _repo.removeCartLine(cartId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(cart: data));
      return;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
  }

  /// **Checkout is never retried automatically.**
  ///
  /// It splits the cart by seller, creates one order each, and empties the
  /// cart. A mid-loop stock failure answers `401` *after* some orders may
  /// already exist — so whatever comes back, the caller is sent to the orders
  /// list to see what is actually there.
  Future<bool> checkout() async {
    final addressId = state.addressId;
    if (addressId == null || state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.checkout(addressId: addressId);
    final succeeded = result is Ok<CheckoutResult> || result is NoContent<CheckoutResult>;

    emit(state.copyWith(
      // Set either way: orders may exist even on the failure path.
      checkedOut: true,
      action: succeeded
          ? const SubmitState(status: FormStatus.success)
          : result.failureState,
    ));
    return succeeded;
  }
}

class ShopOrdersCubit extends PagedCubit<ShopOrder> {
  final ShopRepository _repo;

  /// Required by the endpoint; `all` is how you ask for everything.
  String status = 'all';

  ShopOrdersCubit(this._repo);

  @override
  Future<ApiResult<Paged<ShopOrder>>> fetchPage(int page) =>
      _repo.orders(status: status, page: page);

  Future<void> setStatus(String value) => applyFilter(() => status = value);
}

@immutable
class ShopOrderDetailState {
  final bool loading;
  final ShopOrder? order;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const ShopOrderDetailState({
    this.loading = true,
    this.order,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  ShopOrderDetailState copyWith({
    bool? loading,
    ShopOrder? order,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      ShopOrderDetailState(
        loading: loading ?? this.loading,
        order: order ?? this.order,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

class ShopOrderDetailCubit extends Cubit<ShopOrderDetailState> {
  final ShopRepository _repo;
  final int orderId;

  ShopOrderDetailCubit(this._repo, this.orderId) : super(const ShopOrderDetailState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.order(orderId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, order: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  /// A direct multipart upload — v1 takes the file itself, not a path.
  Future<bool> uploadReceipt(String filePath) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.uploadReceipt(orderId: orderId, filePath: filePath);
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: result.failureState));
    if (ok) await load();
    return ok;
  }

  /// Seller-only; the route checks the caller owns the order.
  Future<bool> setStatus(String status) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.setOrderStatus(orderId: orderId, status: status);
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: result.failureState));
    if (ok) await load();
    return ok;
  }
}

// ---------------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------------

@immutable
class ChatListState {
  final bool loading;
  final List<ChatThread> threads;
  final String? errorMessage;
  final bool offline;

  const ChatListState({
    this.loading = true,
    this.threads = const [],
    this.errorMessage,
    this.offline = false,
  });

  ChatListState copyWith({
    bool? loading,
    List<ChatThread>? threads,
    String? errorMessage,
    bool? offline,
    bool clearError = false,
  }) =>
      ChatListState(
        loading: loading ?? this.loading,
        threads: threads ?? this.threads,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
      );
}

class ChatListCubit extends Cubit<ChatListState> {
  final ShopRepository _repo;

  ChatListCubit(this._repo) : super(const ChatListState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.chatThreads();
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, threads: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }
}

@immutable
class ChatRoomState {
  final bool loading;
  final List<ChatMessage> messages;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const ChatRoomState({
    this.loading = true,
    this.messages = const [],
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  ChatRoomState copyWith({
    bool? loading,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      ChatRoomState(
        loading: loading ?? this.loading,
        messages: messages ?? this.messages,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

/// One conversation.
///
/// Live delivery would be a Laravel broadcast; until the broadcaster
/// credentials are settled this refreshes on open, on send, and on a `chat`
/// push — no socket, and no polling loop burning the request budget.
class ChatRoomCubit extends Cubit<ChatRoomState> {
  final ShopRepository _repo;
  final SessionStore _session;
  final int withId;

  ChatRoomCubit(this._repo, this._session, this.withId) : super(const ChatRoomState());

  int? get myUserId => _session.userId;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.messages(withId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, messages: data.items));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  /// **`sender_id` has to be sent explicitly here** — this is the one v1 call
  /// where the middleware does not fill it in.
  Future<bool> send(String text) async {
    final senderId = _session.userId;
    final trimmed = text.trim();
    if (senderId == null || trimmed.isEmpty || state.action.isSubmitting) return false;

    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.sendMessage(
      senderId: senderId,
      targetId: withId,
      text: trimmed,
    );
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: ok ? const SubmitState() : result.failureState));
    if (ok) await load();
    return ok;
  }
}
