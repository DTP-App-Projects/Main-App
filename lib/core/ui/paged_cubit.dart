import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../error/api_failure_ui.dart';
import '../network/api_result.dart';
import '../network/paged.dart';

@immutable
class PagedState<T> {
  final bool loading;
  final bool loadingMore;
  final Paged<T> page;

  /// Localized; `null` when the last load succeeded.
  final String? errorMessage;

  /// Offline is its own state — a different message and a retry that might
  /// actually work.
  final bool offline;

  const PagedState({
    this.loading = true,
    this.page = const Paged.empty(),
    this.loadingMore = false,
    this.errorMessage,
    this.offline = false,
  });

  List<T> get items => page.items;
  bool get hasMore => page.hasMore;
  bool get isEmpty => !loading && items.isEmpty && errorMessage == null;
  bool get failedOutright => errorMessage != null && items.isEmpty;

  PagedState<T> copyWith({
    bool? loading,
    bool? loadingMore,
    Paged<T>? page,
    String? errorMessage,
    bool? offline,
    bool clearError = false,
  }) =>
      PagedState<T>(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page ?? this.page,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
      );
}

/// Every paginated list in the trader and supplier tracks behaves the same:
/// first page, infinite scroll, pull to refresh, and a failed page two that
/// leaves page one on screen.
abstract class PagedCubit<T> extends Cubit<PagedState<T>> {
  PagedCubit() : super(PagedState<T>());

  Future<ApiResult<Paged<T>>> fetchPage(int page);

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await fetchPage(1);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, page: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<void> refresh() => load();

  /// Guarded so a fast scroller cannot queue three pages — the global budget
  /// is 60 requests a minute for the whole app.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));

    final result = await fetchPage(state.page.currentPage + 1);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loadingMore: false, page: state.page.append(data)));
      return;
    }
    // Page one stays on screen; the message explains why there is no more.
    emit(state.copyWith(loadingMore: false, errorMessage: result.failureMessage));
  }

  /// Re-runs the first page after a filter change, keeping the old rows until
  /// the new ones land would be worse — a filtered list that still shows the
  /// old filter's rows reads as a bug.
  Future<void> applyFilter(void Function() mutate) async {
    mutate();
    await load();
  }
}
