import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../data/models/trade/catalog.dart';
import '../../../../data/models/trade/supplier_summary.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/models/compliance/relationship_request.dart';

/// `GET /v2/catalog/suppliers` — search is debounced by the view; this only
/// holds the current term.
class SuppliersCubit extends PagedCubit<SupplierSummary> {
  final CatalogRepository _repo;

  String search = '';

  SuppliersCubit(this._repo);

  @override
  Future<ApiResult<Paged<SupplierSummary>>> fetchPage(int page) =>
      _repo.suppliers(page: page, search: search.isEmpty ? null : search);

  Future<void> setSearch(String value) => applyFilter(() => search = value.trim());

  /// Swaps in the row the detail screen came back with — a request sent
  /// there shows here at once, without re-reading the whole list.
  void replace(SupplierSummary updated) {
    final page = state.page;
    if (!page.items.any((s) => s.id == updated.id)) return;
    emit(state.copyWith(
      page: Paged(
        items: [for (final s in page.items) s.id == updated.id ? updated : s],
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        perPage: page.perPage,
        total: page.total,
        unreadCount: page.unreadCount,
      ),
    ));
  }
}

@immutable
class SupplierDetailState {
  final bool loading;
  final SupplierSummary? supplier;
  final String? errorMessage;
  final bool offline;

  /// The pre-relationship browse, so a trader can see what is on offer before
  /// being approved.
  final List<Product> publicCatalog;

  final bool isFollowing;
  final SubmitState action;

  const SupplierDetailState({
    this.loading = true,
    this.supplier,
    this.errorMessage,
    this.offline = false,
    this.publicCatalog = const [],
    this.isFollowing = false,
    this.action = const SubmitState(),
  });

  SupplierDetailState copyWith({
    bool? loading,
    SupplierSummary? supplier,
    String? errorMessage,
    bool? offline,
    List<Product>? publicCatalog,
    bool? isFollowing,
    SubmitState? action,
    bool clearError = false,
  }) =>
      SupplierDetailState(
        loading: loading ?? this.loading,
        supplier: supplier ?? this.supplier,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        publicCatalog: publicCatalog ?? this.publicCatalog,
        isFollowing: isFollowing ?? this.isFollowing,
        action: action ?? this.action,
      );
}

class SupplierDetailCubit extends Cubit<SupplierDetailState> {
  final CatalogRepository _repo;
  final int supplierOrganizationId;

  SupplierDetailCubit(this._repo, this.supplierOrganizationId)
      : super(const SupplierDetailState());

  /// Three reads in sequence rather than a fan-out: the global budget is 60
  /// requests a minute and a screen load should not spend three of them at
  /// once.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final supplier = await _repo.supplier(supplierOrganizationId);
    if (supplier case Ok(:final data)) {
      emit(state.copyWith(loading: false, supplier: data));
    } else {
      emit(state.copyWith(
        loading: false,
        offline: supplier.isOffline,
        errorMessage: supplier.failureMessage,
      ));
      return;
    }

    final following = await _repo.isFollowing(supplierOrganizationId);
    if (following case Ok(:final data)) emit(state.copyWith(isFollowing: data));

    final catalog = await _repo.publicCatalog(supplierOrganizationId);
    if (catalog case Ok(:final data)) emit(state.copyWith(publicCatalog: data));
  }

  Future<void> toggleFollow() async {
    final next = !state.isFollowing;
    // Optimistic: following is cheap to undo and the tap should feel instant.
    emit(state.copyWith(isFollowing: next));

    final result = await _repo.setFollowing(supplierOrganizationId, next);
    if (result case Ok(:final data)) {
      emit(state.copyWith(isFollowing: data));
      return;
    }
    emit(state.copyWith(isFollowing: !next, action: result.failureState));
  }

  /// Asks the supplier to open a trading relationship on the supply model the
  /// trader chose. Ordering stays blocked until the supplier's signatory
  /// accepts it **and** a contract is active.
  Future<void> requestRelationship(RelationshipRequestDraft draft) async {
    if (state.action.isSubmitting) return;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.requestRelationship(
      counterpartyOrganizationId: supplierOrganizationId,
      role: 'trader',
      requestedModel: draft.model,
      creditTermDays: draft.creditTermDays,
      creditLimit: draft.creditLimit,
      debtDocumentation: draft.debtDocumentation,
      notes: draft.notes,
    );
    emit(state.copyWith(action: result.failureState));

    if (result is Ok || result is NoContent) {
      // `order_entry_ready` and `relationship_status` both change here.
      await load();
    }
  }
}
