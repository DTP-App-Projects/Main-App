import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/orders_repository.dart';

/// `GET /v2/purchase_orders?role=trader&status=a,b,c`.
///
/// `role` is always sent: without it a hybrid organization sees its own
/// supplier-side orders mixed into "my orders".
class OrdersCubit extends PagedCubit<PurchaseOrder> {
  final OrdersRepository _repo;
  final Workspace role;

  /// Comma-separated multi-value on the wire.
  Set<String> statuses = {};

  OrdersCubit(this._repo, {this.role = Workspace.trader});

  @override
  Future<ApiResult<Paged<PurchaseOrder>>> fetchPage(int page) =>
      _repo.orders(role: role, page: page, statuses: statuses.toList());

  Future<void> toggleStatus(String status) => applyFilter(() {
        if (!statuses.remove(status)) statuses.add(status);
      });

  Future<void> clearStatuses() => applyFilter(statuses.clear);
}

@immutable
class OrderDetailState {
  final bool loading;
  final PurchaseOrder? order;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const OrderDetailState({
    this.loading = true,
    this.order,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  OrderDetailState copyWith({
    bool? loading,
    PurchaseOrder? order,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      OrderDetailState(
        loading: loading ?? this.loading,
        order: order ?? this.order,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

/// One order, with its actions built from what the server says is allowed.
///
/// Nothing about the state machine is hardcoded here: `allowed_transitions`,
/// `reason_required_for`, `next_action` and `can_request_cancel` come off the
/// detail response, and `viewer_role` decides which side is looking.
class OrderDetailCubit extends Cubit<OrderDetailState> {
  final OrdersRepository _repo;
  final int orderId;

  OrderDetailCubit(this._repo, this.orderId) : super(const OrderDetailState());

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

  /// A transition the server listed. [note] is mandatory for the ones named
  /// in `reason_required_for` — 3 to 500 characters.
  Future<bool> changeStatus(String status, {String? note}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.changeStatus(id: orderId, status: status, note: note);
    if (result case Ok(:final data)) {
      emit(state.copyWith(order: data, action: const SubmitState()));
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }

  /// The selling side answers a cancellation request: `accepted` or
  /// `rejected`, with a note required on a rejection.
  Future<bool> decideCancelRequest(String decision, {String? note}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.decideCancelRequest(
      id: orderId,
      decision: decision,
      note: note,
    );
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: result.failureState));
    if (ok) await load();
    return ok;
  }

  /// After approval the buying side may only ask. Not auto-retried — a
  /// duplicate request is noise on the selling side.
  Future<bool> requestCancel(String reason) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.requestCancel(id: orderId, reason: reason);
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: result.failureState));
    if (ok) await load();
    return ok;
  }
}
