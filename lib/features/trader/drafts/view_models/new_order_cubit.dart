import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/coerce.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/models/trade/order_entry.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/models/trade/supplier_summary.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/lookups_repository.dart';
import '../../../../data/repositories/orders_repository.dart';

/// The buying mode — card 1 of the website's «أمر شراء جديد»
/// (`/b2b/order_entry?mode=cash|deferred|installment`).
enum PurchaseMode {
  cash,
  credit,
  installment;

  /// `payment_terms.term_mode` for this mode, and the website's `mode=`.
  String get termMode => switch (this) {
    cash => 'cash',
    credit => 'deferred',
    installment => 'installment',
  };

  /// `contracts.contract_type` values that serve this mode. The API answers
  /// `cash` for a `direct_cash` contract it created (live, 2026-10-06), so
  /// both spellings count. A `framework` agreement is not a pricing contract
  /// and is never offered here — it governs credit when no contract is
  /// chosen.
  Set<String> get contractTypes => switch (this) {
    cash => const {'direct_cash', 'cash'},
    credit => const {'direct_credit', 'credit', 'deferred'},
    installment => const {'installment'},
  };

  /// Cash needs nothing beyond an approved relationship
  /// («يمكن المتابعة كاش بدون عقد»).
  bool get isCredit => this != cash;
}

/// Why a mode is not offered, as the website's ⓘ explains it.
enum ModeBlock {
  /// No approved relationship at all.
  noRelationship,

  /// «Credit limit or due policy is not configured for this relationship.»
  creditNotConfigured,

  /// Credit is configured, but there is no active credit contract and no
  /// framework agreement in force.
  noCreditContract,

  /// «Installments require an active installment contract.»
  noInstallmentContract,
}

@immutable
class NewOrderState {
  final bool loading;
  final String? errorMessage;
  final bool offline;

  final List<LookupItem> paymentTerms;
  final List<LookupItem> branches;
  final List<LookupItem> sectors;

  /// The trader's side of every relationship, and every contract — read once,
  /// so eligibility per mode is counted without a request per choice.
  final List<LookupItem> relationships;
  final List<LookupItem> contracts;

  /// Supplier organization → its sector ids (`/catalog/suppliers`).
  final Map<int, List<NamedRef>> supplierSectors;

  /// Relationship id → its detail (credit terms), for approved ones.
  final Map<int, BusinessRelationship> relationshipDetails;

  final PurchaseMode? mode;
  final int? sectorId;
  final int? paymentTermId;
  final int? branchId;
  final LookupItem? relationship;
  final int? contractId;

  /// Card 4: the orderable SKUs for the current choices, and the quantity
  /// typed against each (by SKU id).
  final bool itemsLoading;
  final List<OrderEntryItem> items;
  final Map<int, double> quantities;

  /// A refusal that belongs to one SKU's line (local rule, add-line or
  /// submit `errors[]`), shown under that SKU.
  final Map<int, String> lineErrors;

  /// The submit's `errors[]` that name no SKU, and its stable code.
  final List<SubmitRuleError> ruleErrors;
  final String actionCode;

  final CreditReview? creditReview;
  final SubmitState action;

  const NewOrderState({
    this.loading = true,
    this.errorMessage,
    this.offline = false,
    this.paymentTerms = const [],
    this.branches = const [],
    this.sectors = const [],
    this.relationships = const [],
    this.contracts = const [],
    this.supplierSectors = const {},
    this.relationshipDetails = const {},
    this.mode,
    this.sectorId,
    this.paymentTermId,
    this.branchId,
    this.relationship,
    this.contractId,
    this.itemsLoading = false,
    this.items = const [],
    this.quantities = const {},
    this.lineErrors = const {},
    this.ruleErrors = const [],
    this.actionCode = '',
    this.creditReview,
    this.action = const SubmitState(),
  });

