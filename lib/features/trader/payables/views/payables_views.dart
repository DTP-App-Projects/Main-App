import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/invoice.dart';
import '../../../../data/repositories/receivables_repository.dart';
import '../../../shared/compliance/views/payment_notice_widgets.dart';
import '../view_models/payables_cubits.dart';

const _invoiceStatuses = ['issued', 'partially_paid', 'paid', 'overdue', 'canceled'];

class InvoicesView extends StatelessWidget {
  const InvoicesView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => InvoicesCubit(getIt<ReceivablesRepository>())..load(),
        child: const _InvoicesBody(),
      );
}

class _InvoicesBody extends StatelessWidget {
  const _InvoicesBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<InvoicesCubit>();
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('invoice.payables'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.statuses.isEmpty,
                onTap: () => cubit.clearStatuses(),
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
            child: PagedListView<Invoice>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.request_quote_outlined,
              emptyTitle: 'invoice.empty'.tr(),
              itemBuilder: (invoice) => DocumentTile(
                code: invoice.invoiceNo,
                title: invoice.purchaseOrder?.name ?? '',
                subtitle: invoice.dueDate == null
                    ? ''
                    : '${'invoice.due'.tr()}: ${AppDates.date(invoice.dueDate, locale)}',
                status: invoice.isOverdue ? 'overdue' : invoice.status,
                amount: invoice.outstandingAmount,
                currency: invoice.currencyCode,
                icon: Icons.request_quote_outlined,
                onTap: () => context.push(AppRoutes.invoiceDetailFor(invoice.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One invoice: what is owed, when each instalment falls due, and the claim
/// button. Totals are displayed as the server sent them — never re-derived.
/// A return goes through a return note (guide Part 14.1): the other side
/// accepts it with a verification code and a credit note follows. The old
/// `post_invoice_returns` form was approved by the supplier with neither.
void _openReturnNote(BuildContext context, Invoice invoice) {
  final purchaseOrderId = invoice.purchaseOrderId;
  if (purchaseOrderId == null) return;
  context.push(AppRoutes.returnNoteNewFor(purchaseOrderId, invoiceId: invoice.id));
}

class InvoiceDetailView extends StatelessWidget {
  final int invoiceId;

  /// The notice a `payment_notice.*` push is about — scrolled to and marked.
  final int? highlightNoticeId;

  const InvoiceDetailView({super.key, required this.invoiceId, this.highlightNoticeId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            InvoiceDetailCubit(getIt<ReceivablesRepository>(), invoiceId)..load(),
        child: _InvoiceDetailBody(highlightNoticeId: highlightNoticeId),
      );
}

class _InvoiceDetailBody extends StatefulWidget {
  final int? highlightNoticeId;

  const _InvoiceDetailBody({this.highlightNoticeId});

  @override
  State<_InvoiceDetailBody> createState() => _InvoiceDetailBodyState();
}

class _InvoiceDetailBodyState extends State<_InvoiceDetailBody> {
  final _highlightKey = GlobalKey();
  bool _scrolled = false;

  /// Once the highlighted notice is on the list, bring it into view — once.
  void _scrollToNotice(InvoiceDetailState state) {
    final id = widget.highlightNoticeId;
    if (_scrolled || id == null || !state.notices.any((n) => n.id == id)) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<InvoiceDetailCubit>();
    final state = cubit.state;
    final invoice = state.invoice;
    final theme = Theme.of(context);
    final t = context.tokens;
    _scrollToNotice(state);

    return Scaffold(
      // The number leads the header card; the bar names the document type.
      appBar: AppBar(title: Text('invoice.title'.tr())),
      bottomNavigationBar: invoice == null
          ? null
          : AppBottomBar(
              // The last action's result, right above the buttons.
              leading: (state.action.message ?? '').isEmpty
                  ? null
                  : FormMessage(message: state.action.message, success: state.action.isSuccess),
              child: invoice.isPaid
                  ? AppButton.outline(
                      label: 'returns.submit'.tr(),
                      icon: Icons.assignment_return_outlined,
                      onPressed: () => _openReturnNote(context, invoice),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppButton.outline(
                            label: 'returns.submit'.tr(),
                            icon: Icons.assignment_return_outlined,
                            onPressed: () => _openReturnNote(context, invoice),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: AppButton.primary(
                            label: 'invoice.claim_payment'.tr(),
                            icon: Icons.payments_outlined,
                            onPressed: () => _claim(context, invoice, invoice.nextDue),
                          ),
                        ),
                      ],
                    ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading && invoice == null) return const DetailSkeleton();
          if (invoice == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                // ---- the tax invoice: ZATCA QR, PDF, late payment, Nafith,
                //      dispute pack (compliance release) ---------------------
                AppMenuGroup(children: [
                  AppMenuRow(
                    icon: Icons.qr_code_2_rounded,
                    title: 'tax.open'.tr(),
                    subtitle: invoice.compliance.documentTitle.isEmpty ? null : invoice.compliance.documentTitle,
                    onTap: () => context.push(AppRoutes.invoiceComplianceFor(invoice.id)),
                  ),
                ]),
                const SizedBox(height: AppTokens.space4),

                // ---- header, with what is still owed as the hero -----------
                AppCard(
                  shadow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              invoice.invoiceNo,
                              style: theme.textTheme.titleMedium,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(
                            status: invoice.isOverdue ? 'overdue' : invoice.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space4),
                      Text('invoice.outstanding'.tr(), style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppTokens.space1),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MoneyText(
                            invoice.outstandingAmount,
                            currency: invoice.currencyCode,
                            style: AppType.ledgerLarge(
                              invoice.isOverdue ? t.danger : t.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.space3),
                        child: Divider(height: 1, color: t.divider),
                      ),
                      DetailRow(
                        label: 'invoice.date'.tr(),
                        value: DateText(invoice.invoiceDate),
                      ),
                      DetailRow(
                        label: 'invoice.due'.tr(),
                        value: DateText(invoice.dueDate),
                      ),
                      if (invoice.paymentTerm != null)
                        DetailRow(
                          label: 'order.payment_term'.tr(),
                          value: Text(invoice.paymentTerm!.label),
                        ),
                      DetailRow(
                        label: 'order.subtotal'.tr(),
                        value: MoneyText(invoice.subtotal, currency: invoice.currencyCode),
                      ),
                      DetailRow(
                        label: 'order.tax_total'.tr(),
                        value: MoneyText(invoice.taxTotal, currency: invoice.currencyCode),
                      ),
                      DetailRow(
                        label: 'order.grand_total'.tr(),
                        emphasis: true,
                        value: MoneyText(invoice.grandTotal, currency: invoice.currencyCode),
                      ),
                    ],
                  ),
                ),

                // ---- instalments --------------------------------------------
                if (invoice.dueSchedules.isNotEmpty) ...[
                  AppSectionLabel('invoice.schedule'.tr()),
                  AppCard.section(
                    child: Column(
                      children: [
                        for (var i = 0; i < invoice.dueSchedules.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: AppTokens.space4,
                              ),
                              child: Divider(height: 1, color: t.divider),
                            ),
                          _InstallmentRow(
                            schedule: invoice.dueSchedules[i],
                            currency: invoice.currencyCode,
                            onClaim: invoice.dueSchedules[i].isSettled
                                ? null
                                : () => _claim(context, invoice, invoice.dueSchedules[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // ---- payment notices: waiting, confirmed, rejected ---------
                if (state.notices.isNotEmpty) ...[
                  AppSectionLabel(
                    'payment_notice.title'.tr(),
                    trailing: AppCountBadge(state.notices.length),
                  ),
                  for (final notice in state.notices)
                    Padding(
                      key: notice.id == widget.highlightNoticeId ? _highlightKey : null,
                      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                      child: PaymentNoticeCard(
                        notice: notice,
                        highlighted: notice.id == widget.highlightNoticeId,
                        onReviewed: cubit.load,
                      ),
                    ),
                ],

                // ---- claims already sent ------------------------------------
                if (state.claims.isNotEmpty) ...[
                  AppSectionLabel('invoice.claims'.tr()),
                  AppCard.section(
                    child: Column(
                      children: [
                        for (var i = 0; i < state.claims.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: AppTokens.space4,
                              ),
                              child: Divider(height: 1, color: t.divider),
                            ),
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTokens.space4,
                              vertical: AppTokens.space3,
                            ),
                            child: Row(
                              children: [
                                const AppIconCircle(Icons.payments_outlined, size: 40),
                                const SizedBox(width: AppTokens.space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      MoneyText(
                                        state.claims[i].amount,
                                        currency: invoice.currencyCode,
                                        style: AppType.ledger(t.textPrimary),
                                      ),
                                      Text(
                                        _methodLabel(state.claims[i].paymentMethod),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppTokens.space2),
                                StatusChip(status: state.claims[i].status),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// The method's own word when the app has one, else the server's code.
  static String _methodLabel(String method) {
    if (method.isEmpty) return '—';
    final key = 'invoice.method_$method';
    final translated = key.tr();
    return translated == key ? method : translated;
  }

  Future<void> _claim(
    BuildContext context,
    Invoice invoice,
    DueSchedule? schedule,
  ) async {
    final cubit = context.read<InvoiceDetailCubit>();
    await showAppSheet<void>(
      context: context,
      title: 'invoice.claim_payment'.tr(),
      subtitle: 'invoice.claim_hint'.tr(),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ClaimPaymentSheet(invoice: invoice, schedule: schedule),
      ),
    );
  }
}

/// One instalment: number, due date, what is left on it, and an explicit
/// "Claim" affordance when it is still open.
class _InstallmentRow extends StatelessWidget {
  final DueSchedule schedule;
  final String currency;
  final VoidCallback? onClaim;

  const _InstallmentRow({
    required this.schedule,
    required this.currency,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return InkWell(
      onTap: onClaim,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.space4,
          AppTokens.space3,
          AppTokens.space2,
          AppTokens.space3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'invoice.installment'.tr(namedArgs: {'no': '${schedule.installmentNo}'}),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 16, color: t.iconMuted),
                      const SizedBox(width: AppTokens.space1),
                      DateText(schedule.dueDate, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space1),
                  MoneyText(
                    schedule.outstanding,
                    currency: currency,
                    style: AppType.ledger(t.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            if (schedule.isOverdue)
              const StatusChip(status: 'overdue')
            else if (schedule.isSettled)
              const StatusChip(status: 'paid'),
            if (onClaim != null) ...[
              AppButton.text(
                label: 'invoice.claim_short'.tr(),
                height: 40,
                onPressed: onClaim,
              ),
              DirectionalChevron(size: 20, color: t.iconMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// "I paid — please confirm." Proof is uploaded first and only its **path**
/// is sent, which is the two-step upload every v2 file field uses.
///
/// Built as the body of a `showAppSheet`, which supplies the title, the
/// scrolling and the keyboard inset.
class ClaimPaymentSheet extends StatefulWidget {
  final Invoice invoice;
  final DueSchedule? schedule;

  const ClaimPaymentSheet({super.key, required this.invoice, this.schedule});

  @override
  State<ClaimPaymentSheet> createState() => _ClaimPaymentSheetState();
}

class _ClaimPaymentSheetState extends State<ClaimPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (widget.schedule?.outstanding ?? widget.invoice.outstandingAmount)
        .toStringAsFixed(2),
  );
  final _reference = TextEditingController();
  final _note = TextEditingController();

  String? _method = ReceivablesRepository.noticePaymentMethods.first;
  String? _proofPath;
  DateTime _paidAt = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount < 0.01) return;

    // A payment notice, as the website sends it — the supplier confirms
    // or rejects it, and confirming is what moves the balance.
    final ok = await context.read<InvoiceDetailCubit>().sendNotice(
          amount: amount,
          dueScheduleId: widget.schedule?.id,
          paymentMethod: _method ?? ReceivablesRepository.noticePaymentMethods.first,
          referenceNo: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          proofFile: _proofPath,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          paidAt: _paidAt,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InvoiceDetailCubit>().state;
    final schedule = widget.schedule;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (schedule != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppBadge(
                'invoice.installment'.tr(namedArgs: {'no': '${schedule.installmentNo}'}),
                icon: Icons.event_outlined,
              ),
            ),
            const SizedBox(height: AppTokens.space4),
          ],

          AppField(
            controller: _amount,
            label: 'invoice.amount'.tr(),
            required: true,
            icon: Icons.payments_outlined,
            suffixText: widget.invoice.currencyCode,
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final parsed = double.tryParse((value ?? '').trim()) ?? 0;
              return parsed < 0.01 ? 'validation.required'.tr() : null;
            },
            serverError: state.action.fieldError('amount'),
          ),
          CodePicker(
            label: 'invoice.payment_method'.tr(),
            value: _method,
            // The methods `POST /payment_notices` accepts.
            codes: ReceivablesRepository.noticePaymentMethods,
            labelOf: (code) => 'invoice.method_$code'.tr(),
            error: state.action.fieldError('payment_method'),
            onChanged: (value) => setState(() => _method = value),
          ),
          AppDateField(
            label: 'invoice.paid_at'.tr(),
            value: _paidAt,
            error: state.action.fieldError('paid_at'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _paidAt,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _paidAt = picked);
            },
          ),
          AppField(
            controller: _reference,
            label: 'invoice.reference_no'.tr(),
            icon: Icons.tag_rounded,
            textDirection: TextDirection.ltr,
            serverError: state.action.fieldError('reference_no'),
          ),
          ProofFileField(
            label: 'invoice.proof'.tr(),
            module: 'payment_notices',
            fieldKey: 'proof_file',
            onUploaded: (path) => _proofPath = path,
            error: state.action.fieldError('proof_file'),
          ),
          AppField(
            controller: _note,
            label: 'profile.notes'.tr(),
            maxLines: 2,
            textInputAction: TextInputAction.done,
            serverError: state.action.fieldError('note'),
          ),
          const SizedBox(height: AppTokens.space2),
          FormMessage(message: state.action.message),
          SubmitButton(
            busy: state.action.isSubmitting,
            label: 'invoice.send_claim'.tr(),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
