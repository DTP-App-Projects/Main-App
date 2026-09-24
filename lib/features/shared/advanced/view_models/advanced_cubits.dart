import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../data/models/advanced/contract.dart';
import '../../../../data/models/advanced/finance.dart';
import '../../../../data/models/advanced/shelf.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/contracts_repository.dart';

// ---------------------------------------------------------------------------
// Contracts
// ---------------------------------------------------------------------------

class ContractsCubit extends PagedCubit<Contract> {
  final ContractsRepository _repo;

  String? status;

  ContractsCubit(this._repo);

  @override
  Future<ApiResult<Paged<Contract>>> fetchPage(int page) =>
      _repo.contracts(page: page, status: status);

  Future<void> setStatus(String? value) => applyFilter(() => status = value);
}

@immutable
class ContractDetailState {
  final bool loading;
  final Contract? contract;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const ContractDetailState({
    this.loading = true,
    this.contract,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  ContractDetailState copyWith({
    bool? loading,
    Contract? contract,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      ContractDetailState(
        loading: loading ?? this.loading,
        contract: contract ?? this.contract,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

/// One contract, with its approval chain.
///
/// Approving needs `contracts.approve`, which is deliberately separate from
/// `contracts.manage` — the person who drafts a contract is not always the
/// person who signs it off.
class ContractDetailCubit extends Cubit<ContractDetailState> {
  final ContractsRepository _repo;
  final int contractId;

  ContractDetailCubit(this._repo, this.contractId) : super(const ContractDetailState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.contract(contractId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, contract: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<bool> setStatus(String status, {String? note}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.setContractStatus(
      id: contractId,
      status: status,
      note: note,
    );
    if (result case Ok(:final data)) {
      emit(state.copyWith(contract: data, action: const SubmitState()));
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }

  Future<bool> decideApproval({
    required int approvalId,
    required String status,
    String? note,
  }) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.decideContractApproval(
      contractId: contractId,
      approvalId: approvalId,
      status: status,
      note: note,
    );
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: result.failureState));
    if (ok) await load();
    return ok;
  }
}

// ---------------------------------------------------------------------------
// Shelf
// ---------------------------------------------------------------------------

@immutable
class ShelfPanelState {
  final bool loading;
  final List<ShelfContract> contracts;
  final String? errorMessage;
  final bool offline;

  const ShelfPanelState({
    this.loading = true,
    this.contracts = const [],
    this.errorMessage,
    this.offline = false,
  });

  ShelfPanelState copyWith({
    bool? loading,
    List<ShelfContract>? contracts,
    String? errorMessage,
    bool? offline,
    bool clearError = false,
  }) =>
      ShelfPanelState(
        loading: loading ?? this.loading,
        contracts: contracts ?? this.contracts,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
      );
}

class ShelfPanelCubit extends Cubit<ShelfPanelState> {
  final ContractsRepository _repo;

  ShelfPanelCubit(this._repo) : super(const ShelfPanelState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.shelfContracts();
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, contracts: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }
}

class ShelfAdjustmentsCubit extends PagedCubit<ShelfAdjustment> {
  final ContractsRepository _repo;

  String? status;

  ShelfAdjustmentsCubit(this._repo);

  @override
  Future<ApiResult<Paged<ShelfAdjustment>>> fetchPage(int page) =>
      _repo.shelfAdjustments(page: page, status: status);

  Future<void> setStatus(String? value) => applyFilter(() => status = value);
}

/// One SKU being counted, with whatever the last visit left behind.
@immutable
class CountDraft {
  final int skuId;
  final String skuName;
  final double previousCount;
  final double currentCount;
  final double addedCount;
  final double damagedCount;
  final double expiredCount;
  final String? currentCountPhotoPath;
  final String? beforePhotoPath;
  final String? afterPhotoPath;

  const CountDraft({
    required this.skuId,
    required this.skuName,
    this.previousCount = 0,
    this.currentCount = 0,
    this.addedCount = 0,
    this.damagedCount = 0,
    this.expiredCount = 0,
    this.currentCountPhotoPath,
    this.beforePhotoPath,
    this.afterPhotoPath,
  });

  /// What the numbers say was sold. Shown live so an operator notices a
  /// typo before submitting, not after the settlement is wrong.
  double get impliedSold =>
      previousCount + addedCount - currentCount - damagedCount - expiredCount;

  bool get looksWrong => impliedSold < 0;

  CountDraft copyWith({
    double? previousCount,
    double? currentCount,
    double? addedCount,
    double? damagedCount,
    double? expiredCount,
    String? currentCountPhotoPath,
    String? beforePhotoPath,
    String? afterPhotoPath,
  }) =>
      CountDraft(
        skuId: skuId,
        skuName: skuName,
        previousCount: previousCount ?? this.previousCount,
        currentCount: currentCount ?? this.currentCount,
        addedCount: addedCount ?? this.addedCount,
        damagedCount: damagedCount ?? this.damagedCount,
        expiredCount: expiredCount ?? this.expiredCount,
        currentCountPhotoPath: currentCountPhotoPath ?? this.currentCountPhotoPath,
        beforePhotoPath: beforePhotoPath ?? this.beforePhotoPath,
        afterPhotoPath: afterPhotoPath ?? this.afterPhotoPath,
      );

  ShelfLineInput toInput() => ShelfLineInput(
        skuId: skuId,
        previousCount: previousCount,
        currentCount: currentCount,
        addedCount: addedCount,
        damagedCount: damagedCount,
        expiredCount: expiredCount,
        currentCountPhotoPath: currentCountPhotoPath,
        beforePhotoPath: beforePhotoPath,
        afterPhotoPath: afterPhotoPath,
      );
}

@immutable
class ShelfCountState {
  final List<CountDraft> lines;
  final String adjustmentType;
  final String visitType;
  final SubmitState action;
  final bool prefilling;
  final bool submitted;

  const ShelfCountState({
    this.lines = const [],
    this.adjustmentType = 'manual',
    this.visitType = 'supplier_self',
    this.action = const SubmitState(),
    this.prefilling = false,
    this.submitted = false,
  });

  bool get hasLines => lines.isNotEmpty;
  bool get anyLooksWrong => lines.any((line) => line.looksWrong);

  ShelfCountState copyWith({
    List<CountDraft>? lines,
    String? adjustmentType,
    String? visitType,
    SubmitState? action,
    bool? prefilling,
    bool? submitted,
  }) =>
      ShelfCountState(
        lines: lines ?? this.lines,
        adjustmentType: adjustmentType ?? this.adjustmentType,
        visitType: visitType ?? this.visitType,
        action: action ?? this.action,
        prefilling: prefilling ?? this.prefilling,
        submitted: submitted ?? this.submitted,
      );
}

/// The shelf count form.
///
/// It opens by asking the server what the last visit left on the shelf, so
/// nobody has to remember — that is what `previous_count` is for.
class ShelfCountCubit extends Cubit<ShelfCountState> {
  final ContractsRepository _repo;
  final int contractId;
  final int branchId;

  ShelfCountCubit(this._repo, {required this.contractId, required this.branchId})
      : super(const ShelfCountState());

  void addSku({required int skuId, required String skuName}) {
    if (state.lines.any((line) => line.skuId == skuId)) return;
    emit(state.copyWith(
      lines: [...state.lines, CountDraft(skuId: skuId, skuName: skuName)],
    ));
  }

  void removeSku(int skuId) => emit(state.copyWith(
        lines: state.lines.where((line) => line.skuId != skuId).toList(),
      ));

  void updateLine(int skuId, CountDraft Function(CountDraft) mutate) =>
      emit(state.copyWith(
        lines: [
          for (final line in state.lines) line.skuId == skuId ? mutate(line) : line,
        ],
      ));

  void setAdjustmentType(String value) => emit(state.copyWith(adjustmentType: value));

  void setVisitType(String value) => emit(state.copyWith(visitType: value));

  /// Fills `previous_count` for every SKU on the form in one call.
  Future<void> prefillPreviousCounts() async {
    if (state.lines.isEmpty || state.prefilling) return;
    emit(state.copyWith(prefilling: true));

    final result = await _repo.previousCount(
      contractId: contractId,
      branchId: branchId,
      skuIds: state.lines.map((line) => line.skuId).toList(),
    );

    if (result case Ok(:final data)) {
      final bySku = {for (final row in data) row.skuId: row.previousCount};
      emit(state.copyWith(
        prefilling: false,
        lines: [
          for (final line in state.lines)
            line.copyWith(previousCount: bySku[line.skuId] ?? line.previousCount),
        ],
      ));
      return;
    }
    emit(state.copyWith(
      prefilling: false,
      action: result.failureState,
    ));
  }

  Future<bool> submit({String? notes}) async {
    if (state.action.isSubmitting || state.lines.isEmpty) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.saveShelfAdjustment(
      contractId: contractId,
      branchId: branchId,
      adjustmentType: state.adjustmentType,
      visitType: state.visitType,
      notes: notes,
      lines: state.lines.map((line) => line.toInput()).toList(),
    );

    if (result case Ok()) {
      emit(state.copyWith(
        submitted: true,
        action: const SubmitState(status: FormStatus.success),
      ));
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }
}

// ---------------------------------------------------------------------------
// Settlements
// ---------------------------------------------------------------------------

class SettlementsCubit extends PagedCubit<Settlement> {
  final AccountRepository _repo;

  String? status;

  SettlementsCubit(this._repo);

  @override
  Future<ApiResult<Paged<Settlement>>> fetchPage(int page) =>
      _repo.settlements(page: page, status: status);

  Future<void> setStatus(String? value) => applyFilter(() => status = value);

  Future<bool> setSettlementStatus({required int id, required String value}) async {
    final result = await _repo.setSettlementStatus(id: id, status: value);
    if (result is Ok<Settlement> || result is NoContent<Settlement>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }
}

// ---------------------------------------------------------------------------
// Wallet and subscription
// ---------------------------------------------------------------------------

@immutable
class WalletState {
  final bool loading;
  final Wallet? wallet;
  final List<WalletTransaction> transactions;
  final List<TopupMethod> methods;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const WalletState({
    this.loading = true,
    this.wallet,
    this.transactions = const [],
    this.methods = const [],
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  WalletState copyWith({
    bool? loading,
    Wallet? wallet,
    List<WalletTransaction>? transactions,
    List<TopupMethod>? methods,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      WalletState(
        loading: loading ?? this.loading,
        wallet: wallet ?? this.wallet,
        transactions: transactions ?? this.transactions,
        methods: methods ?? this.methods,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

class WalletCubit extends Cubit<WalletState> {
  final AccountRepository _repo;

  WalletCubit(this._repo) : super(const WalletState());

  /// Three reads in sequence, not a fan-out — the budget is 60 a minute.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final wallet = await _repo.wallet();
    if (wallet case Ok(:final data)) {
      emit(state.copyWith(loading: false, wallet: data));
    } else {
      emit(state.copyWith(
        loading: false,
        offline: wallet.isOffline,
        errorMessage: wallet.failureMessage,
      ));
      return;
    }

    final transactions = await _repo.walletTransactions();
    if (transactions case Ok(:final data)) {
      emit(state.copyWith(transactions: data.items));
    }

    final methods = await _repo.topupMethods();
    if (methods case Ok(:final data)) emit(state.copyWith(methods: data));
  }

  Future<bool> requestTopup({
    required double amount,
    required String method,
    String? bankReference,
    String? proofPath,
  }) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.requestTopup(
      amount: amount,
      method: method,
      bankReference: bankReference,
      transferProofPath: proofPath,
    );
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<void> || result is NoContent<void>;
    if (ok) await load();
    return ok;
  }
}

@immutable
class SubscriptionState {
  final bool loading;
  final SubscriptionSummary? summary;
  final List<SubscriptionPlan> plans;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const SubscriptionState({
    this.loading = true,
    this.summary,
    this.plans = const [],
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  SubscriptionState copyWith({
    bool? loading,
    SubscriptionSummary? summary,
    List<SubscriptionPlan>? plans,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      SubscriptionState(
        loading: loading ?? this.loading,
        summary: summary ?? this.summary,
        plans: plans ?? this.plans,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final AccountRepository _repo;

  SubscriptionCubit(this._repo) : super(const SubscriptionState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final summary = await _repo.currentSubscription();
    if (summary case Ok(:final data)) {
      emit(state.copyWith(loading: false, summary: data));
    } else {
      emit(state.copyWith(
        loading: false,
        offline: summary.isOffline,
        errorMessage: summary.failureMessage,
      ));
    }

    final plans = await _repo.plans();
    if (plans case Ok(:final data)) emit(state.copyWith(plans: data));
  }

  Future<bool> setBillingMode(String mode) => _run(() => _repo.setBillingMode(mode));

  /// `422 already_subscribed` is a real answer — the trial has been used.
  Future<bool> startTrial() => _run(_repo.startTrial);

  Future<bool> _run(Future<ApiResult<void>> Function() call) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await call();
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<void> || result is NoContent<void>;
    if (ok) await load();
    return ok;
  }
}

// ---------------------------------------------------------------------------
// Ratings
// ---------------------------------------------------------------------------

@immutable
class RatingsState {
  final bool loading;
  final RatingAggregate? aggregate;
  final List<Rating> ratings;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const RatingsState({
    this.loading = true,
    this.aggregate,
    this.ratings = const [],
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  /// The dimensions to offer. The enum is server-side and unreadable from the
  /// validators, so the picker is built from what has actually been used.
  List<String> get dimensions {
    final known = {
      ...?aggregate?.knownDimensions,
      ...ratings.map((rating) => rating.dimension),
    }..removeWhere((value) => value.isEmpty);
    return known.toList()..sort();
  }

  RatingsState copyWith({
    bool? loading,
    RatingAggregate? aggregate,
    List<Rating>? ratings,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      RatingsState(
        loading: loading ?? this.loading,
        aggregate: aggregate ?? this.aggregate,
        ratings: ratings ?? this.ratings,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

class RatingsCubit extends Cubit<RatingsState> {
  final AccountRepository _repo;
  final int businessRelationshipId;

  RatingsCubit(this._repo, this.businessRelationshipId) : super(const RatingsState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final aggregate =
        await _repo.ratingAggregate(businessRelationshipId: businessRelationshipId);
    if (aggregate case Ok(:final data)) {
      emit(state.copyWith(loading: false, aggregate: data));
    } else {
      emit(state.copyWith(
        loading: false,
        offline: aggregate.isOffline,
        errorMessage: aggregate.failureMessage,
      ));
    }

    final ratings = await _repo.ratings(businessRelationshipId: businessRelationshipId);
    if (ratings case Ok(:final data)) emit(state.copyWith(ratings: data));
  }

  Future<bool> rate({
    required String dimension,
    required int score,
    String? note,
  }) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.rate(
      businessRelationshipId: businessRelationshipId,
      dimension: dimension,
      score: score,
      note: note,
    );
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<Rating> || result is NoContent<Rating>;
    if (ok) await load();
    return ok;
  }
}

// ---------------------------------------------------------------------------
// Account: deletion, Nafath, biometric devices
// ---------------------------------------------------------------------------

@immutable
class AccountState {
  final bool loading;
  final DeletionRequest? deletion;
  final List<BiometricCredential> devices;
  final String? errorMessage;
  final SubmitState action;

  const AccountState({
    this.loading = true,
    this.deletion,
    this.devices = const [],
    this.errorMessage,
    this.action = const SubmitState(),
  });

  bool get deletionPending => deletion?.isActive ?? false;

  AccountState copyWith({
    bool? loading,
    DeletionRequest? deletion,
    List<BiometricCredential>? devices,
    String? errorMessage,
    SubmitState? action,
    bool clearError = false,
    bool clearDeletion = false,
  }) =>
      AccountState(
        loading: loading ?? this.loading,
        deletion: clearDeletion ? null : (deletion ?? this.deletion),
        devices: devices ?? this.devices,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        action: action ?? this.action,
      );
}

class AccountCubit extends Cubit<AccountState> {
  final AccountRepository _repo;

  AccountCubit(this._repo) : super(const AccountState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    final deletion = await _repo.deletionRequest();
    // A 404 here means "nothing pending", which is the normal case.
    emit(state.copyWith(
      loading: false,
      deletion: deletion.dataOrNull,
      clearDeletion: deletion.dataOrNull == null,
    ));

    final devices = await _repo.biometricCredentials();
    if (devices case Ok(:final data)) emit(state.copyWith(devices: data));

    // B9: a failed load used to render as an empty account. A 404 on the
    // deletion request is the normal "nothing pending"; anything else that is
    // not a success (offline, server error) is surfaced so the screen can
    // offer a retry instead of pretending there is no data.
    bool failed(ApiResult<Object?> result) =>
        !(result is Ok || result is NoContent || (result is Failed && result.status == 404));
    final failure = failed(deletion) ? deletion : (failed(devices) ? devices : null);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.failureMessage ?? ''));
    }
  }

  /// The in-app delete path both stores require.
  Future<bool> requestDeletion(String reason) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.requestDeletion(reason: reason);
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<DeletionRequest> || result is NoContent<DeletionRequest>;
    if (ok) await load();
    return ok;
  }

  Future<bool> cancelDeletion() async {
    final result = await _repo.cancelDeletion();
    final ok = result is Ok<void> || result is NoContent<void>;
    if (ok) {
      emit(state.copyWith(clearDeletion: true));
      await load();
    } else {
      emit(state.copyWith(action: result.failureState));
    }
    return ok;
  }

  Future<bool> revokeDevice(int id) async {
    final result = await _repo.revokeBiometricCredential(id: id);
    final ok = result is Ok<void> || result is NoContent<void>;
    if (ok) await load();
    return ok;
  }
}

@immutable
class NafathState {
  final NafathTransaction? transaction;
  final SubmitState action;
  final bool polling;

  const NafathState({this.transaction, this.action = const SubmitState(), this.polling = false});

  NafathState copyWith({
    NafathTransaction? transaction,
    SubmitState? action,
    bool? polling,
    bool clearTransaction = false,
  }) =>
      NafathState(
        transaction: clearTransaction ? null : (transaction ?? this.transaction),
        action: action ?? this.action,
        polling: polling ?? this.polling,
      );
}

/// Nafath identity verification.
///
/// Gated on `platform_flags.nafath_enabled`: with the feature off the server
/// answers **200** with `nafath_disabled`, which the normalizer turns into a
/// failure so it cannot be mistaken for a started transaction.
class NafathCubit extends Cubit<NafathState> {
  static const pollInterval = Duration(seconds: 3);
  static const maxPolls = 40;

  final AccountRepository _repo;

  Timer? _timer;
  int _polls = 0;

  NafathCubit(this._repo) : super(const NafathState());

  Future<bool> start(String nationalId) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.startNafath(nationalId: nationalId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(transaction: data, action: const SubmitState()));
      _startPolling();
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }

  void _startPolling() {
    _timer?.cancel();
    _polls = 0;
    emit(state.copyWith(polling: true));
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    final transaction = state.transaction;
    if (transaction == null || isClosed) return;

    // Bounded: a user who never opens the Nafath app should not leave the
    // screen polling forever.
    if (++_polls > maxPolls) {
      _stop();
      return;
    }

    final result = await _repo.nafathStatus(transaction.transactionId);
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(transaction: data));
      if (!data.isPending) _stop();
    }
  }

  Future<void> cancel() async {
    final transaction = state.transaction;
    _stop();
    if (transaction == null) return;
    await _repo.cancelNafath(transaction.transactionId);
    emit(state.copyWith(clearTransaction: true));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (!isClosed) emit(state.copyWith(polling: false));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
