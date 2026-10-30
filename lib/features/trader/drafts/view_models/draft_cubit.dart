import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../data/models/trade/catalog.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/orders_repository.dart';

@immutable
class DraftState {
  final bool loading;
  final PurchaseDraft? draft;
  final String? errorMessage;
  final bool offline;

  /// The draft-level form: header edits and submit.
  final SubmitState action;

  /// A rejection that belongs to the line the user just tried to add, shown
  /// against that line rather than as a page-level error.
  final String? lineError;

  final bool addingLine;

  /// Set once the draft has become an order.
  final PurchaseOrder? submitted;

  final List<PaymentTerm> paymentTerms;

  /// The `credit_review` of the submit — a `failed` / `manual_review` one
  /// means the order exists but is on credit hold.
  final CreditReview? creditReview;

  /// Every `errors[]` entry of a refused submit, each shown, and the line
  /// with its `sku_id` highlighted.
  final List<SubmitRuleError> ruleErrors;

  /// The stable code of the last refused submit, for the guided refusals
  /// (framework agreement not signed yet).
  final String actionCode;

  const DraftState({
    this.creditReview,
    this.ruleErrors = const [],
    this.actionCode = '',
    this.loading = true,
    this.draft,
    this.errorMessage,
    this.offline = false,
    this.action = const SubmitState(),
    this.lineError,
    this.addingLine = false,
    this.submitted,
    this.paymentTerms = const [],
  });

  DraftState copyWith({
    bool? loading,
    PurchaseDraft? draft,
    String? errorMessage,
    bool? offline,
    SubmitState? action,
    String? lineError,
    bool? addingLine,
    PurchaseOrder? submitted,
    List<PaymentTerm>? paymentTerms,
    CreditReview? creditReview,
    List<SubmitRuleError>? ruleErrors,
    String? actionCode,
    bool clearError = false,
    bool clearLineError = false,
  }) => DraftState(
    creditReview: creditReview ?? this.creditReview,
    ruleErrors: ruleErrors ?? this.ruleErrors,
    actionCode: actionCode ?? this.actionCode,
    loading: loading ?? this.loading,
    draft: draft ?? this.draft,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    action: action ?? this.action,
    lineError: clearLineError ? null : (lineError ?? this.lineError),
    addingLine: addingLine ?? this.addingLine,
    submitted: submitted ?? this.submitted,
    paymentTerms: paymentTerms ?? this.paymentTerms,
  );
}

/// Draft → purchase order, the trader's core flow.
///
/// Two rules shape this cubit:
/// * **Resolve the price before adding a line.** A SKU with no matching rule
///   cannot be ordered, and the server would reject the add anyway.
/// * **Submit is never auto-retried.** A submit that times out may have
///   created the order; the user re-checks the list instead.
class DraftCubit extends Cubit<DraftState> {
  final OrdersRepository _orders;
  final CatalogRepository _catalog;

  final int supplierOrganizationId;
  final int? relationshipId;

  int? _draftId;

  DraftCubit(
    this._orders,
    this._catalog, {
    required this.supplierOrganizationId,
    this.relationshipId,
    int? draftId,
  }) : _draftId = draftId,
       super(const DraftState());

  int? get draftId => _draftId;

  /// Opens an existing draft, or creates one for this supplier. The create is
  /// an upsert, so a retry after a dropped response reuses the same draft
  /// rather than starting a second basket.
  Future<void> start() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final existing = _draftId;
    final result = existing != null
        ? await _orders.draft(existing)
        : await _orders.saveDraft(
            supplierOrganizationId: supplierOrganizationId,
            relationshipId: relationshipId,
          );

