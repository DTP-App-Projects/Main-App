import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../data/models/trade/catalog.dart';
import '../../../../data/repositories/catalog_repository.dart';

class ProductsCubit extends PagedCubit<Product> {
  final CatalogRepository _repo;

  String search = '';

  ProductsCubit(this._repo);

  @override
  Future<ApiResult<Paged<Product>>> fetchPage(int page) =>
      _repo.products(page: page, search: search.isEmpty ? null : search);

  Future<void> setSearch(String value) => applyFilter(() => search = value.trim());
}

@immutable
class ProductDetailState {
  final bool loading;
  final Product? product;
  final String? errorMessage;
  final bool offline;

  /// Resolved prices, keyed by SKU id. Filled lazily: one call per SKU the
  /// user actually looks at, not one per SKU in the list.
  final Map<int, PriceResolution> prices;

  /// SKU ids with a resolve request in flight.
  final Set<int> resolving;

  const ProductDetailState({
    this.loading = true,
    this.product,
    this.errorMessage,
    this.offline = false,
    this.prices = const {},
    this.resolving = const {},
  });

  ProductDetailState copyWith({
    bool? loading,
    Product? product,
    String? errorMessage,
    bool? offline,
    Map<int, PriceResolution>? prices,
    Set<int>? resolving,
    bool clearError = false,
  }) =>
      ProductDetailState(
        loading: loading ?? this.loading,
        product: product ?? this.product,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        prices: prices ?? this.prices,
        resolving: resolving ?? this.resolving,
      );
}

/// The product page is **read-only for a trader** — SKU rules belong to the
/// supplier. What the trader gets here is the price that actually applies to
/// them, which only `/pricing/resolve` can answer.
class ProductDetailCubit extends Cubit<ProductDetailState> {
  final CatalogRepository _repo;
  final int productId;
  final int? relationshipId;

  ProductDetailCubit(this._repo, this.productId, {this.relationshipId})
      : super(const ProductDetailState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.product(productId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, product: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  /// One resolve per SKU, cached. A list of twenty SKUs must not become
  /// twenty requests on open — the cap is 60 a minute for the whole app.
  Future<void> resolvePrice(Sku sku) async {
    if (state.prices.containsKey(sku.id) || state.resolving.contains(sku.id)) return;
    emit(state.copyWith(resolving: {...state.resolving, sku.id}));

    final result = await _repo.resolvePrice(
      skuId: sku.id,
      qty: sku.minOrderQty > 0 ? sku.minOrderQty : 1,
      relationshipId: relationshipId,
    );

    final resolving = {...state.resolving}..remove(sku.id);
    if (result case Ok(:final data)) {
      emit(state.copyWith(prices: {...state.prices, sku.id: data}, resolving: resolving));
      return;
    }
    emit(state.copyWith(resolving: resolving, errorMessage: result.failureMessage));
  }
}
