import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/ui/form_status.dart';
import '../../../data/models/lookups/lookup_item.dart';
import '../../../data/models/trade/delivery_note.dart';
import '../../../data/models/trade/purchase_order.dart';
import '../../../data/repositories/lookups_repository.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../../data/repositories/shipments_repository.dart';

@immutable
class DeliveryNoteFormState {
  final bool loading;
  final PurchaseOrder? order;
  final List<LookupItem> supplierBranches;
  final int? supplierBranchId;

  /// Quantity to ship per order line, pre-filled with what is still open.
  final Map<int, double> shipQty;
  final String? proofPath;
  final String? errorMessage;
  final bool offline;
  final SubmitState submit;

  const DeliveryNoteFormState({
    this.loading = true,
    this.order,
    this.supplierBranches = const [],
    this.supplierBranchId,
    this.shipQty = const {},
    this.proofPath,
    this.errorMessage,
    this.offline = false,
    this.submit = const SubmitState(),
  });

  DeliveryNoteFormState copyWith({
    bool? loading,
    PurchaseOrder? order,
    List<LookupItem>? supplierBranches,
    int? supplierBranchId,
    Map<int, double>? shipQty,
    String? proofPath,
    bool clearProof = false,
    String? errorMessage,
    bool? offline,
    SubmitState? submit,
    bool clearError = false,
  }) =>
      DeliveryNoteFormState(
        loading: loading ?? this.loading,
        order: order ?? this.order,
        supplierBranches: supplierBranches ?? this.supplierBranches,
        supplierBranchId: supplierBranchId ?? this.supplierBranchId,
        shipQty: shipQty ?? this.shipQty,
        proofPath: clearProof ? null : (proofPath ?? this.proofPath),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        submit: submit ?? this.submit,
      );

  /// What is still open on [line]: ordered minus already shipped.
  static double remaining(PurchaseOrderLine line) {
    final open = line.qty - line.shippedQty;
    return open < 0 ? 0 : open;
  }

  bool get hasSomethingToShip => shipQty.values.any((q) => q > 0);
}

/// «إنشاء إذن تسليم» (guide Part 10.1): from an approved order, ship some or
/// all of what is open, from one of the supplier's branches to the order's
/// delivery branch. The server answers a cash order that is not yet invoiced
/// and paid with its own reason, shown as written.
class DeliveryNoteFormCubit extends Cubit<DeliveryNoteFormState> {
  final OrdersRepository _orders;
  final ShipmentsRepository _shipments;
  final LookupsRepository _lookups;
  final int orderId;

  DeliveryNoteFormCubit(this._orders, this._shipments, this._lookups, this.orderId)
      : super(const DeliveryNoteFormState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));
    final order = await _orders.order(orderId);
    if (isClosed) return;
    if (order is! Ok<PurchaseOrder>) {
      emit(state.copyWith(loading: false, offline: order.isOffline, errorMessage: order.failureMessage));
      return;
    }
    final branches = await _lookups.items(Lookup.branches);
    if (isClosed) return;
    final items = branches.dataOrNull ?? const <LookupItem>[];
    LookupItem? preferred;
    for (final b in items) {
      if (b.raw['is_default'] == true || b.raw['is_default'] == 1) preferred = b;
    }
    preferred ??= items.isEmpty ? null : items.first;

    emit(state.copyWith(
      loading: false,
      order: order.data,
      supplierBranches: items,
      supplierBranchId: preferred?.id,
      shipQty: {for (final line in order.data.lines) line.id: DeliveryNoteFormState.remaining(line)},
    ));
  }

  void chooseBranch(int? id) => emit(state.copyWith(supplierBranchId: id));
  void setProof(String? path) => emit(state.copyWith(proofPath: path, clearProof: path == null));

  /// Never more than what is open on the line, never below zero.
  void setQty(PurchaseOrderLine line, double qty) {
    final max = DeliveryNoteFormState.remaining(line);
    final value = qty < 0 ? 0.0 : (qty > max ? max : qty);
    emit(state.copyWith(shipQty: {...state.shipQty, line.id: value}));
  }

  Future<DeliveryNote?> submit({String? notes}) async {
    final order = state.order;
    if (order == null || state.submit.isSubmitting || !state.hasSomethingToShip) return null;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _shipments.saveDeliveryNote(
      purchaseOrderId: order.id,
      supplierBranchId: state.supplierBranchId,
      traderBranchId: order.deliveryBranchId,
      proofFile: state.proofPath,
      notes: (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      lines: [
        for (final line in order.lines)
          if ((state.shipQty[line.id] ?? 0) > 0)
            DeliveryLineInput(
              purchaseOrderLineId: line.id,
              skuId: line.skuId,
              shippedQty: state.shipQty[line.id]!,
            ),
      ],
    );
    if (isClosed) return null;
    emit(state.copyWith(submit: result.failureState));
    return result.dataOrNull;
  }
}
