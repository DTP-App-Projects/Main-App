import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/network/paged.dart';
import '../../../../../data/models/notifications/app_notification.dart';
import '../../../../../data/repositories/notifications_repository.dart';

@immutable
class NotificationsState {
  final bool loading;
  final bool loadingMore;
  final Paged<AppNotification> page;
  final String? errorMessage;
  final bool offline;

  /// Kept separately from the page so the badge survives paging and filtering.
  final int unreadCount;

  final bool unreadOnly;

  const NotificationsState({
    this.loading = true,
    this.loadingMore = false,
    this.page = const Paged.empty(),
    this.errorMessage,
    this.offline = false,
    this.unreadCount = 0,
    this.unreadOnly = false,
  });

  List<AppNotification> get items => page.items;
  bool get isEmpty => !loading && items.isEmpty && errorMessage == null;
  bool get hasMore => page.hasMore;

  NotificationsState copyWith({
    bool? loading,
    bool? loadingMore,
    Paged<AppNotification>? page,
    String? errorMessage,
    bool? offline,
    int? unreadCount,
    bool? unreadOnly,
    bool clearError = false,
  }) => NotificationsState(
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    page: page ?? this.page,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    unreadCount: unreadCount ?? this.unreadCount,
    unreadOnly: unreadOnly ?? this.unreadOnly,
  );
}

/// Lives for the whole session: the shell reads [NotificationsState.unreadCount]
/// for the badge whether or not the list has ever been opened.
class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repo;

  NotificationsCubit(this._repo) : super(const NotificationsState());

  /// Coalesces a burst of pushes into one re-read (60 req/min budget).
  Timer? _pushRefresh;

  /// [quiet] re-reads page one behind the rows already on screen — no
  /// skeleton, and a failure keeps them.
  Future<void> load({bool unreadOnly = false, bool quiet = false}) async {
    final silent = quiet && state.items.isNotEmpty && state.unreadOnly == unreadOnly;
    if (!silent) {
      emit(state.copyWith(loading: true, clearError: true, offline: false, unreadOnly: unreadOnly));
    }

    final result = await _repo.list(page: 1, unreadOnly: unreadOnly);
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(
        state.copyWith(
          loading: false,
          page: data,
          unreadCount: data.unreadCount ?? state.unreadCount,
        ),
      );
      return;
    }
    if (silent) return;
    emit(
      state.copyWith(
        loading: false,
        offline: result.isOffline,
        errorMessage: result.failureMessage,
      ),
    );
  }

  Future<void> refresh({bool quiet = false}) => load(unreadOnly: state.unreadOnly, quiet: quiet);

  Future<void> toggleUnreadOnly() => load(unreadOnly: !state.unreadOnly);

  /// Infinite scroll. Guarded so a fast scroller cannot queue three pages.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));

    final result = await _repo.list(page: state.page.currentPage + 1, unreadOnly: state.unreadOnly);
    if (result case Ok(:final data)) {
      emit(
        state.copyWith(
          loadingMore: false,
          page: state.page.append(data),
          unreadCount: data.unreadCount ?? state.unreadCount,
        ),
      );
      return;
    }
    // A failed page-two keeps page one on screen; the message is enough.
    emit(state.copyWith(loadingMore: false, errorMessage: result.failureMessage));
  }

  /// Marks one row read. The row flips locally first so the tap feels
  /// immediate, and is put back if the server disagrees.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final before = state;
    _replace(notification.markedRead(), unread: (state.unreadCount - 1).clamp(0, 1 << 30));

    final result = await _repo.markRead(notification.id);
    if (result is Ok || result is NoContent) return;
    emit(before.copyWith(errorMessage: result.failureMessage));
  }

  Future<void> markAllRead() async {
    final result = await _repo.markAllRead();
    if (result case Ok(:final data)) {
      emit(
        state.copyWith(
          unreadCount: data,
          page: Paged(
            items: state.items.map((n) => n.markedRead()).toList(),
            currentPage: state.page.currentPage,
            lastPage: state.page.lastPage,
            perPage: state.page.perPage,
            total: state.page.total,
            unreadCount: data,
          ),
        ),
      );
      // The unread-only filter would now show nothing; re-read instead of
      // leaving an empty list that looks like a bug.
      if (state.unreadOnly) await refresh();
      return;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
  }

  /// Notifications are scoped to the organization, so a logout or an org
  /// switch must not leave the previous one's badge on screen.
  void reset() {
    _pushRefresh?.cancel();
    emit(const NotificationsState());
  }

  /// A push arrived while the app was open: bump the badge at once, then
  /// re-read the list so the new row is there — the list used to keep its
  /// old rows until pulled, and only the badge moved.
  void onPushReceived() {
    emit(state.copyWith(unreadCount: state.unreadCount + 1));
    _pushRefresh?.cancel();
    _pushRefresh = Timer(const Duration(seconds: 1), () => refresh(quiet: true));
  }

  @override
  Future<void> close() {
    _pushRefresh?.cancel();
    return super.close();
  }

  void _replace(AppNotification updated, {required int unread}) {
    emit(
      state.copyWith(
        unreadCount: unread,
        page: Paged(
          items: [for (final item in state.items) item.id == updated.id ? updated : item],
          currentPage: state.page.currentPage,
          lastPage: state.page.lastPage,
          perPage: state.page.perPage,
          total: state.page.total,
          unreadCount: unread,
        ),
      ),
    );
  }
}
