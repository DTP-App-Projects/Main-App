import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../error/api_failure_ui.dart';
import '../network/api_result.dart';
import 'form_status.dart';

@immutable
class CollectionState<T> {
  final bool loading;
  final List<T> items;

  /// Localized; `null` when the last load succeeded.
  final String? errorMessage;

  /// Offline is a different state from an error — different copy, different
  /// affordance.
  final bool offline;

  /// The inline add/edit form living on the same screen as the list.
  final SubmitState submit;

  const CollectionState({
    this.loading = true,
    this.items = const [],
    this.errorMessage,
    this.offline = false,
    this.submit = const SubmitState(),
  });

  bool get isEmpty => !loading && items.isEmpty && errorMessage == null;

  CollectionState<T> copyWith({
    bool? loading,
    List<T>? items,
    String? errorMessage,
    bool? offline,
    SubmitState? submit,
    bool clearError = false,
  }) =>
      CollectionState<T>(
        loading: loading ?? this.loading,
        items: items ?? this.items,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        submit: submit ?? this.submit,
      );
}

/// "List some rows, then upsert one" is the same screen three times over in
/// onboarding — branches, bank accounts, documents. The shape lives here.
///
/// Every write these drive is an **idempotent upsert**, so a retry after a
/// dropped response updates rather than duplicating.
abstract class CollectionCubit<T> extends Cubit<CollectionState<T>> {
  CollectionCubit() : super(CollectionState<T>());

  Future<ApiResult<List<T>>> fetchAll();

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await fetchAll();
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, items: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  /// Runs an upsert, maps its failure onto the form, and reloads the list on
  /// success. Returns true when the row was saved.
  Future<bool> submit(Future<ApiResult<T>> Function() call) async {
    if (state.submit.isSubmitting) return false;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await call();
    if (result is Ok<T> || result is NoContent<T>) {
      emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
      await load();
      return true;
    }
    emit(state.copyWith(submit: result.failureState));
    return false;
  }

  void resetForm() => emit(state.copyWith(submit: const SubmitState()));
}
