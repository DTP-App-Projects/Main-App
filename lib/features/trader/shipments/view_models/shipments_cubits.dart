import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/repositories/shipments_repository.dart';

/// Incoming shipments. `?role=trader` is always sent — without it a hybrid
/// organization sees its own outbound deliveries in the same list.
class ShipmentsCubit extends PagedCubit<DeliveryNote> {
  final ShipmentsRepository _repo;
  final Workspace role;

  Set<String> statuses = {};

  ShipmentsCubit(this._repo, {this.role = Workspace.trader});

  @override
  Future<ApiResult<Paged<DeliveryNote>>> fetchPage(int page) =>
      _repo.deliveryNotes(role: role, page: page, statuses: statuses.toList());

  Future<void> toggleStatus(String status) => applyFilter(() {
        if (!statuses.remove(status)) statuses.add(status);
      });

  Future<void> clearStatuses() => applyFilter(statuses.clear);
}

@immutable
class TrackingState {
  final bool loading;
  final DeliveryNote? note;
  final String? errorMessage;
  final bool offline;

  /// True while the screen is polling, so the UI can say "live".
  final bool live;

  const TrackingState({
    this.loading = true,
    this.note,
    this.errorMessage,
    this.offline = false,
    this.live = false,
  });

  TrackingState copyWith({
    bool? loading,
    DeliveryNote? note,
    String? errorMessage,
    bool? offline,
    bool? live,
    bool clearError = false,
  }) =>
      TrackingState(
        loading: loading ?? this.loading,
        note: note ?? this.note,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        live: live ?? this.live,
      );
}

/// Live tracking for one delivery.
///
/// **Polling is bounded and cancelled on dispose**: 5 s while the screen is
/// visible, 30 s once it is backgrounded, and stopped entirely once the
/// shipment is no longer moving. The whole app shares a 60 requests/minute
/// budget.
class TrackingCubit extends Cubit<TrackingState> {
  static const foregroundInterval = Duration(seconds: 5);
  static const backgroundInterval = Duration(seconds: 30);

  final ShipmentsRepository _repo;
  final int deliveryNoteId;

  Timer? _timer;
  bool _foreground = true;

  TrackingCubit(this._repo, this.deliveryNoteId) : super(const TrackingState());

  Future<void> start() async {
    await _fetch(initial: true);
    _schedule();
  }

  /// Called when the app goes to the background or comes back.
  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _schedule();
  }

  Future<void> refresh() => _fetch(initial: false);

  Future<void> _fetch({required bool initial}) async {
    if (initial) emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.tracking(deliveryNoteId);
    if (isClosed) return;

    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, note: data, clearError: true, offline: false));
      // A delivered or cancelled shipment will not change again.
      if (!data.isInTransit) _stop();
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
      // Losing connectivity should not spin the poller; it resumes on retry.
      live: false,
    ));
    if (result.isOffline) _stop();
  }

  void _schedule() {
    _timer?.cancel();
    final note = state.note;
    if (note != null && !note.isInTransit) {
      emit(state.copyWith(live: false));
      return;
    }
    emit(state.copyWith(live: true));
    _timer = Timer.periodic(
      _foreground ? foregroundInterval : backgroundInterval,
      (_) => _fetch(initial: false),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (!isClosed) emit(state.copyWith(live: false));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