  NewOrderState copyWith({
    bool? loading,
    String? errorMessage,
    bool? offline,
    List<LookupItem>? paymentTerms,
    List<LookupItem>? branches,
    List<LookupItem>? sectors,
    List<LookupItem>? relationships,
    List<LookupItem>? contracts,
    Map<int, List<NamedRef>>? supplierSectors,
    Map<int, BusinessRelationship>? relationshipDetails,
    PurchaseMode? mode,
    int? sectorId,
    bool clearSector = false,
    int? paymentTermId,
    bool clearPaymentTerm = false,
    int? branchId,
    LookupItem? relationship,
    bool clearRelationship = false,
    int? contractId,
    bool clearContract = false,
    bool? itemsLoading,
    List<OrderEntryItem>? items,
    Map<int, double>? quantities,
    Map<int, String>? lineErrors,
    List<SubmitRuleError>? ruleErrors,
    String? actionCode,
    CreditReview? creditReview,
    SubmitState? action,
    bool clearError = false,
  }) => NewOrderState(
    loading: loading ?? this.loading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    offline: offline ?? this.offline,
    paymentTerms: paymentTerms ?? this.paymentTerms,
    branches: branches ?? this.branches,
    sectors: sectors ?? this.sectors,
    relationships: relationships ?? this.relationships,
    contracts: contracts ?? this.contracts,
    supplierSectors: supplierSectors ?? this.supplierSectors,
    relationshipDetails: relationshipDetails ?? this.relationshipDetails,
    mode: mode ?? this.mode,
    sectorId: clearSector ? null : (sectorId ?? this.sectorId),
    paymentTermId: clearPaymentTerm ? null : (paymentTermId ?? this.paymentTermId),
    branchId: branchId ?? this.branchId,
    relationship: clearRelationship ? null : (relationship ?? this.relationship),
    contractId: clearContract ? null : (contractId ?? this.contractId),
    itemsLoading: itemsLoading ?? this.itemsLoading,
    items: items ?? this.items,
    quantities: quantities ?? this.quantities,
    lineErrors: lineErrors ?? this.lineErrors,
    ruleErrors: ruleErrors ?? this.ruleErrors,
    actionCode: actionCode ?? this.actionCode,
    creditReview: creditReview ?? this.creditReview,
    action: action ?? this.action,
  );

  static const _liveRelationship = {'approved', 'active'};
  static const _liveContract = {'approved', 'active', 'signed'};

  static int? _relationshipIdOf(LookupItem contract) =>
      asIntOrNull(contract.raw['business_relationship_id'] ?? contract.raw['relationship_id']);

  int? supplierIdOf(LookupItem relationship) =>
      asIntOrNull(relationship.raw['supplier_organization_id']);

  /// Approved relationships only: «لا شراء بدون علاقة مقبولة».
  List<LookupItem> get approvedRelationships => [
    for (final r in relationships)
      if (_liveRelationship.contains(r.status)) r,
  ];

  List<LookupItem> _contractsOf(LookupItem relationship) => [
    for (final c in contracts)
      if (_relationshipIdOf(c) == relationship.id && _liveContract.contains(c.status)) c,
  ];

  /// Active contracts of [relationship] that serve [mode].
  List<LookupItem> contractsFor(LookupItem relationship, PurchaseMode mode) => [
    for (final c in _contractsOf(relationship))
      if (mode.contractTypes.contains('${c.raw['contract_type'] ?? ''}')) c,
  ];

  /// The framework agreement in force on [relationship] (`FA-…`), if any.
  LookupItem? frameworkOf(LookupItem relationship) {
    for (final c in _contractsOf(relationship)) {
      if ('${c.raw['contract_type'] ?? ''}' == 'framework') return c;
    }
    return null;
  }

  bool _creditEnabled(LookupItem relationship) =>
      relationshipDetails[relationship.id]?.isCreditEnabled ?? false;

