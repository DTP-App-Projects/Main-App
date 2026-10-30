import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paged.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/paged_cubit.dart';
import '../../../data/models/fleet/internal_transfer.dart';
import '../../../data/repositories/account_repository.dart' show TransferLineInput;
import '../../../data/repositories/internal_transfers_repository.dart';

/// «النقل الداخلي» — the list, filtered by one status.
class InternalTransfersCubit extends PagedCubit<InternalTransfer> {
  final InternalTransfersRepository _repo;

  String? status;

  InternalTransfersCubit(this._repo);

  @override
  Future<ApiResult<Paged<InternalTransfer>>> fetchPage(int page) =>
      _repo.transfers(status: status, page: page);

  Future<void> filter(String? value) => applyFilter(() => status = value);
}

@immutable
class InternalTransferState {
  final bool loading;
  final InternalTransfer? transfer;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  /// The SKUs a line can be added from; read the first time it is needed.
  final List<TransferSku> skus;

  const InternalTransferState({
    this.loading = true,
    this.transfer,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
    this.skus = const [],
  });

  InternalTransferState copyWith({
    bool? loading,
    InternalTransfer? transfer,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    List<TransferSku>? skus,
    bool clearError = false,
  }) => InternalTransferState(
    loading: loading ?? this.loading,
    transfer: transfer ?? this.transfer,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    action: action ?? this.action,
    skus: skus ?? this.skus,
  );
}

/// One transfer: approve / cancel / close, and its lines while `draft`.
class InternalTransferCubit extends Cubit<InternalTransferState> {
  final InternalTransfersRepository _repo;
  final int transferId;

  InternalTransferCubit(this._repo, this.transferId) : super(const InternalTransferState());

  Future<void> load({bool quiet = false}) async {
    if (!quiet || state.transfer == null) {
      emit(state.copyWith(loading: true, clearError: true, offline: false));
    }
    final result = await _repo.transfer(transferId);
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, transfer: data, clearError: true));
      return;
    }
    emit(
      state.copyWith(
        loading: false,
        offline: result.isOffline,
        errorMessage: result.failureMessage,
      ),
    );
  }

  Future<bool> approve() => _status('approved');

  Future<bool> cancel(String reason) => _status('canceled', reason: reason);

  Future<bool> closeTransfer() => _status('closed');

  Future<bool> _status(String status, {String? reason}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));
    final result = await _repo.changeStatus(transferId, status, reason: reason);
    if (isClosed) return false;
    if (result case Ok(:final data)) {
      emit(
        state.copyWith(
          transfer: data,
          action: const SubmitState(status: FormStatus.success),
        ),
      );
      // The PATCH answer may come back without its relations loaded.
      await load(quiet: true);
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }

  /// The SKU list for "add a line", read once.
  Future<List<TransferSku>> skus() async {
    if (state.skus.isNotEmpty) return state.skus;
    final result = await _repo.formOptions();
    if (isClosed) return const [];
    if (result case Ok(:final data)) {
      emit(state.copyWith(skus: data.skus));
      return data.skus;
    }
    emit(state.copyWith(action: result.failureState));
    return const [];
  }

  Future<bool> addLine(int skuId, double qty) =>
      _lines(() => _repo.addLine(transferId, skuId: skuId, requestedQty: qty));

  Future<bool> deleteLine(int lineId) => _lines(() => _repo.deleteLine(transferId, lineId));

  Future<bool> _lines(Future<ApiResult<void>> Function() call) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));
    final result = await call();
    if (isClosed) return false;
    if (result is Ok<void> || result is NoContent<void>) {
      emit(state.copyWith(action: const SubmitState()));
      await load(quiet: true);
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }
}

@immutable
class TransferDraftLine {
  final TransferSku sku;
  final double qty;

  const TransferDraftLine({required this.sku, this.qty = 0});
}

@immutable
class TransferFormState {
  final bool loading;
  final TransferFormOptions? options;
  final String? errorMessage;
  final bool offline;
  final int? sourceId;
  final int? destinationId;
  final String priority;
  final DateTime? requiredBy;
  final bool approveNow;
  final List<TransferDraftLine> lines;
  final SubmitState submit;

  const TransferFormState({
    this.loading = true,
    this.options,
    this.errorMessage,
    this.offline = false,
    this.sourceId,
    this.destinationId,
    this.priority = 'normal',
    this.requiredBy,
    this.approveNow = false,
    this.lines = const [],
    this.submit = const SubmitState(),
  });

