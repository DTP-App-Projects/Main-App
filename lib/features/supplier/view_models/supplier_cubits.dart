import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paged.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/paged_cubit.dart';
import '../../../core/workspace/workspace.dart';
import '../../../data/models/trade/catalog.dart';
import '../../../data/models/trade/delivery_note.dart';
import '../../../data/models/trade/invoice.dart';
import '../../../data/models/trade/pricing.dart';
import '../../../data/models/trade/supplier_summary.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/receivables_repository.dart';
import '../../../data/repositories/shipments_repository.dart';
import '../../../data/repositories/supplier_repository.dart';

// ---------------------------------------------------------------------------
// Catalogue: the supplier writes the rules a trader is judged against
// ---------------------------------------------------------------------------

class SupplierProductsCubit extends PagedCubit<Product> {
  final CatalogRepository _repo;

  String search = '';

  SupplierProductsCubit(this._repo);

  @override
  Future<ApiResult<Paged<Product>>> fetchPage(int page) =>
      _repo.products(page: page, search: search.isEmpty ? null : search);

  Future<void> setSearch(String value) => applyFilter(() => search = value.trim());
}

@immutable
class SkuRulesState {
  final bool loading;
  final Product? product;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const SkuRulesState({
    this.loading = true,
    this.product,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  SkuRulesState copyWith({
    bool? loading,
    Product? product,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      SkuRulesState(
        loading: loading ?? this.loading,
        product: product ?? this.product,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

/// Editing `min_order_qty` / `order_step_qty` here is what produces the
/// trader's `qty_less_than_min_order_qty` and `qty_not_matching_order_step`
/// rejections — the screen says so out loud.
class SkuRulesCubit extends Cubit<SkuRulesState> {
  final CatalogRepository _catalog;
  final SupplierRepository _supplier;
  final int productId;

  SkuRulesCubit(this._catalog, this._supplier, this.productId)
      : super(const SkuRulesState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _catalog.product(productId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, product: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<bool> save({
    required int skuId,
    double? minOrderQty,
    double? orderStepQty,
    double? packQuantity,
    String? skuStatus,
    String? barcode,
    bool? barcodeRequired,
  }) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _supplier.updateSkuRules(
      productId: productId,
      skuId: skuId,
      minOrderQty: minOrderQty,
      orderStepQty: orderStepQty,
      packQuantity: packQuantity,
      skuStatus: skuStatus,
      barcode: barcode,
      barcodeRequired: barcodeRequired,
    );
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<Sku> || result is NoContent<Sku>;
    if (ok) await load();
    return ok;
  }
}

// ---------------------------------------------------------------------------
// Pricing
// ---------------------------------------------------------------------------

class PriceListsCubit extends PagedCubit<PriceList> {
  final SupplierRepository _repo;

  PriceListsCubit(this._repo);

  @override
  Future<ApiResult<Paged<PriceList>>> fetchPage(int page) => _repo.priceLists(page: page);

  /// The form checks [PriceList.scopeNeedsId] before sending, so
  /// `400 scope_id_required_for_selected_scope` never comes back.
  Future<bool> save({
    int? priceListId,
    required String scopeType,
    int? scopeId,
    String? nameAr,
    String? nameEn,
    String? currencyCode,
    String? status,
  }) async {
    if (state.loading) return false;
    final result = await _repo.savePriceList(
      priceListId: priceListId,
      scopeType: scopeType,
      scopeId: scopeId,
      nameAr: nameAr,
      nameEn: nameEn,
      currencyCode: currencyCode,
      status: status,
    );
    if (result is Ok<PriceList> || result is NoContent<PriceList>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }

  Future<bool> addItem({
    required int priceListId,
    required int skuId,
    required double minQty,
    required double unitPrice,
    double? maxQty,
    int? paymentTermId,
    String? discountType,
    double? discountValue,
  }) async {
    final result = await _repo.savePriceItem(
      priceListId: priceListId,
      skuId: skuId,
      minQty: minQty,
      unitPrice: unitPrice,
      maxQty: maxQty,
      paymentTermId: paymentTermId,
      discountType: discountType,
      discountValue: discountValue,
    );
    if (result is Ok<PriceItem> || result is NoContent<PriceItem>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }
}

// ---------------------------------------------------------------------------
// Relationships and credit
// ---------------------------------------------------------------------------

class RelationshipsCubit extends PagedCubit<BusinessRelationship> {
  final SupplierRepository _repo;

  String? status;

  RelationshipsCubit(this._repo);

  @override
  Future<ApiResult<Paged<BusinessRelationship>>> fetchPage(int page) =>
      _repo.relationships(page: page, status: status);

  Future<void> setStatus(String? value) => applyFilter(() => status = value);

  Future<bool> setRelationshipStatus({required int id, required String value}) async {
    final result = await _repo.setRelationshipStatus(id: id, status: value);
    if (result is Ok<BusinessRelationship> || result is NoContent<BusinessRelationship>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }
}

@immutable
class CreditState {
  final bool loading;
  final CreditProfile? profile;
  final CreditExposure? exposure;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const CreditState({
    this.loading = true,
    this.profile,
    this.exposure,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  CreditState copyWith({
    bool? loading,
    CreditProfile? profile,
    CreditExposure? exposure,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      CreditState(
        loading: loading ?? this.loading,
        profile: profile ?? this.profile,
        exposure: exposure ?? this.exposure,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

/// The credit profile is **the supplier's to write**; a trader attempting it
/// gets `403 credit_profile_can_only_be_managed_by_supplier_side`.
class CreditCubit extends Cubit<CreditState> {
  final SupplierRepository _repo;
  final int relationshipId;

  CreditCubit(this._repo, this.relationshipId) : super(const CreditState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.credit(relationshipId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(
        loading: false,
        profile: data.profile,
        exposure: data.exposure,
      ));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<bool> save({
    required String grade,
    required double creditLimit,
    int? maxDueDays,
    int? maxOverdueDays,
    double? upfrontRequiredPercent,
    bool? autoFreezeOnLimit,
    bool? autoFreezeOnOverdue,
    int? reviewCycleDays,
  }) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.saveCredit(
      relationshipId: relationshipId,
      grade: grade,
      creditLimit: creditLimit,
      maxDueDays: maxDueDays,
      maxOverdueDays: maxOverdueDays,
      upfrontRequiredPercent: upfrontRequiredPercent,
      autoFreezeOnLimit: autoFreezeOnLimit,
      autoFreezeOnOverdue: autoFreezeOnOverdue,
      reviewCycleDays: reviewCycleDays,
    );
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<CreditProfile> || result is NoContent<CreditProfile>;
    if (ok) await load();
    return ok;
  }
}

// ---------------------------------------------------------------------------
// Outbound shipments
// ---------------------------------------------------------------------------

class OutboundShipmentsCubit extends PagedCubit<DeliveryNote> {
  final ShipmentsRepository _repo;

  Set<String> statuses = {};

  OutboundShipmentsCubit(this._repo);

  @override
  Future<ApiResult<Paged<DeliveryNote>>> fetchPage(int page) =>
      _repo.deliveryNotes(role: Workspace.supplier, page: page, statuses: statuses.toList());

  Future<void> toggleStatus(String status) => applyFilter(() {
        if (!statuses.remove(status)) statuses.add(status);
      });

  Future<void> clearStatuses() => applyFilter(statuses.clear);
}

@immutable
class DeliveryEditorState {
  final bool loading;
  final DeliveryNote? note;
  final String? errorMessage;
  final bool offline;
  final SubmitState action;

  const DeliveryEditorState({
    this.loading = true,
    this.note,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
  });

  DeliveryEditorState copyWith({
    bool? loading,
    DeliveryNote? note,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    bool clearError = false,
  }) =>
      DeliveryEditorState(
        loading: loading ?? this.loading,
        note: note ?? this.note,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        action: action ?? this.action,
      );
}

/// One shipment, from the supplier's side: seals on, dispatch, cancel,
/// reschedule.
///
/// The order matters and the server enforces it — seals cannot be set after
/// dispatch (`409`), and dispatch is refused without them (`422`).
class DeliveryEditorCubit extends Cubit<DeliveryEditorState> {
  final ShipmentsRepository _repo;
  final int deliveryNoteId;

  DeliveryEditorCubit(this._repo, this.deliveryNoteId)
      : super(const DeliveryEditorState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.deliveryNote(deliveryNoteId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, note: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  Future<bool> setSeals(List<String> seals) =>
      _run(() => _repo.setSeals(id: deliveryNoteId, seals: seals));

  Future<bool> dispatch({String? note}) => _run(
        () => _repo.changeDeliveryStatus(
          id: deliveryNoteId,
          status: 'dispatched',
          note: note,
        ),
      );

  Future<bool> markDelivered({String? proofFile}) => _run(
        () => _repo.changeDeliveryStatus(
          id: deliveryNoteId,
          status: 'delivered',
          proofFile: proofFile,
        ),
      );

  Future<bool> cancel({required String reason, String? note}) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.cancelDelivery(
      id: deliveryNoteId,
      reason: reason,
      note: note,
    );
    emit(state.copyWith(action: result.failureState));

    final ok = result is Ok<void> || result is NoContent<void>;
    if (ok) await load();
    return ok;
  }

  Future<bool> reschedule(DateTime routeDate) =>
      _run(() => _repo.reschedule(id: deliveryNoteId, routeDate: routeDate));

  Future<bool> _run(Future<ApiResult<DeliveryNote>> Function() call) async {
    if (state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await call();
    if (result case Ok(:final data)) {
      emit(state.copyWith(note: data, action: const SubmitState()));
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }
}

// ---------------------------------------------------------------------------
// Money: claims to settle, returns to decide
// ---------------------------------------------------------------------------

/// The supplier side of the invoice list.
class SupplierInvoicesCubit extends PagedCubit<Invoice> {
  final ReceivablesRepository _repo;

  Set<String> statuses = {};

  SupplierInvoicesCubit(this._repo);

  @override
  Future<ApiResult<Paged<Invoice>>> fetchPage(int page) =>
      _repo.invoices(role: Workspace.supplier, page: page, statuses: statuses.toList());

  Future<void> toggleStatus(String status) => applyFilter(() {
        if (!statuses.remove(status)) statuses.add(status);
      });

  Future<void> clearStatuses() => applyFilter(statuses.clear);

  /// Only the supplier may move an instalment. `due_amount` must be at least
  /// 0.01, which the form checks first.
  Future<bool> editDueSchedule({
    required int id,
    DateTime? dueDate,
    double? dueAmount,
  }) async {
    final result = await _repo.updateDueSchedule(
      id: id,
      dueDate: dueDate,
      dueAmount: dueAmount,
    );
    if (result is Ok<DueSchedule> || result is NoContent<DueSchedule>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }
}

@immutable
class IssueInvoiceState {
  final SubmitState action;
  final Invoice? issued;

  const IssueInvoiceState({this.action = const SubmitState(), this.issued});

  IssueInvoiceState copyWith({SubmitState? action, Invoice? issued}) =>
      IssueInvoiceState(action: action ?? this.action, issued: issued ?? this.issued);
}

/// Issuing an invoice is **not auto-retried** — a duplicate is a document the
/// supplier then has to cancel, and it is quota-gated besides.
class IssueInvoiceCubit extends Cubit<IssueInvoiceState> {
  final ReceivablesRepository _repo;

  IssueInvoiceCubit(this._repo) : super(const IssueInvoiceState());

  Future<Invoice?> issue({
    required int purchaseOrderId,
    int? deliveryNoteId,
    DateTime? invoiceDate,
    bool proforma = false,
  }) async {
    if (state.action.isSubmitting) return null;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = proforma
        ? await _repo.issueProforma(
            purchaseOrderId: purchaseOrderId,
            invoiceDate: invoiceDate,
          )
        : await _repo.issueInvoice(
            purchaseOrderId: purchaseOrderId,
            deliveryNoteId: deliveryNoteId,
            invoiceDate: invoiceDate,
          );

    if (result case Ok(:final data)) {
      emit(state.copyWith(
        issued: data,
        action: const SubmitState(status: FormStatus.success),
      ));
      return data;
    }
    emit(state.copyWith(action: result.failureState));
    return null;
  }
}

class CollectionsInboxCubit extends PagedCubit<CollectionReceipt> {
  final ReceivablesRepository _repo;

  String? status;

  CollectionsInboxCubit(this._repo);

  @override
  Future<ApiResult<Paged<CollectionReceipt>>> fetchPage(int page) =>
      _repo.collections(page: page, status: status);

  Future<void> setStatus(String? value) => applyFilter(() => status = value);

  /// Settling a trader claim. A full settlement fires `invoice.paid`.
  Future<bool> decide({required int id, required String status}) async {
    final result = await _repo.decideCollection(id: id, status: status);
    if (result is Ok<CollectionReceipt> || result is NoContent<CollectionReceipt>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }
}

class ReturnsInboxCubit extends PagedCubit<PostInvoiceReturn> {
  final ReceivablesRepository _repo;

  String? status;

  ReturnsInboxCubit(this._repo);

  @override
  Future<ApiResult<Paged<PostInvoiceReturn>>> fetchPage(int page) =>
      _repo.returns(page: page, status: status);

  Future<void> setStatus(String? value) => applyFilter(() => status = value);

  /// Approving issues the credit note. The transitions each side may make
  /// differ, hence `403 post_invoice_return_transition_not_allowed_for_role`.
  Future<bool> decide({
    required int id,
    required String status,
    String? reason,
  }) async {
    final result = await _repo.decideReturn(id: id, status: status, reason: reason);
    if (result is Ok<PostInvoiceReturn> || result is NoContent<PostInvoiceReturn>) {
      await load();
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureMessage));
    return false;
  }
}