  /// Why [relationship] cannot order in [mode]; `null` when it can.
  ModeBlock? blockFor(LookupItem relationship, PurchaseMode mode) {
    switch (mode) {
      case PurchaseMode.cash:
        return null;
      case PurchaseMode.credit:
        if (!_creditEnabled(relationship)) return ModeBlock.creditNotConfigured;
        // The submit's rule: credit needs an active contract or a signed
        // framework agreement (`contract_required_for_payment_mode`).
        if (contractsFor(relationship, mode).isEmpty && frameworkOf(relationship) == null) {
          return ModeBlock.noCreditContract;
        }
        return null;
      case PurchaseMode.installment:
        if (contractsFor(relationship, mode).isEmpty) return ModeBlock.noInstallmentContract;
        if (!_creditEnabled(relationship)) return ModeBlock.creditNotConfigured;
        return null;
    }
  }

  bool inSector(LookupItem relationship) {
    final sector = sectorId;
    if (sector == null) return true;
    final sectors = supplierSectors[supplierIdOf(relationship)];
    // A supplier whose sectors are unknown is not hidden.
    return sectors == null || sectors.any((s) => s.id == sector);
  }

  /// The suppliers card 2 offers for [mode], in the chosen sector.
  List<LookupItem> eligibleFor(PurchaseMode mode) => [
    for (final r in approvedRelationships)
      if (inSector(r) && blockFor(r, mode) == null) r,
  ];

  /// Why [mode] shows «غير متاح» — the first reason among the sector's
  /// approved suppliers; `null` when it is available.
  ModeBlock? modeBlock(PurchaseMode mode) {
    if (eligibleFor(mode).isNotEmpty) return null;
    final candidates = [
      for (final r in approvedRelationships)
        if (inSector(r)) r,
    ];
    if (candidates.isEmpty) return ModeBlock.noRelationship;
    return blockFor(candidates.first, mode);
  }

  List<LookupItem> termsFor(PurchaseMode mode) => [
    for (final t in paymentTerms)
      if ('${t.raw['term_mode'] ?? ''}' == mode.termMode) t,
  ];

  /// A contract must be chosen: credit / installment with no framework
  /// agreement to govern the order. Cash never needs one.
  bool get contractRequired {
    final m = mode;
    final r = relationship;
    if (m == null || r == null || !m.isCredit) return false;
    if (m == PurchaseMode.installment) return true;
    return frameworkOf(r) == null;
  }

  /// The lines the trader filled in.
  List<OrderEntryItem> get chosenItems => [
    for (final i in items)
      if ((quantities[i.skuId] ?? 0) > 0) i,
  ];

  /// Quantity × current unit price. The final price is set on submit.
  double get estimatedTotal {
    var total = 0.0;
    for (final i in chosenItems) {
      total += (quantities[i.skuId] ?? 0) * i.finalPrice;
    }
    return total;
  }

  String get currencyCode {
    for (final i in items) {
      if (i.currencyCode.isNotEmpty) return i.currencyCode;
    }
    return '';
  }

  bool get canSubmit =>
      mode != null &&
      relationship != null &&
      branchId != null &&
      (!contractRequired || contractId != null) &&
      chosenItems.isNotEmpty;
}

/// «أمر شراء جديد», built like the website's guided page
/// (`/b2b/order_entry`): buying mode & delivery branch → supplier →
/// contract → items, then **one** submit. There is no order-entry endpoint;
/// the same picture is assembled from the lookups the website reads, and the
/// submit is draft → lines → `submit`.
class NewOrderCubit extends Cubit<NewOrderState> {
  final LookupsRepository _lookups;
  final OrdersRepository _orders;
  final CatalogRepository _catalog;

  /// A supplier the user came from, picked as soon as it is eligible.
  final int? preselectedSupplierId;

  /// The draft the submit builds; reused when a submit has to be retried,
  /// so a second attempt never opens a second basket.
  int? _draftId;

  NewOrderCubit(this._lookups, this._orders, this._catalog, {this.preselectedSupplierId})
    : super(const NewOrderState());

  /// The lookups, in sequence — the request budget is per minute.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final terms = await _lookups.items(Lookup.paymentTerms);
    final branches = await _lookups.items(Lookup.branches);
    final relationships = await _lookups.items(
      Lookup.relationships,
      query: const {'my_role': 'trader'},
    );
    final contracts = await _lookups.items(Lookup.contracts);
    final sectors = await _lookups.items(Lookup.businessSectors);
    if (isClosed) return;