  /// The server refuses it too; the form says so first.
  bool get sameBranch => sourceId != null && sourceId == destinationId;

  List<TransferSku> get pickable {
    final taken = {for (final l in lines) l.sku.id};
    return [
      for (final s in options?.skus ?? const <TransferSku>[])
        if (!taken.contains(s.id)) s,
    ];
  }

  bool get canSubmit =>
      sourceId != null &&
      destinationId != null &&
      !sameBranch &&
      lines.any((l) => l.qty > 0) &&
      !submit.isSubmitting;

  TransferFormState copyWith({
    bool? loading,
    TransferFormOptions? options,
    String? errorMessage,
    bool? offline,
    int? sourceId,
    int? destinationId,
    String? priority,
    DateTime? requiredBy,
    bool? approveNow,
    List<TransferDraftLine>? lines,
    SubmitState? submit,
    bool clearError = false,
    bool clearRequiredBy = false,
  }) => TransferFormState(
    loading: loading ?? this.loading,
    options: options ?? this.options,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    sourceId: sourceId ?? this.sourceId,
    destinationId: destinationId ?? this.destinationId,
    priority: priority ?? this.priority,
    requiredBy: clearRequiredBy ? null : (requiredBy ?? this.requiredBy),
    approveNow: approveNow ?? this.approveNow,
    lines: lines ?? this.lines,
    submit: submit ?? this.submit,
  );
}

/// «طلب نقل داخلي»: from one branch to another, with lines.
class InternalTransferFormCubit extends Cubit<TransferFormState> {
  final InternalTransfersRepository _repo;

  InternalTransferFormCubit(this._repo) : super(const TransferFormState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));
    final result = await _repo.formOptions();
    if (isClosed) return;
    if (result case Ok(:final data)) {
      int? source;
      for (final b in data.branches) {
        if (b.isDefault) source = b.id;
      }
      emit(
        state.copyWith(
          loading: false,
          options: data,
          sourceId: source,
          priority: data.priorities.contains('normal') ? 'normal' : data.priorities.first,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        loading: false,
        offline: result.isOffline,
        errorMessage: result.failureMessage,
      ),
    );
  }

  void chooseSource(int? id) => emit(state.copyWith(sourceId: id));

  void chooseDestination(int? id) => emit(state.copyWith(destinationId: id));

  void choosePriority(String? value) => emit(state.copyWith(priority: value));

  void setRequiredBy(DateTime? day) =>
      emit(state.copyWith(requiredBy: day, clearRequiredBy: day == null));

  void setApproveNow(bool value) => emit(state.copyWith(approveNow: value));

  void addSku(TransferSku sku) {
    if (state.lines.any((l) => l.sku.id == sku.id)) return;
    emit(
      state.copyWith(
        lines: [
          ...state.lines,
          TransferDraftLine(sku: sku, qty: 1),
        ],
      ),
    );
  }

  void removeSku(int skuId) => emit(
    state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.sku.id != skuId) l,
      ],
    ),
  );

  void setQty(int skuId, double qty) => emit(
    state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.sku.id == skuId) TransferDraftLine(sku: l.sku, qty: qty < 0 ? 0 : qty) else l,
      ],
    ),
  );

  Future<InternalTransfer?> submit({String? notes, required bool mayApprove}) async {
    if (state.sameBranch) {
      emit(
        state.copyWith(
          submit: SubmitState(
            status: FormStatus.failure,
            message: 'transfer.same_branch'.tr(),
            bag: {
              'destination_branch_id': ['transfer.same_branch'.tr()],
            },
          ),
        ),
      );
      return null;
    }
    if (!state.canSubmit) return null;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));
    final result = await _repo.create(
      sourceBranchId: state.sourceId!,
      destinationBranchId: state.destinationId!,
      priority: state.priority,
      requiredByDate: state.requiredBy,
      notes: notes,
      // Only offered with `internal_transfers.approve`; never sent otherwise.
      approveNow: mayApprove && state.approveNow,
      lines: [
        for (final l in state.lines)
          if (l.qty > 0) TransferLineInput(skuId: l.sku.id, requestedQty: l.qty),
      ],
    );
    if (isClosed) return null;
    if (result case Ok(:final data)) {
      emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
      return data;
    }
    emit(state.copyWith(submit: result.failureState));
    return null;
  }
}
