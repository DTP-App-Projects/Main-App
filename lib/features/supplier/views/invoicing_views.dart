import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/lookups/lookup_item.dart';
import '../../../data/models/trade/invoice.dart';
import '../../../data/repositories/receivables_repository.dart';
import '../view_models/supplier_cubits.dart';

const _invoiceStatuses = ['issued', 'partially_paid', 'paid', 'overdue', 'canceled'];

/// Receivables: what the supplier has billed, and the instalments it may move.
class SupplierInvoicesView extends StatelessWidget {
  const SupplierInvoicesView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SupplierInvoicesCubit(getIt<ReceivablesRepository>())..load(),
        child: const _SupplierInvoicesBody(),
      );
}

class _SupplierInvoicesBody extends StatelessWidget {
  const _SupplierInvoicesBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SupplierInvoicesCubit>();
    void issue() => context.push(AppRoutes.supplierIssueInvoice);

    return Scaffold(
      appBar: AppBar(title: Text('invoice.receivables'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: issue,
        icon: const Icon(Icons.add_rounded),
        label: Text('invoice.issue'.tr()),
      ),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.statuses.isEmpty,
                onTap: cubit.clearStatuses,
              ),
              for (final status in _invoiceStatuses)
                AppFilterOption(
                  label: 'status.$status'.tr(),
                  selected: cubit.statuses.contains(status),
                  onTap: () => cubit.toggleStatus(status),
                ),
            ],
          ),
          Expanded(
            // The list's own gutter and bottom room keep the cards off the
            // screen edges and clear of the FAB.
            child: PagedListView<Invoice>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.request_quote_outlined,
              emptyTitle: 'invoice.empty'.tr(),
              emptyActionLabel: 'invoice.issue'.tr(),
              onEmptyAction: issue,
              itemBuilder: (invoice) => _InvoiceCard(invoice: invoice),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final cubit = context.read<SupplierInvoicesCubit>();

    return AppCard.item(
      // The supplier's way into the tax invoice, late payment and Nafith.
      onTap: () => context.push(AppRoutes.invoiceComplianceFor(invoice.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNo,
                  style: AppType.code(t.textPrimary),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: invoice.isOverdue ? 'overdue' : invoice.status),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          DetailRow(
            label: 'order.grand_total'.tr(),
            value: MoneyText(invoice.grandTotal, currency: invoice.currencyCode),
          ),
          DetailRow(
            label: 'invoice.outstanding'.tr(),
            emphasis: true,
            value: MoneyText(
              invoice.outstandingAmount,
              currency: invoice.currencyCode,
              style: AppType.ledger(t.textPrimary),
            ),
          ),
          if (invoice.dueSchedules.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space2),
            Divider(height: 1, color: t.divider),
            const SizedBox(height: AppTokens.space3),
            Text(
              'invoice.schedule'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppTokens.space1),
            for (final schedule in invoice.dueSchedules)
              _InstallmentRow(
                schedule: schedule,
                currency: invoice.currencyCode,
                // Only the supplier may move an instalment, and only an
                // unsettled one.
                onEdit: schedule.isSettled
                    ? null
                    : () => _editSchedule(context, cubit, schedule, invoice.currencyCode),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _editSchedule(
    BuildContext context,
    SupplierInvoicesCubit cubit,
    DueSchedule schedule,
    String currency,
  ) =>
      showAppSheet<void>(
        context: context,
        title: 'invoice.edit_schedule'.tr(),
        subtitle: 'invoice.installment'.tr(namedArgs: {'no': '${schedule.installmentNo}'}),
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: _DueScheduleForm(schedule: schedule, currency: currency),
        ),
      );
}

/// One instalment as a compact row: number and due date, the amount at the
/// end, and a plain text action to move it.
class _InstallmentRow extends StatelessWidget {
  final DueSchedule schedule;
  final String currency;
  final VoidCallback? onEdit;

  const _InstallmentRow({required this.schedule, required this.currency, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'invoice.installment'.tr(namedArgs: {'no': '${schedule.installmentNo}'}),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    DateText(schedule.dueDate, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              MoneyText(schedule.dueAmount, currency: currency, style: AppType.ledger(t.textPrimary, size: 14)),
            ],
          ),
          if (onEdit != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.text(
                label: 'invoice.edit_schedule'.tr(),
                icon: Icons.edit_calendar_outlined,
                height: 40,
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }
}

class _DueScheduleForm extends StatefulWidget {
  final DueSchedule schedule;
  final String currency;

  const _DueScheduleForm({required this.schedule, required this.currency});

  @override
  State<_DueScheduleForm> createState() => _DueScheduleFormState();
}

class _DueScheduleFormState extends State<_DueScheduleForm> {
  late final _amount =
      TextEditingController(text: widget.schedule.dueAmount.toStringAsFixed(2));
  late DateTime? _dueDate = widget.schedule.dueDate;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    // The server's floor; checking it here avoids a round trip for a typo.
    if (amount < 0.01) {
      setState(() => _error = 'validation.required'.tr());
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<SupplierInvoicesCubit>().editDueSchedule(
          id: widget.schedule.id,
          dueDate: _dueDate,
          dueAmount: amount,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          controller: _amount,
          label: 'invoice.amount'.tr(),
          icon: Icons.payments_outlined,
          suffixText: widget.currency,
          textDirection: TextDirection.ltr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        AppDateField(
          label: 'invoice.due'.tr(),
          value: _dueDate,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _dueDate ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
            );
            if (picked != null) setState(() => _dueDate = picked);
          },
        ),
        FormMessage(message: _error),
        SubmitButton(busy: _busy, label: 'common.save'.tr(), onPressed: _save),
      ],
    );
  }
}

/// Issue an invoice against a purchase order, or a proforma with no shipment.
class IssueInvoiceView extends StatelessWidget {
  const IssueInvoiceView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => IssueInvoiceCubit(getIt<ReceivablesRepository>()),
        child: const _IssueInvoiceBody(),
      );
}