    if (result case Ok(:final data)) {
      _draftId = data.id;
      emit(state.copyWith(loading: false, draft: data));
      await _loadPaymentTerms();
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

  Future<void> _loadPaymentTerms() async {
    final result = await _catalog.paymentTerms();
    if (result case Ok(:final data)) emit(state.copyWith(paymentTerms: data));
  }

  /// Header fields: payment term, delivery branch, notes. An upsert again —
  /// so every field the draft already has is sent back with the change.
  /// Sending only the edited one could clear the rest, the contract the
  /// guided order chose included.
  Future<void> updateHeader({int? paymentTermId, int? deliveryBranchId, String? notes}) async {
    final id = _draftId;
    if (id == null || state.action.isSubmitting) return;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final current = state.draft;
    final result = await _orders.saveDraft(
      draftId: id,
      supplierOrganizationId: supplierOrganizationId,
      relationshipId: relationshipId,
      paymentTermId: paymentTermId ?? current?.paymentTermId,
      deliveryBranchId: deliveryBranchId ?? current?.deliveryBranchId,
      contractId: current?.contractId,
      notes: notes ?? (current?.notes.isEmpty ?? true ? null : current!.notes),
    );
    if (result case Ok(:final data)) {
      emit(state.copyWith(draft: data, action: const SubmitState()));
      return;
    }
    emit(state.copyWith(action: result.failureState));
  }

  /// Adds a line, after checking the two things that would otherwise waste
  /// the user's attempt: the SKU's own quantity rules, and whether a price
  /// rule applies at all.
  ///
  /// Returns the failing error code, or `null` on success.
  Future<String?> addLine({required Sku sku, required double qty}) async {
    final id = _draftId;
    if (id == null || state.addingLine) return null;

    // 1. The rules the SKU itself publishes. Same codes the server uses, so
    //    the message is identical whichever side catches it.
    final localRejection = sku.validateQty(qty);
    if (localRejection != null) {
      emit(state.copyWith(lineError: ErrorMessages.forCode(localRejection)));
      return localRejection;
    }

    emit(state.copyWith(addingLine: true, clearLineError: true));

    // 2. The price that applies to this trader, for this quantity.
    final pricing = await _catalog.resolvePrice(
      skuId: sku.id,
      qty: qty,
      paymentTermId: state.draft?.paymentTermId,
      relationshipId: relationshipId,
    );
    if (pricing case Ok(:final data) when !data.canOrder) {
      emit(
        state.copyWith(
          addingLine: false,
          lineError: ErrorMessages.forCode('pricing_not_found_for_sku'),
        ),
      );
      return 'pricing_not_found_for_sku';
    }

    // 3. The add itself. Its rejections are per-line and specific.
    final result = await _orders.addLine(draftId: id, skuId: sku.id, qty: qty);
    if (result case Ok(:final data)) {
      emit(state.copyWith(addingLine: false, draft: data, clearLineError: true));
      return null;
    }

    final code = result is Failed<PurchaseDraft> ? result.code : null;
    emit(state.copyWith(addingLine: false, lineError: result.failureMessage));
    // The draft may still have changed; re-read rather than guess.
    await _reload();
    return code;
  }

  Future<void> removeLine(int lineId) async {
    final id = _draftId;
    if (id == null) return;

    final result = await _orders.removeLine(draftId: id, lineId: lineId);
    if (result is Ok || result is NoContent) {
      await _reload();
      return;
    }
    emit(state.copyWith(lineError: result.failureMessage));
  }

  /// **Not auto-retried.** On any failure the user is shown what happened and
  /// re-checks the order list themselves. Notes typed but not yet saved are
  /// saved first, with the rest of the header.
  ///
  /// A delivery branch is required (the server refuses with
  /// `delivery_branch_required`), so a draft without one is stopped here.
  Future<PurchaseOrder?> submit({String? notes}) async {
    final id = _draftId;
    if (id == null || state.action.isSubmitting) return null;
    final draft = state.draft;
    if (draft != null && draft.deliveryBranchId == null) {
      emit(
        state.copyWith(
          actionCode: 'delivery_branch_required',
          ruleErrors: const [],
          action: SubmitState(
            status: FormStatus.failure,
            message: ErrorMessages.forCode('delivery_branch_required'),
          ),
        ),
      );
      return null;
    }
    if (notes != null && draft != null && notes.trim() != draft.notes) {
      await updateHeader(notes: notes.trim());
      if (state.action.status == FormStatus.failure) return null;
    }
    emit(
      state.copyWith(
        action: const SubmitState(status: FormStatus.submitting),
        ruleErrors: const [],
        actionCode: '',
      ),
    );

    final result = await _orders.submitDraft(id);
    if (result case Ok(:final data)) {
      emit(
        state.copyWith(
          submitted: data.order,
          creditReview: data.creditReview,
          action: const SubmitState(status: FormStatus.success),
        ),
      );
      return data.order;
    }
    final details = result is Failed<DraftSubmitResult> ? result.details : null;
    emit(
      state.copyWith(
        action: result.failureState,
        actionCode: result.failureCode,
        ruleErrors: SubmitRuleError.listFrom(details),
      ),
    );
    // The server may have re-priced or attached a contract; show its draft.
    await _reload();
    return null;
  }

  /// The submit's rule errors about [skuId]'s line.
  List<SubmitRuleError> errorsForSku(int skuId) => [
    for (final e in state.ruleErrors)
      if (e.skuId == skuId) e,
  ];

  Future<void> _reload() async {
    final id = _draftId;
    if (id == null) return;
    final result = await _orders.draft(id);
    if (result case Ok(:final data)) emit(state.copyWith(draft: data));
  }

  void clearLineError() => emit(state.copyWith(clearLineError: true));
}
