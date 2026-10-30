import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../data/models/trade/document_flow.dart';
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

  /// The stable code of the last failed action — the screen guides the user
  /// on the compliance refusals (no framework agreement, supply suspended,
  /// credit limit exceeded).
  final String actionCode;

  /// `GET /purchase_orders/{id}/timeline` — the full history, the
  /// cancellation request's notes included. Falls back to the detail's own.
  final List<TimelineEvent>? timeline;

  /// The documents around the order (shipments, receipts, invoices,
  /// payments). Optional: empty when the server has none to show.
  final DocumentFlow flow;

  const OrderDetailState({
    this.timeline,
    this.flow = DocumentFlow.empty,
    this.actionCode = '',
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
    String? actionCode,
    List<TimelineEvent>? timeline,
    DocumentFlow? flow,
  }) =>
      OrderDetailState(
        timeline: timeline ?? this.timeline,
        flow: flow ?? this.flow,
        actionCode: actionCode ?? this.actionCode,
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

  /// The order, then its timeline, then the document chain — in sequence
  /// (the request budget is per minute). Every action ends here: the screen
  /// shows what the server now says, never a locally patched copy.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.order(orderId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, order: data));
    } else {
      emit(state.copyWith(
        loading: false,
        offline: result.isOffline,
        errorMessage: result.failureMessage,
      ));
      return;
    }

    final timeline = await _repo.timeline(orderId);
    if (isClosed) return;
    if (timeline case Ok(:final data) when data.isNotEmpty) emit(state.copyWith(timeline: data));

    final flow = await _repo.documentFlow('purchase_order', orderId);
    if (isClosed) return;
    if (flow case Ok(:final data)) emit(state.copyWith(flow: data));
  }

  /// The timeline to draw: the endpoint's, else the one on the detail.
  List<TimelineEvent> get timeline => state.timeline ?? state.order?.timeline ?? const [];

  /// A transition the server listed. [note] is mandatory for the ones named
  /// in `reason_required_for` — 3 to 500 characters.
  Future<bool> changeStatus(String status, {String? note, String? otpCode}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting), actionCode: ''));

    final result = await _repo.changeStatus(id: orderId, status: status, note: note, otpCode: otpCode);
    if (result is Ok<PurchaseOrder> || result is NoContent<PurchaseOrder>) {
      emit(state.copyWith(action: const SubmitState()));
      await load();
      return true;
    }
    emit(state.copyWith(action: result.failureState, actionCode: result.failureCode));
    return false;
  }

  /// The OTP sheet posts the transition itself and keeps a rejection on the
  /// sheet; this is its submit, reporting the raw result back to it.
  Future<ApiResult<PurchaseOrder>> changeStatusWithOtp(String status, String otpCode, {String? note}) async {
    final result = await _repo.changeStatus(id: orderId, status: status, note: note, otpCode: otpCode);
    if (result is Ok<PurchaseOrder> || result is NoContent<PurchaseOrder>) {
      emit(state.copyWith(action: const SubmitState(), actionCode: ''));
      await load();
    } else {
      emit(state.copyWith(actionCode: result.failureCode));
    }
    return result;
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
