import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../data/models/advanced/contract.dart';
import '../../../../data/repositories/contracts_repository.dart';

enum ApprovalsFilter { all, purchaseOrders, contracts }

@immutable
class ApprovalsState {
  final bool loading;
  final ApprovalsInbox inbox;
  final String? errorMessage;
  final bool offline;
  final ApprovalsFilter filter;

  /// The purchase-order approval being decided, for its buttons' spinner.
  final int? decidingId;
  final SubmitState action;

  const ApprovalsState({
    this.loading = true,
    this.inbox = const ApprovalsInbox(),
    this.errorMessage,
    this.offline = false,
    this.filter = ApprovalsFilter.all,
    this.decidingId,
    this.action = const SubmitState(),
  });

  ApprovalsState copyWith({
    bool? loading,
    ApprovalsInbox? inbox,
    String? errorMessage,
    bool? offline,
    ApprovalsFilter? filter,
    int? decidingId,
    bool clearDeciding = false,
    SubmitState? action,
    bool clearError = false,
  }) =>
      ApprovalsState(
        loading: loading ?? this.loading,
        inbox: inbox ?? this.inbox,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        filter: filter ?? this.filter,
        decidingId: clearDeciding ? null : (decidingId ?? this.decidingId),
        action: action ?? this.action,
      );
}

/// «صندوق الموافقات» (guide Part 8.7): an organization's internal approvals
/// of purchase orders and contracts. A contract is decided on its own page
/// (its approval chain lives there); a purchase-order step here.
class ApprovalsCubit extends Cubit<ApprovalsState> {
  final ContractsRepository _repo;

  ApprovalsCubit(this._repo) : super(const ApprovalsState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));
    final result = await _repo.approvalsInbox();
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, inbox: data));
      return;
    }
    emit(state.copyWith(loading: false, offline: result.isOffline, errorMessage: result.failureMessage));
  }

  void setFilter(ApprovalsFilter filter) => emit(state.copyWith(filter: filter));

  /// `approved` or `rejected` (a rejection carries its reason). A supplier's
  /// final acceptance of an order is not decided here: it needs the binding
  /// code on the order page, and the server's refusal says so.
  Future<bool> decide(PurchaseOrderApproval approval, String status, {String? note}) async {
    if (state.decidingId != null) return false;
    emit(state.copyWith(decidingId: approval.id, action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.decideOrderApproval(approvalId: approval.id, status: status, note: note);
    if (isClosed) return false;
    final ok = result is Ok || result is NoContent;
    emit(state.copyWith(clearDeciding: true, action: result.failureState));
    if (ok) await load();
    return ok;
  }
}
