import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../data/models/compliance/terms.dart';
import '../../../../data/repositories/compliance_repository.dart';

@immutable
class TermsGateState {
  final bool loading;
  final TermsStatus status;
  final SubmitState submit;

  /// The upcoming-version banner was closed this session. It comes back on
  /// the next start, and for good once the version is in force (then it is
  /// the gate, not a banner).
  final bool bannerDismissed;

  const TermsGateState({
    this.loading = false,
    this.status = TermsStatus.empty,
    this.submit = const SubmitState(),
    this.bannerDismissed = false,
  });

  bool get showBanner => !bannerDismissed && status.upcoming.isNotEmpty;

  TermsGateState copyWith({
    bool? loading,
    TermsStatus? status,
    SubmitState? submit,
    bool? bannerDismissed,
  }) =>
      TermsGateState(
        loading: loading ?? this.loading,
        status: status ?? this.status,
        submit: submit ?? this.submit,
        bannerDismissed: bannerDismissed ?? this.bannerDismissed,
      );
}

/// Session-scoped: the terms status is read on start and after login, and
/// drives both the blocking screen and the 7-day notice banner.
class TermsCubit extends Cubit<TermsGateState> {
  final ComplianceRepository _repo;

  TermsCubit(this._repo) : super(const TermsGateState());

  /// Resolves to the fresh status, or `null` when it could not be read —
  /// a failed read never blocks the app: the server's `409` still guards
  /// every write.
  Future<TermsStatus?> load() async {
    emit(state.copyWith(loading: true));
    final result = await _repo.termsStatus();
    if (isClosed) return null;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, status: data));
      return data;
    }
    emit(state.copyWith(loading: false));
    return null;
  }

  /// Level-1 click acceptance of [ids]. Resolves to `true` on success.
  Future<bool> accept(List<int> ids) async {
    if (ids.isEmpty) return false;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));
    final result = await _repo.acceptTerms(ids);
    if (isClosed) return false;
    if (result is Ok || result is NoContent) {
      emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
      await load();
      return true;
    }
    emit(state.copyWith(submit: result.failureState));
    return false;
  }

  void dismissBanner() => emit(state.copyWith(bannerDismissed: true));

  void reset() => emit(const TermsGateState());
}
