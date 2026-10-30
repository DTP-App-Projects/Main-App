import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/ui/form_status.dart';
import '../../../data/models/fleet/fleet_contract.dart';
import '../../../data/repositories/fleet_repository.dart';

@immutable
class DeliveryContractsState {
  final bool loading;
  final FleetContractsOverview? overview;
  final String? errorMessage;
  final bool offline;

  /// The request form.
  final SubmitState submit;

  /// Ending a contract.
  final SubmitState action;

  const DeliveryContractsState({
    this.loading = true,
    this.overview,
    this.errorMessage,
    this.offline = false,
    this.submit = const SubmitState(),
    this.action = const SubmitState(),
  });

  DeliveryContractsState copyWith({
    bool? loading,
    FleetContractsOverview? overview,
    String? errorMessage,
    bool? offline,
    SubmitState? submit,
    SubmitState? action,
    bool clearError = false,
  }) => DeliveryContractsState(
    loading: loading ?? this.loading,
    overview: overview ?? this.overview,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    submit: submit ?? this.submit,
    action: action ?? this.action,
  );
}

/// «عقود التوصيل»: one read gives the contracts *and* the companies still
/// free to ask — so after a request or an end, one re-read moves the company
/// between the two.
class DeliveryContractsCubit extends Cubit<DeliveryContractsState> {
  final FleetRepository _repo;

  DeliveryContractsCubit(this._repo) : super(const DeliveryContractsState());

  Future<void> load({bool quiet = false}) async {
    if (!quiet || state.overview == null) {
      emit(state.copyWith(loading: true, clearError: true, offline: false));
    }
    final result = await _repo.contracts();
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, overview: data, clearError: true));
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

  void resetForm() => emit(state.copyWith(submit: const SubmitState()));

  Future<bool> request({
    required int fleetCompanyId,
    required String billingMode,
    double? ratePerDelivery,
    double? ratePerKm,
    double? monthlyRetainerAmount,
    int? driversCount,
    int? expectedDeliveriesPerMonth,
    String? coverageNotes,
  }) async {
    if (state.submit.isSubmitting) return false;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));
    final result = await _repo.requestContract(
      fleetCompanyId: fleetCompanyId,
      billingMode: billingMode,
      ratePerDelivery: ratePerDelivery,
      ratePerKm: ratePerKm,
      monthlyRetainerAmount: monthlyRetainerAmount,
      driversCount: driversCount,
      expectedDeliveriesPerMonth: expectedDeliveriesPerMonth,
      coverageNotes: coverageNotes,
    );
    if (isClosed) return false;
    if (result is Ok<FleetContract>) {
      emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
      await load(quiet: true);
      return true;
    }
    emit(state.copyWith(submit: result.failureState));
    return false;
  }

  Future<bool> end(int contractId, {String? reason}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));
    final result = await _repo.endContract(contractId, reason: reason);
    if (isClosed) return false;
    if (result is Ok<FleetContract>) {
      emit(state.copyWith(action: const SubmitState(status: FormStatus.success)));
      await load(quiet: true);
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }
}
