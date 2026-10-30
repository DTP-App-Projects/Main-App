import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paged.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/paged_cubit.dart';

/// A paginated compliance list, given only how to fetch a page. The list
/// behaviour (skeleton, refresh, infinite scroll, empty) is [PagedCubit]'s.
class FetchPagedCubit<T> extends PagedCubit<T> {
  final Future<ApiResult<Paged<T>>> Function(int page) _fetch;

  FetchPagedCubit(this._fetch);

  @override
  Future<ApiResult<Paged<T>>> fetchPage(int page) => _fetch(page);
}

@immutable
class DetailState<T> {
  final bool loading;
  final T? data;
  final String? errorMessage;
  final bool offline;

  /// The last action on the document (accept, reject, send, …).
  final SubmitState action;

  /// The stable code of the last failed action, for the screen to branch on
  /// (e.g. guide to the framework agreement on `framework_agreement_required`).
  final String actionCode;

  const DetailState({
    this.loading = true,
    this.data,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
    this.actionCode = '',
  });

  DetailState<T> copyWith({
    bool? loading,
    T? data,
    String? errorMessage,
    bool clearError = false,
    bool? offline,
    SubmitState? action,
    String? actionCode,
  }) =>
      DetailState<T>(
        loading: loading ?? this.loading,
        data: data ?? this.data,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
        actionCode: actionCode ?? this.actionCode,
      );
}

/// One compliance document: load it, run an action on it, reload.
class DetailCubit<T> extends Cubit<DetailState<T>> {
  final Future<ApiResult<T>> Function() _fetch;

  DetailCubit(this._fetch) : super(DetailState<T>());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));
    final result = await _fetch();
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, data: data));
      return;
    }
    emit(state.copyWith(loading: false, offline: result.isOffline, errorMessage: result.failureMessage));
  }

  /// Runs [call]; on success reloads the document and resolves `true`.
  /// A failure stays on screen as the action message, with its code kept in
  /// [DetailState.actionCode].
  Future<bool> run(Future<ApiResult<Object?>> Function() call, {String? successMessage}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting), actionCode: ''));
    final result = await call();
    if (isClosed) return false;
    if (result is Ok || result is NoContent) {
      emit(state.copyWith(
        action: SubmitState(status: FormStatus.success, message: successMessage),
        actionCode: '',
      ));
      await load();
      return true;
    }
    emit(state.copyWith(action: result.failureState, actionCode: result.failureCode));
    return false;
  }

  /// After an action that ran elsewhere (the OTP sheet posts on its own).
  Future<void> succeeded(String? message) async {
    emit(state.copyWith(action: SubmitState(status: FormStatus.success, message: message), actionCode: ''));
    await load();
  }
}
