import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/models/trade/catalog.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../../../../data/repositories/lookups_repository.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../shared/compliance/service_invoice_gate.dart';
import '../../../shared/compliance/views/order_compliance_section.dart';
import '../view_models/draft_cubit.dart';
import 'order_submitted.dart';

/// Build an order: pick lines, set the terms, submit.
///
/// The SKU picker is `/lookups/skus`, which returns the resolved price and
/// availability in one call — the right picker for order entry.
class DraftEditorView extends StatelessWidget {
  final int supplierOrganizationId;
  final int? draftId;
  final int? relationshipId;

  const DraftEditorView({
    super.key,
    required this.supplierOrganizationId,
    this.draftId,
    this.relationshipId,
  });

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => DraftCubit(
          getIt<OrdersRepository>(),
          getIt<CatalogRepository>(),
          supplierOrganizationId: supplierOrganizationId,
          relationshipId: relationshipId,
          draftId: draftId,
        )..start(),
      ),
      BlocProvider(create: (_) => OrdersRestrictionCubit(getIt<ComplianceRepository>())..load()),
    ],
    child: _DraftBody(supplierOrganizationId: supplierOrganizationId),
  );
}

class _DraftBody extends StatefulWidget {
  final int supplierOrganizationId;

  const _DraftBody({required this.supplierOrganizationId});

  @override
  State<_DraftBody> createState() => _DraftBodyState();
}

class _DraftBodyState extends State<_DraftBody> {
  final _notes = TextEditingController();
  bool _notesFilled = false;

