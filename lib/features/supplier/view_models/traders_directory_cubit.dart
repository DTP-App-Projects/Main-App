import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/ui/form_status.dart';
import '../../../data/models/compliance/relationship_request.dart';
import '../../../data/models/trade/supplier_summary.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/supplier_repository.dart';

@immutable
class TradersDirectoryState {
  final bool loading;
  final List<TraderSummary> traders;
  final String? errorMessage;
  final bool offline;
  final String search;

  /// The trader a request is being sent to, for the button's spinner.
  final int? requestingId;
  final SubmitState action;

  const TradersDirectoryState({
    this.loading = true,
    this.traders = const [],
    this.errorMessage,
    this.offline = false,
    this.search = '',
    this.requestingId,
    this.action = const SubmitState(),
  });

  TradersDirectoryState copyWith({
    bool? loading,
    List<TraderSummary>? traders,
    String? errorMessage,
    bool? offline,
    String? search,
    int? requestingId,
    bool clearRequesting = false,
    SubmitState? action,
    bool clearError = false,
  }) =>
      TradersDirectoryState(
        loading: loading ?? this.loading,
        traders: traders ?? this.traders,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        search: search ?? this.search,
        requestingId: clearRequesting ? null : (requestingId ?? this.requestingId),
        action: action ?? this.action,
      );
}

/// «دليل التجار» (guide Part 6.1): the supplier finds a trader and asks for a
/// relationship — the supplier side of what the trader's supplier list does.
class TradersDirectoryCubit extends Cubit<TradersDirectoryState> {
  final SupplierRepository _repo;
  final CatalogRepository _catalog;

  TradersDirectoryCubit(this._repo, this._catalog) : super(const TradersDirectoryState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));
    final result = await _repo.traders(search: state.search);
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, traders: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<void> setSearch(String value) async {
    final search = value.trim();
    if (search == state.search) return;
    emit(state.copyWith(search: search));
    await load();
  }

  /// Sends the request on the chosen supply model (role `supplier`: this
  /// side sells), then re-reads the row so it reads "Request sent".
  Future<bool> requestRelationship(TraderSummary trader, RelationshipRequestDraft draft) async {
    if (state.requestingId != null) return false;
    emit(state.copyWith(requestingId: trader.id, action: const SubmitState(status: FormStatus.submitting)));

    final result = await _catalog.requestRelationship(
      counterpartyOrganizationId: trader.id,
      role: 'supplier',
      requestedModel: draft.model,
      creditTermDays: draft.creditTermDays,
      creditLimit: draft.creditLimit,
      debtDocumentation: draft.debtDocumentation,
      notes: draft.notes,
    );
    if (isClosed) return false;

    final ok = result is Ok || result is NoContent;
    emit(state.copyWith(clearRequesting: true, action: result.failureState));
    if (ok) await load();
    return ok;
  }
}
