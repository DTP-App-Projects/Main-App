import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/models/ops/ops_panel.dart';
import '../../../../data/repositories/ops_repository.dart';

@immutable
class OpsPanelState {
  final bool loading;
  final OpsPanel? panel;
  final String? errorMessage;
  final bool offline;

  const OpsPanelState({
    this.loading = true,
    this.panel,
    this.errorMessage,
    this.offline = false,
  });

  OpsPanelState copyWith({
    bool? loading,
    OpsPanel? panel,
    String? errorMessage,
    bool? offline,
    bool clearError = false,
  }) =>
      OpsPanelState(
        loading: loading ?? this.loading,
        panel: panel ?? this.panel,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
      );
}

/// The home screen, in one call.
///
/// The workspace is passed explicitly on every fetch — the server's default
/// for `hybrid` is the *supplier* panel, so an omitted param silently shows a
/// trader the wrong home.
class OpsPanelCubit extends Cubit<OpsPanelState> {
  final OpsRepository _repo;
  final WorkspaceCubit _workspace;
  final Workspace _side;

  OpsPanelCubit(this._repo, this._workspace, this._side) : super(const OpsPanelState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.panel(_side);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, panel: data));
      // The panel carries the live palette, so the shell recolours from the
      // same response rather than making a second call for it.
      if (_workspace.state?.active == _side) _workspace.applyTheme(data.theme);
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }
}
