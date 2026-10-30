import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paged.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/paged_cubit.dart';
import '../../../data/models/fleet/van_trip.dart';
import '../../../data/repositories/fleet_repository.dart';

/// «البيع المتجول» — the trips list. The same answer carries the per-status
/// counts (the filter chips) and the cash still out on the road.
class VanTripsCubit extends PagedCubit<VanTrip> {
  final FleetRepository _repo;

  String? status;

  /// From the last page read; the chips and the summary card show these.
  Map<String, int> counts = const {};
  double cashOnRoad = 0;

  VanTripsCubit(this._repo);

  @override
  Future<ApiResult<Paged<VanTrip>>> fetchPage(int page) async {
    final result = await _repo.vanTrips(status: status, page: page);
    if (result case Ok(:final data)) {
      // Set before the page is emitted, so the rebuild sees them.
      counts = data.counts;
      cashOnRoad = data.cashOnRoad;
      return Ok(data.page);
    }
    return result.castFailure<Paged<VanTrip>>();
  }

  Future<void> filter(String? value) => applyFilter(() => status = value);
}

@immutable
class VanTripState {
  final bool loading;
  final VanTripDetail? detail;
  final String? errorMessage;
  final bool offline;

  /// Cancel / reconcile.
  final SubmitState action;

  const VanTripState({
    this.loading = true,
    this.detail,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  VanTrip? get trip => detail?.trip;

  VanTripState copyWith({
    bool? loading,
    VanTripDetail? detail,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) => VanTripState(
    loading: loading ?? this.loading,
    detail: detail ?? this.detail,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    action: action ?? this.action,
  );
}

/// One trip. While the van is `on_road` the figures are re-read every
/// [pollEvery] (three requests a minute of the app's 60); a status change
/// seen by the poll re-reads the whole trip — the driver ended it, and the
/// screen turns into the reconciliation form.
class VanTripCubit extends Cubit<VanTripState> {
  final FleetRepository _repo;
  final int tripId;
  final Duration pollEvery;

  Timer? _poll;
  bool _polling = false;

  VanTripCubit(this._repo, this.tripId, {this.pollEvery = const Duration(seconds: 20)})
    : super(const VanTripState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.vanTrip(tripId);
    if (isClosed) return;
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, detail: data));
      _schedulePoll();
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

  void _schedulePoll() {
    final onRoad = state.trip?.isOnRoad ?? false;
    if (onRoad && _poll == null) {
      _poll = Timer.periodic(pollEvery, (_) => refreshFigures());
    } else if (!onRoad) {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// The light poll. A failed tick is silent — the next one will try again,
  /// and the figures on screen stay as they were.
  Future<void> refreshFigures() async {
    final detail = state.detail;
    if (detail == null || _polling || state.loading || state.action.isSubmitting) return;
    _polling = true;
    final result = await _repo.vanTripFigures(tripId);
    _polling = false;
    if (isClosed) return;
    if (result case Ok(:final data)) {
      if (data.status != detail.trip.status) {
        await load();
        return;
      }
      emit(state.copyWith(detail: detail.copyWith(trip: detail.trip.withFigures(data))));
    }
  }

  Future<bool> cancel() => _run(() => _repo.cancelVanTrip(tripId));

  Future<bool> reconcile({
    required String returnCode,
    required double cashHandedOver,
    String? varianceReason,
    required List<VanReturnLineInput> lines,
  }) => _run(
    () => _repo.reconcileVanTrip(
      tripId,
      returnCode: returnCode,
      cashHandedOver: cashHandedOver,
      varianceReason: varianceReason,
      lines: lines,
    ),
  );

  /// The answer carries the trip only; sales and deliveries are re-read with
  /// it so the read-only summary is complete.
  Future<bool> _run(Future<ApiResult<VanTrip>> Function() call) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await call();
    if (isClosed) return false;
    if (result is Ok<VanTrip>) {
      emit(state.copyWith(action: const SubmitState(status: FormStatus.success)));
      await load();
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}

/// One line of the load sheet being built.
@immutable
class VanLoadDraftLine {
  final VanStockItem item;
  final double qty;
  final double? unitPrice;

  const VanLoadDraftLine({required this.item, this.qty = 0, this.unitPrice});

  VanLoadDraftLine copyWith({double? qty, double? unitPrice, bool clearPrice = false}) =>
      VanLoadDraftLine(
        item: item,
        qty: qty ?? this.qty,
        unitPrice: clearPrice ? null : (unitPrice ?? this.unitPrice),
      );
}

@immutable
class VanLoadSheetState {
  final bool loading;
  final VanFormOptions? options;
  final String? errorMessage;
  final bool offline;
  final int? driverId;
  final int? vehicleId;
  final int? warehouseId;
  final List<VanLoadDraftLine> lines;
  final SubmitState submit;

  const VanLoadSheetState({
    this.loading = true,
    this.options,
    this.errorMessage,
    this.offline = false,
    this.driverId,
    this.vehicleId,
    this.warehouseId,
    this.lines = const [],
    this.submit = const SubmitState(),
  });

  VanWarehouse? get warehouse {
    for (final w in options?.warehouses ?? const <VanWarehouse>[]) {
      if (w.id == warehouseId) return w;
    }
    return null;
  }

  /// The selected warehouse's stock not on the sheet yet.
  List<VanStockItem> get pickable {
    final taken = {for (final l in lines) l.item.skuId};
    return [
      for (final s in warehouse?.stock ?? const <VanStockItem>[])
        if (!taken.contains(s.skuId) && s.availableQty > 0) s,
    ];
  }

  bool get canSubmit =>
      driverId != null &&
      warehouseId != null &&
      lines.any((l) => l.qty > 0) &&
      !submit.isSubmitting;

  VanLoadSheetState copyWith({
    bool? loading,
    VanFormOptions? options,
    String? errorMessage,
    bool? offline,
    int? driverId,
    int? vehicleId,
    int? warehouseId,
    List<VanLoadDraftLine>? lines,
    SubmitState? submit,
    bool clearError = false,
    bool clearVehicle = false,
  }) => VanLoadSheetState(
    loading: loading ?? this.loading,
    options: options ?? this.options,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    driverId: driverId ?? this.driverId,
    vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
    warehouseId: warehouseId ?? this.warehouseId,
    lines: lines ?? this.lines,
    submit: submit ?? this.submit,
  );
}

/// «إنشاء ورقة تحميل»: driver, vehicle, warehouse, then items out of that
/// warehouse's stock — never more than `available_qty`.
class VanLoadSheetCubit extends Cubit<VanLoadSheetState> {
  final FleetRepository _repo;

  VanLoadSheetCubit(this._repo) : super(const VanLoadSheetState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));
    final result = await _repo.vanFormOptions();
    if (isClosed) return;
    if (result case Ok(:final data)) {
      // The default warehouse is the usual one; preselect it.
      int? warehouseId;
      for (final w in data.warehouses) {
        if (w.place.isDefault) warehouseId = w.id;
      }
      if (warehouseId == null && data.warehouses.length == 1) {
        warehouseId = data.warehouses.first.id;
      }
      emit(state.copyWith(loading: false, options: data, warehouseId: warehouseId));
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

  /// Picks the driver's own vehicle when it is free (in the list).
  void chooseDriver(int? id) {
    VanDriverOption? driver;
    for (final d in state.options?.drivers ?? const <VanDriverOption>[]) {
      if (d.id == id) driver = d;
    }
    final preferred = driver?.defaultVehicleId;
    final free =
        preferred != null &&
        (state.options?.vehicles ?? const <VanVehicleOption>[]).any((v) => v.id == preferred);
    emit(state.copyWith(driverId: id, vehicleId: free ? preferred : null, clearVehicle: !free));
  }

  void chooseVehicle(int? id) => emit(state.copyWith(vehicleId: id, clearVehicle: id == null));

  /// Another warehouse has other stock: the lines picked from the old one go.
  void chooseWarehouse(int? id) {
    if (id == null || id == state.warehouseId) return;
    emit(state.copyWith(warehouseId: id, lines: const []));
  }

  void addItem(VanStockItem item) {
    if (state.lines.any((l) => l.item.skuId == item.skuId)) return;
    emit(
      state.copyWith(
        lines: [
          ...state.lines,
          VanLoadDraftLine(item: item),
        ],
      ),
    );
  }

  void removeItem(int skuId) => emit(
    state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.item.skuId != skuId) l,
      ],
    ),
  );

  /// Clamped to what the warehouse holds; returns the value kept.
  double setQty(int skuId, double qty) {
    var kept = qty;
    emit(
      state.copyWith(
        lines: [
          for (final l in state.lines)
            if (l.item.skuId == skuId)
              l.copyWith(qty: kept = qty.clamp(0, l.item.availableQty).toDouble())
            else
              l,
        ],
      ),
    );
    return kept;
  }

  void setPrice(int skuId, double? price) => emit(
    state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.item.skuId == skuId) l.copyWith(unitPrice: price, clearPrice: price == null) else l,
      ],
    ),
  );

  /// The created trip (in `draft`, with its load code), or null.
  Future<VanTrip?> submit({double? maxDiscountPercent, String? notes}) async {
    if (!state.canSubmit) return null;
    if (maxDiscountPercent != null && (maxDiscountPercent < 0 || maxDiscountPercent > 100)) {
      emit(
        state.copyWith(
          submit: SubmitState(
            status: FormStatus.failure,
            message: 'van.discount_range'.tr(),
            bag: {
              'max_discount_percent': ['van.discount_range'.tr()],
            },
          ),
        ),
      );
      return null;
    }
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.createLoadSheet(
      driverId: state.driverId!,
      vehicleId: state.vehicleId,
      warehouseBranchId: state.warehouseId!,
      maxDiscountPercent: maxDiscountPercent,
      notes: notes,
      lines: [
        for (final l in state.lines)
          if (l.qty > 0) VanLoadLineInput(skuId: l.item.skuId, qty: l.qty, unitPrice: l.unitPrice),
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

/// Whether the warehouse count disagrees with the trip: any line whose
/// returned + damaged is not what is still on the van, or cash that is not
/// the cash sales total. The server has the final say
/// (`van_variance_reason_required`); this only marks the reason required.
bool vanReconcileHasVariance({
  required List<VanTripLine> lines,
  required Map<int, ({double returned, double damaged})> counted,
  required double expectedCash,
  required double? cash,
}) {
  for (final line in lines) {
    final c = counted[line.skuId];
    final total = (c?.returned ?? 0) + (c?.damaged ?? 0);
    if ((total - line.inVan).abs() > 0.0005) return true;
  }
  return cash != null && (cash - expectedCash).abs() > 0.005;
}