class _IssueInvoiceBody extends StatefulWidget {
  const _IssueInvoiceBody();

  @override
  State<_IssueInvoiceBody> createState() => _IssueInvoiceBodyState();
}

class _IssueInvoiceBodyState extends State<_IssueInvoiceBody> {
  LookupItem? _order;
  LookupItem? _deliveryNote;
  DateTime _invoiceDate = DateTime.now();
  bool _proforma = false;

  Future<void> _issue() async {
    final order = _order;
    if (order == null) return;

    final invoice = await context.read<IssueInvoiceCubit>().issue(
          purchaseOrderId: order.id,
          deliveryNoteId: _proforma ? null : _deliveryNote?.id,
          invoiceDate: _invoiceDate,
          proforma: _proforma,
        );
    if (invoice == null || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<IssueInvoiceCubit>().state;
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('invoice.issue'.tr())),
      bottomNavigationBar: AppBottomBar(
        // Says why the button is off instead of leaving it grey and silent.
        leading: _order == null
            ? Text(
                'invoice.pick_order_first'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The server's answer, right above the button that asked.
            FormMessage(message: state.action.message),
            SubmitButton(
              busy: state.action.isSubmitting,
              label: 'invoice.issue'.tr(),
              onPressed: _order == null ? null : _issue,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.gutter,
          AppTokens.space3,
          AppTokens.gutter,
          AppTokens.space8,
        ),
        children: [
          AppBanner(message: 'invoice.issue_hint'.tr()),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LookupField(
                  label: 'order.title'.tr(),
                  lookup: Lookup.purchaseOrders,
                  value: _order,
                  required: true,
                  error: state.action.fieldError('purchase_order_id'),
                  onChanged: (item) => setState(() {
                    _order = item;
                    _deliveryNote = null;
                  }),
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('invoice.proforma'.tr(), style: theme.textTheme.titleSmall),
                  subtitle: Text('invoice.proforma_hint'.tr(), style: theme.textTheme.bodySmall),
                  value: _proforma,
                  onChanged: (value) => setState(() => _proforma = value),
                ),
                const SizedBox(height: AppTokens.space3),

                // A proforma is priced from the order alone, so the shipment
                // picker is meaningless there.
                if (!_proforma)
                  LookupField(
                    label: 'outbound.title'.tr(),
                    lookup: Lookup.deliveryNotes,
                    value: _deliveryNote,
                    query: {'purchase_order_id': ?_order?.id},
                    enabled: _order != null,
                    error: state.action.fieldError('delivery_note_id'),
                    onChanged: (item) => setState(() => _deliveryNote = item),
                  ),

                AppDateField(
                  label: 'invoice.date'.tr(),
                  value: _invoiceDate,
                  required: true,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invoiceDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 1),
                    );
                    if (picked != null) setState(() => _invoiceDate = picked);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
