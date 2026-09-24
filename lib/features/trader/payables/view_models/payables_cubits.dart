import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../data/models/trade/invoice.dart';
import '../../../../data/repositories/receivables_repository.dart';

/// Payables: invoices the trader owes. `?role=trader` is always sent.
class InvoicesCubit extends PagedCubit<Invoice> {
  final ReceivablesRepository _repo;
  final Workspace role;

  Set<String> statuses = {};

  InvoicesCubit(this._repo, {this.role = Workspace.trader});

  @override
  Future<ApiResult<Paged<Invoice>>> fetchPage(int page) =>
      _repo.invoices(role: role, page: page, statuses: statuses.toList());

  Future<void> toggleStatus(String status) => applyFilter(() {
        if (!statuses.remove(status)) statuses.add(status);
      });

  Future<void> clearStatuses() => applyFilter(statuses.clear);
}

@immutable
class InvoiceDetailState {
  final bool loading;
  final Invoice? invoice;
  final String? errorMessage;
  final bool offline;

  /// Claims already raised against this invoice, so a trader can see that a
  /// payment is waiting to be confirmed rather than claiming it twice.
  final List<CollectionReceipt> claims;

  final SubmitState action;

  const InvoiceDetailState({
    this.loading = true,
    this.invoice,
    this.errorMessage,
    this.offline = false,
    this.claims = const [],
    this.action = const SubmitState(),
  });

  InvoiceDetailState copyWith({
    bool? loading,
    Invoice? invoice,
    String? errorMessage,
    bool? offline,
    List<CollectionReceipt>? claims,
    SubmitState? action,
    bool clearError = false,
  }) =>
      InvoiceDetailState(
        loading: loading ?? this.loading,
        invoice: invoice ?? this.invoice,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        claims: claims ?? this.claims,
        action: action ?? this.action,
      );
}

class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final ReceivablesRepository _repo;
  final int invoiceId;

  InvoiceDetailCubit(this._repo, this.invoiceId) : super(const InvoiceDetailState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final invoice = await _repo.invoice(invoiceId);
    if (invoice case Ok(:final data)) {
      emit(state.copyWith(loading: false, invoice: data));
    } else {
      emit(state.copyWith(
        loading: false,
        offline: invoice.isOffline,
        errorMessage: invoice.failureMessage,
      ));
      return;
    }

    final claims = await _repo.collections(invoiceId: invoiceId);
    if (claims case Ok(:final data)) emit(state.copyWith(claims: data.items));
  }

  /// **"I paid — please confirm."** One of invoice or due schedule is
  /// required; the screen passes the instalment when there is one.
  ///
  /// Never auto-retried: a duplicate claim costs the supplier a reconciliation.
  Future<bool> claim({
    required double amount,
    int? dueScheduleId,
    String? paymentMethod,
    String? referenceNo,
    String? proofFile,
    String? note,
    DateTime? receivedAt,
  }) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.claimPayment(
      amount: amount,
      invoiceId: dueScheduleId == null ? invoiceId : null,
      dueScheduleId: dueScheduleId,
      paymentMethod: paymentMethod,
      referenceNo: referenceNo,
      proofFile: proofFile,
      note: note,
      receivedAt: receivedAt,
    );

    if (result case Ok()) {
      emit(state.copyWith(action: const SubmitState(status: FormStatus.success)));
      await load();
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }
}

/// The trader's own claim history, across invoices.
class ClaimsCubit extends PagedCubit<CollectionReceipt> {
  final ReceivablesRepository _repo;

  ClaimsCubit(this._repo);

  @override
  Future<ApiResult<Paged<CollectionReceipt>>> fetchPage(int page) =>
      _repo.collections(page: page);
}