  int get supplierOrganizationId => widget.supplierOrganizationId;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DraftCubit>();
    final state = cubit.state;
    final draft = state.draft;
    final theme = Theme.of(context);
    final t = context.tokens;
    // An overdue service invoice: the server would refuse the submit.
    final restricted = context.watch<OrdersRestrictionCubit>().state;
    if (draft != null && !_notesFilled) {
      _notes.text = draft.notes;
      _notesFilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text('order.draft_title'.tr())),
      // The grand total lives here only, next to the button it commits to.
      bottomNavigationBar: draft == null
          ? null
          : AppBottomBar(
              leading: Row(
                children: [
                  Expanded(
                    child: Text('order.grand_total'.tr(), style: theme.textTheme.bodyMedium),
                  ),
                  MoneyText(draft.grandTotal, style: AppType.ledger(t.textPrimary)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The submit's error, right above the submit button.
                  FormMessage(
                    message:
                        state.action.message ?? (restricted ? 'fees.orders_blocked'.tr() : null),
                  ),
                  SubmitButton(
                    busy: state.action.isSubmitting,
                    label: 'order.submit'.tr(),
                    onPressed: draft.canSubmit && !restricted ? () => _submit(context) : null,
                  ),
                ],
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading && draft == null) return const DetailSkeleton();
          if (draft == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.start);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.start,
            );
          }

          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              if (restricted && state.actionCode != ServiceInvoiceCodes.overdue)
                const ServiceInvoiceOverdueBanner(),
              // ---- header: who, how to pay, where to deliver -------------
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AppInitialAvatar(name: draft.supplier?.name ?? ''),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('order.supplier'.tr(), style: theme.textTheme.bodySmall),
                              Text(
                                draft.supplier?.name ?? 'order.draft_title'.tr(),
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space5),
                    // The contract the guided order chose: its prices and
                    // terms are the ones the lines resolve against.
                    if (draft.contractId != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AppBadge(
                            'order.contract_applied'.tr(namedArgs: {'id': '${draft.contractId}'}),
                            tone: AppTone.brand,
                            icon: Icons.description_outlined,
                          ),
                        ),
                      ),
                    _PaymentTermPicker(state: state),
                    _BranchPicker(state: state),
                    AppField(
                      controller: _notes,
                      label: 'order.notes'.tr(),
                      hint: 'common.optional'.tr(),
                      maxLines: 2,
                      textInputAction: TextInputAction.newline,
                      serverError: state.action.fieldError('notes'),
                    ),
                  ],
                ),
              ),

              // ---- a refused submit: every rule, and where to go next -----
              if (state.ruleErrors.isNotEmpty || state.actionCode.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space3),
                GuidedRefusal(code: state.actionCode),
                if (state.ruleErrors.isNotEmpty) _RuleErrorsCard(errors: state.ruleErrors),
              ],

              // ---- lines -------------------------------------------------
              // A line's error, right above the row with the add-line button.
              FormMessage(message: state.lineError),
              AppSectionLabel(
                'order.lines'.tr(),
                trailing: AppButton.text(
                  label: 'order.add_line'.tr(),
                  icon: Icons.add_rounded,
                  height: 32,
                  busy: state.addingLine,
                  onPressed: state.addingLine ? null : () => _addLine(context),
                ),
              ),
              if (draft.lines.isEmpty)
                AppCard(
                  child: Column(
                    children: [
                      const AppIconCircle(Icons.add_shopping_cart_rounded),
                      const SizedBox(height: AppTokens.space3),
                      Text(
                        'order.no_lines'.tr(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                AppCard.section(
                  child: Column(
                    children: [
                      for (var i = 0; i < draft.lines.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTokens.space4,
                            ),
                            child: Divider(height: 1, color: t.divider),
                          ),
                        _DraftLineRow(
                          line: draft.lines[i],
                          errors: cubit.errorsForSku(draft.lines[i].skuId),
                          onRemove: () => _confirmRemove(context, draft.lines[i]),
                        ),
                      ],
                    ],
                  ),
                ),

              // ---- totals (the grand total is in the bottom bar) ----------
              if (draft.lines.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space4),
                AppCard(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppTokens.cardPadding,
                    vertical: AppTokens.space3,
                  ),
                  child: Column(
                    children: [
                      DetailRow(label: 'order.subtotal'.tr(), value: MoneyText(draft.subtotal)),
                      DetailRow(label: 'order.tax_total'.tr(), value: MoneyText(draft.taxTotal)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, DraftLine line) async {
    final cubit = context.read<DraftCubit>();
    final ok = await showAppConfirm(
      context,
      title: 'order.remove_line_title'.tr(),
      body: line.skuName.isEmpty ? line.skuCode : line.skuName,
      confirmLabel: 'order.remove_line'.tr(),
      destructive: true,
    );
    if (!ok) return;
    await cubit.removeLine(line.id);
  }

  Future<void> _addLine(BuildContext context) async {
    final cubit = context.read<DraftCubit>();

    // `/lookups/skus` answers with the resolved price and availability per
    // SKU, scoped to this supplier — one call instead of a list plus a
    // resolve per row.
    final picked = await showLookupPicker(
      context: context,
      title: 'order.pick_sku'.tr(),
      lookup: Lookup.skus,
      // The contract makes the price the contract's. No `branch_id`: it
      // filters the supplier's stock by *its* branch, and the delivery
      // branch is the trader's (it answered 0 for stock the website shows).
      query: {
        'supplier_organization_id': supplierOrganizationId,
        'relationship_id': ?cubit.relationshipId,
        'payment_term_id': ?cubit.state.draft?.paymentTermId,
        'contract_id': ?cubit.state.draft?.contractId,
        'inventory_context': 'catalog',
      },
    );
    if (picked == null || !context.mounted) return;

    final sku = Sku.fromJson(picked.raw);
    final locale = context.locale.toString();
    final qty = await showAppSheet<double>(
      context: context,
      title: sku.displayName(locale),
      subtitle: 'order.qty_rules'.tr(
        namedArgs: {
          'min': _QuantitySheetState._format(sku.minOrderQty),
          'step': _QuantitySheetState._format(sku.orderStepQty),
        },
      ),
      builder: (_) => _QuantitySheet(sku: sku),
    );
    if (qty == null) return;

    await cubit.addLine(sku: sku, qty: qty);
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<DraftCubit>();
    final order = await cubit.submit(notes: _notes.text);
    if (order == null || !context.mounted) return;

    await announceSubmittedOrder(context, order, cubit.state.creditReview);
  }
}

/// Every `errors[]` entry of a refused submit, in the server's words.
class _RuleErrorsCard extends StatelessWidget {
  final List<SubmitRuleError> errors;

  const _RuleErrorsCard({required this.errors});

  @override
  Widget build(BuildContext context) => AppBanner(
    tone: AppTone.danger,
    icon: Icons.rule_rounded,
    title: 'order.submit_blocked'.tr(),
    message: [for (final e in errors) '• ${ruleErrorText(e)}'].join('\n'),
  );
}

/// The entry's own sentence, else the app's copy for its code.
String ruleErrorText(SubmitRuleError error) =>
    error.message.isNotEmpty ? error.message : ErrorMessages.forCode(error.code);

class _DraftLineRow extends StatelessWidget {
  final DraftLine line;
  final VoidCallback onRemove;

  /// The submit's refusals about this line — the row turns red with them.
  final List<SubmitRuleError> errors;

  const _DraftLineRow({required this.line, required this.onRemove, this.errors = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Container(
      color: errors.isEmpty ? null : t.danger.withValues(alpha: 0.06),
      child: _row(context, theme, t),
    );
  }

  Widget _row(BuildContext context, ThemeData theme, AppTokens t) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.space4,
        AppTokens.space3,
        AppTokens.space1,
        AppTokens.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.skuName.isEmpty ? line.skuCode : line.skuName,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppTokens.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'order.line_qty'.tr(namedArgs: {'qty': _qty(line.qty)}),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text('×', style: theme.textTheme.bodySmall),
                    MoneyText(line.unitPrice, style: theme.textTheme.bodySmall),
                  ],
                ),
                for (final error in errors)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
                    child: Text(
                      ruleErrorText(error),
                      style: theme.textTheme.bodySmall?.copyWith(color: t.danger),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          MoneyText(line.lineTotal, style: AppType.ledger(t.textPrimary)),
          IconButton(
            tooltip: 'order.remove_line'.tr(),
            icon: Icon(Icons.delete_outline_rounded, color: t.danger),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  static String _qty(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

/// Asks for a quantity, pre-filled with the smallest the SKU allows and
/// validated against the same rules the server enforces. Pops the sheet with
/// the quantity; dismissing it resolves to `null`.
class _QuantitySheet extends StatefulWidget {
  final Sku sku;

  const _QuantitySheet({required this.sku});

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final _controller = TextEditingController(
    text: _format(widget.sku.minOrderQty > 0 ? widget.sku.minOrderQty : 1),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = double.tryParse(_controller.text.trim()) ?? 0;
    final rejection = widget.sku.validateQty(qty);
    if (rejection != null) {
      setState(() => _error = 'errors.$rejection'.tr());
      return;
    }
    Navigator.of(context).pop(qty);
  }

  /// The stepper moves by the SKU's order step (1 when it has none) and
  /// never below zero; the value is still checked on submit.
  void _nudge(int direction) {
    final step = widget.sku.orderStepQty > 0 ? widget.sku.orderStepQty : 1.0;
    final current = double.tryParse(_controller.text.trim()) ?? 0;
    final next = current + step * direction;
    setState(() {
      _controller.text = _format(next < 0 ? 0 : next);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final sku = widget.sku;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFieldShell(
          label: 'order.qty'.tr(),
          bottom: AppTokens.space2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCircleButton(icon: Icons.remove_rounded, onPressed: () => _nudge(-1)),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    errorText: _error,
                    errorMaxLines: 3,
                    suffixText: sku.unitLabel(locale),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              AppCircleButton(icon: Icons.add_rounded, onPressed: () => _nudge(1)),
            ],
          ),
        ),
        if (sku.orderStepQty > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.text(
              label: 'order.snap_qty'.tr(),
              icon: Icons.straighten_rounded,
              height: 40,
              onPressed: () {
                final current = double.tryParse(_controller.text.trim()) ?? 0;
                setState(() {
                  _controller.text = _format(sku.snapQty(current));
                  _error = null;
                });
              },
            ),
          ),
        const SizedBox(height: AppTokens.space5),
        AppButton.primary(label: 'order.add_line'.tr(), onPressed: _submit),
      ],
    );
  }

  static String _format(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

class _PaymentTermPicker extends StatelessWidget {
  final DraftState state;

  const _PaymentTermPicker({required this.state});

  @override
  Widget build(BuildContext context) => IdPicker(
    label: 'order.payment_term'.tr(),
    value: state.draft?.paymentTermId,
    items: state.paymentTerms,
    idOf: (term) => term.id,
    labelOf: (term) => term.label,
    required: false,
    error: state.action.fieldError('payment_term_id'),
    onChanged: (id) => context.read<DraftCubit>().updateHeader(paymentTermId: id),
  );
}

/// The draft stores only the branch **id**, so the chosen row is kept here to
/// keep its name on screen without a second lookup.
class _BranchPicker extends StatefulWidget {
  final DraftState state;

  const _BranchPicker({required this.state});

  @override
  State<_BranchPicker> createState() => _BranchPickerState();
}

/// A refused submit's branch rule, shown on the picker it is about.
String? _branchRuleError(DraftState state) {
  for (final error in state.ruleErrors) {
    if (error.isBranch) return ruleErrorText(error);
  }
  return state.actionCode.startsWith('delivery_branch') ? state.action.message : null;
}

class _BranchPickerState extends State<_BranchPicker> {
  LookupItem? _branch;

  /// A reopened draft (or one the guided order created) already has a
  /// branch; show its name instead of an empty picker.
  @override
  void initState() {
    super.initState();
    final id = widget.state.draft?.deliveryBranchId;
    if (id != null) _restore(id);
  }

  Future<void> _restore(int id) async {
    final result = await getIt<LookupsRepository>().items(Lookup.branches);
    if (!mounted) return;
    for (final item in result.dataOrNull ?? const <LookupItem>[]) {
      if (item.id == id) setState(() => _branch = item);
    }
  }

  @override
  Widget build(BuildContext context) => LookupField(
    label: 'order.delivery_branch'.tr(),
    lookup: Lookup.branches,
    value: _branch,
    // Required since the submit applies the website's rules
    // (`delivery_branch_required` / `delivery_branch_invalid`).
    required: true,
    error: widget.state.action.fieldError('delivery_branch_id') ?? _branchRuleError(widget.state),
    onChanged: (item) {
      setState(() => _branch = item);
      context.read<DraftCubit>().updateHeader(deliveryBranchId: item?.id);
    },
  );
}
