import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/models/trade/catalog.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../view_models/draft_cubit.dart';

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
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DraftCubit(
          getIt<OrdersRepository>(),
          getIt<CatalogRepository>(),
          supplierOrganizationId: supplierOrganizationId,
          relationshipId: relationshipId,
          draftId: draftId,
        )..start(),
        child: _DraftBody(supplierOrganizationId: supplierOrganizationId),
      );
}

class _DraftBody extends StatelessWidget {
  final int supplierOrganizationId;

  const _DraftBody({required this.supplierOrganizationId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DraftCubit>();
    final state = cubit.state;
    final draft = state.draft;
    final theme = Theme.of(context);
    final t = context.tokens;

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
              child: SubmitButton(
                busy: state.action.isSubmitting,
                label: 'order.submit'.tr(),
                onPressed: draft.canSubmit ? () => _submit(context) : null,
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
              FormMessage(message: state.action.message),
              FormMessage(message: state.lineError),

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
                    _PaymentTermPicker(state: state),
                    _BranchPicker(state: state),
                  ],
                ),
              ),

              // ---- lines -------------------------------------------------
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
                      DetailRow(
                        label: 'order.subtotal'.tr(),
                        value: MoneyText(draft.subtotal),
                      ),
                      DetailRow(
                        label: 'order.tax_total'.tr(),
                        value: MoneyText(draft.taxTotal),
                      ),
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
      query: {
        'supplier_organization_id': supplierOrganizationId,
        'relationship_id': ?cubit.relationshipId,
        'payment_term_id': ?cubit.state.draft?.paymentTermId,
        'inventory_context': 'catalog',
      },
    );
    if (picked == null || !context.mounted) return;

    final sku = Sku.fromJson(picked.raw);
    final locale = context.locale.toString();
    final qty = await showAppSheet<double>(
      context: context,
      title: sku.displayName(locale),
      subtitle: 'order.qty_rules'.tr(namedArgs: {
        'min': _QuantitySheetState._format(sku.minOrderQty),
        'step': _QuantitySheetState._format(sku.orderStepQty),
      }),
      builder: (_) => _QuantitySheet(sku: sku),
    );
    if (qty == null) return;

    await cubit.addLine(sku: sku, qty: qty);
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<DraftCubit>();
    final order = await cubit.submit();
    if (order == null || !context.mounted) return;

    // Replace rather than push: the draft is gone, and Back should not offer
    // to submit it again.
    context.pushReplacement(AppRoutes.orderDetailFor(order.id));
  }
}

class _DraftLineRow extends StatelessWidget {
  final DraftLine line;
  final VoidCallback onRemove;

  const _DraftLineRow({required this.line, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

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
              AppCircleButton(
                icon: Icons.remove_rounded,
                onPressed: () => _nudge(-1),
              ),
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
              AppCircleButton(
                icon: Icons.add_rounded,
                onPressed: () => _nudge(1),
              ),
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
        onChanged: (id) =>
            context.read<DraftCubit>().updateHeader(paymentTermId: id),
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

class _BranchPickerState extends State<_BranchPicker> {
  LookupItem? _branch;

  @override
  Widget build(BuildContext context) => LookupField(
        label: 'order.delivery_branch'.tr(),
        lookup: Lookup.branches,
        value: _branch,
        error: widget.state.action.fieldError('delivery_branch_id'),
        onChanged: (item) {
          setState(() => _branch = item);
          context.read<DraftCubit>().updateHeader(deliveryBranchId: item?.id);
        },
      );
}