    final failed = [
      terms,
      branches,
      relationships,
    ].firstWhere((r) => r is! Ok<List<LookupItem>>, orElse: () => const Ok<List<LookupItem>>([]));
    if (failed is! Ok<List<LookupItem>>) {
      emit(
        state.copyWith(
          loading: false,
          offline: failed.isOffline,
          errorMessage: failed.failureMessage,
        ),
      );
      return;
    }

    final branchItems = branches.dataOrNull ?? const <LookupItem>[];
    LookupItem? defaultBranch;
    for (final b in branchItems) {
      if (asBool(b.raw['is_default'])) defaultBranch = b;
    }
    defaultBranch ??= branchItems.isEmpty ? null : branchItems.first;

    emit(
      state.copyWith(
        paymentTerms: terms.dataOrNull,
        branches: branchItems,
        branchId: defaultBranch?.id,
        relationships: relationships.dataOrNull,
        // No contracts / sectors are valid answers.
        contracts: contracts.dataOrNull ?? const [],
        sectors: sectors.dataOrNull ?? const [],
      ),
    );

    await _loadSuppliersAndCredit();
    if (isClosed) return;
    emit(state.copyWith(loading: false));

    // Start where the website starts: cash, and the supplier the user came
    // from when there is one.
    chooseMode(PurchaseMode.cash);
    LookupItem? preselected;
    for (final r in state.eligibleFor(PurchaseMode.cash)) {
      if (state.supplierIdOf(r) == preselectedSupplierId) preselected = r;
    }
    preselected ??= state.eligibleFor(PurchaseMode.cash).length == 1
        ? state.eligibleFor(PurchaseMode.cash).single
        : null;
    if (preselected != null) await chooseSupplier(preselected);
  }

  /// Each approved supplier's sectors (one page of the directory) and each
  /// approved relationship's credit terms (one detail each). Optional: a
  /// failure leaves credit unavailable and the sector filter open.
  Future<void> _loadSuppliersAndCredit() async {
    final approved = state.approvedRelationships;
    if (approved.isEmpty) return;

    final directory = await _catalog.suppliers(limit: 50);
    final sectors = <int, List<NamedRef>>{};
    for (final s in directory.dataOrNull?.items ?? const <SupplierSummary>[]) {
      sectors[s.id] = s.sectors;
    }

    final details = <int, BusinessRelationship>{};
    for (final r in approved) {
      if (isClosed) return;
      final detail = await _catalog.relationship(r.id);
      if (detail case Ok(:final data)) details[r.id] = data;
    }
    if (isClosed) return;
    emit(state.copyWith(supplierSectors: sectors, relationshipDetails: details));
  }

  // ------------------------------------------------------------ card 1

  /// A mode resets the supplier and contract, as the website's mode links do.
  void chooseMode(PurchaseMode mode) {
    final terms = state.termsFor(mode);
    emit(
      state.copyWith(
        mode: mode,
        paymentTermId: terms.isEmpty ? null : terms.first.id,
        clearPaymentTerm: terms.isEmpty,
        clearRelationship: true,
        clearContract: true,
        items: const [],
        quantities: const {},
        lineErrors: const {},
        ruleErrors: const [],
        actionCode: '',
        action: const SubmitState(),
      ),
    );
    _draftId = null;
  }

  void chooseSector(int? id) {
    final relationship = state.relationship;
    emit(state.copyWith(sectorId: id, clearSector: id == null));
    // The chosen supplier stays only while it is still in the sector.
    if (relationship != null && !state.inSector(relationship)) {
      emit(state.copyWith(clearRelationship: true, clearContract: true, items: const []));
    }
  }

  void chooseBranch(int? id) {
    if (id == null || id == state.branchId) return;
    emit(state.copyWith(branchId: id));
  }

  // ------------------------------------------------------------ card 2

  Future<void> chooseSupplier(LookupItem relationship) async {
    final mode = state.mode;
    if (mode == null) return;
    final contracts = state.contractsFor(relationship, mode);
    _draftId = null;
    emit(
      state.copyWith(
        relationship: relationship,
        // One matching contract is the only sensible choice.
        contractId: contracts.length == 1 ? contracts.first.id : null,
        clearContract: contracts.length != 1,
        quantities: const {},
        lineErrors: const {},
        ruleErrors: const [],
        actionCode: '',
        action: const SubmitState(),
      ),
    );
    await _loadItems();
  }

  // ------------------------------------------------------------ card 3

  Future<void> chooseContract(int? id) async {
    if (id == state.contractId) return;
    emit(state.copyWith(contractId: id, clearContract: id == null));
    // The contract's prices replace the general ones.
    await _loadItems();
  }

  // ------------------------------------------------------------ card 4

  Future<void> choosePaymentTerm(int? id) async {
    if (id == state.paymentTermId) return;
    emit(state.copyWith(paymentTermId: id, clearPaymentTerm: id == null));
    await _loadItems();
  }

  /// The orderable SKUs for the current choices: `/lookups/skus` answers
  /// each one's quantity rules, the delivery branch's stock and the price.
  Future<void> _loadItems() async {
    final relationship = state.relationship;
    final supplierId = relationship == null ? null : state.supplierIdOf(relationship);
    if (relationship == null || supplierId == null) return;
    emit(state.copyWith(itemsLoading: true));

    final result = await _lookups.items(
      Lookup.skus,
      query: {
        'supplier_organization_id': supplierId,
        'relationship_id': relationship.id,
        'payment_term_id': ?state.paymentTermId,
        'contract_id': ?state.contractId,
        // No `branch_id`: it filters the *supplier's* stock by branch, and the
        // delivery branch is the trader's — it answered 0 where the website
        // shows the supplier's 230 (live, 2026-10-11).
        'inventory_context': 'catalog',
        'limit': 100,
      },
    );
    if (isClosed) return;
    final items = [
      for (final row in result.dataOrNull ?? const <LookupItem>[]) OrderEntryItem.fromJson(row.raw),
    ];
    // Quantities typed for SKUs still on the list survive a reload.
    final kept = {
      for (final entry in state.quantities.entries)
        if (items.any((i) => i.skuId == entry.key)) entry.key: entry.value,
    };
    emit(state.copyWith(itemsLoading: false, items: items, quantities: kept));
  }

  /// Never more than the item's available stock ([OrderEntryItem.maxQty]):
  /// a larger typed or stepped value lands on the maximum.
  void setQuantity(int skuId, double qty) {
    for (final item in state.items) {
      final max = item.skuId == skuId ? item.maxQty : null;
      if (max != null && qty > max) qty = max;
    }
    final quantities = {...state.quantities};
    if (qty <= 0) {
      quantities.remove(skuId);
    } else {
      quantities[skuId] = qty;
    }
    final errors = {...state.lineErrors}..remove(skuId);
    emit(state.copyWith(quantities: quantities, lineErrors: errors));
  }

  /// One step up or down by the SKU's order step; the first step up lands on
  /// the smallest quantity its rules allow. [setQuantity] caps it at stock.
  void nudge(OrderEntryItem item, int direction) {
    final sku = item.sku;
    final step = sku.orderStepQty > 0 ? sku.orderStepQty : 1.0;
    final current = state.quantities[item.skuId] ?? 0;
    var next = current + step * direction;
    if (direction > 0 && current == 0) {
      next = sku.snapQty(sku.minOrderQty > 0 ? sku.minOrderQty : step);
    }
    setQuantity(item.skuId, next < 0 ? 0 : next);
  }

  // ------------------------------------------------------------ submit

  /// **Never auto-retried.** Draft (with every choice) → its lines → submit.
  /// A line the server refuses stops the submit and is shown under its SKU;
  /// the next attempt reuses the same draft and only sends what differs.
  /// Returns the order, or `null` (the reasons are on [state]).
  Future<PurchaseOrder?> submit({String? notes}) async {
    final relationship = state.relationship;
    final supplierId = relationship == null ? null : state.supplierIdOf(relationship);
    if (state.action.isSubmitting || relationship == null || supplierId == null) return null;

    if (state.branchId == null) {
      return _refuse('delivery_branch_required');
    }

    // The SKU's own rules first: same codes the server uses.
    final local = <int, String>{};
    for (final item in state.chosenItems) {
      final code = item.sku.validateQty(state.quantities[item.skuId]!);
      if (code != null) local[item.skuId] = ErrorMessages.forCode(code);
    }
    if (local.isNotEmpty) {
      emit(state.copyWith(lineErrors: local));
      return null;
    }
    if (!state.canSubmit) return null;

    emit(
      state.copyWith(
        action: const SubmitState(status: FormStatus.submitting),
        lineErrors: const {},
        ruleErrors: const [],
        actionCode: '',
      ),
    );

    // 1. The draft, carrying every header choice.
    final draft = await _orders.saveDraft(
      draftId: _draftId,
      supplierOrganizationId: supplierId,
      relationshipId: relationship.id,
      deliveryBranchId: state.branchId,
      paymentTermId: state.paymentTermId,
      contractId: state.contractId,
      notes: (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
    );
    if (isClosed) return null;
    if (draft is! Ok<PurchaseDraft>) {
      emit(state.copyWith(action: draft.failureState, actionCode: draft.failureCode));
      return null;
    }
    final draftId = draft.data.id;
    _draftId = draftId;

    // 2. The lines — only what differs from what the draft already holds.
    final existing = {for (final line in draft.data.lines) line.skuId: line};
    final lineErrors = <int, String>{};
    for (final line in draft.data.lines) {
      if ((state.quantities[line.skuId] ?? 0) > 0) continue;
      await _orders.removeLine(draftId: draftId, lineId: line.id);
    }
    for (final item in state.chosenItems) {
      final qty = state.quantities[item.skuId]!;
      final held = existing[item.skuId];
      if (held != null) {
        if ((held.qty - qty).abs() < 1e-9) continue;
        await _orders.removeLine(draftId: draftId, lineId: held.id);
      }
      final added = await _orders.addLine(draftId: draftId, skuId: item.skuId, qty: qty);
      if (isClosed) return null;
      if (added is! Ok<PurchaseDraft>) {
        lineErrors[item.skuId] = added.failureMessage ?? ErrorMessages.forCode(added.failureCode);
      }
    }
    if (lineErrors.isNotEmpty) {
      emit(
        state.copyWith(
          lineErrors: lineErrors,
          action: SubmitState(
            status: FormStatus.failure,
            message: ErrorMessages.forCode('order_lines_refused'),
          ),
        ),
      );
      return null;
    }

    // 3. The submit: the server's contract rules and credit check.
    final result = await _orders.submitDraft(draftId);
    if (isClosed) return null;
    if (result case Ok(:final data)) {
      _draftId = null;
      emit(
        state.copyWith(
          creditReview: data.creditReview,
          action: const SubmitState(status: FormStatus.success),
        ),
      );
      return data.order;
    }
    final rules = SubmitRuleError.listFrom(
      result is Failed<DraftSubmitResult> ? result.details : null,
    );
    emit(
      state.copyWith(
        action: result.failureState,
        actionCode: result.failureCode,
        ruleErrors: [
          for (final e in rules)
            if (e.skuId == null) e,
        ],
        lineErrors: {
          for (final e in rules)
            if (e.skuId != null)
              e.skuId!: e.message.isNotEmpty ? e.message : ErrorMessages.forCode(e.code),
        },
      ),
    );
    return null;
  }

  PurchaseOrder? _refuse(String code) {
    emit(
      state.copyWith(
        actionCode: code,
        action: SubmitState(status: FormStatus.failure, message: ErrorMessages.forCode(code)),
      ),
    );
    return null;
  }
}
