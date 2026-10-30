import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/i18n/money.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/api_paths.dart';
import '../../../../data/models/compliance/legal.dart';
import '../../../../data/models/compliance/returns_and_evidence.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';
import '../files/document_file_view.dart';
import '../otp_acceptance_sheet.dart';
import '../service_invoice_gate.dart';

ComplianceRepository get _repo => getIt<ComplianceRepository>();

String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// --------------------------------------------------------------- return notes

class ReturnNotesView extends StatelessWidget {
  const ReturnNotesView({super.key});

  @override
  Widget build(BuildContext context) => PagedScreen<ReturnNote>(
        title: 'rn.title'.tr(),
        fetch: (page) => _repo.returnNotes(page: page),
        emptyIcon: Icons.assignment_return_outlined,
        emptyTitle: 'rn.empty'.tr(),
        emptyBody: 'rn.empty_hint'.tr(),
        itemBuilder: (context, r) => DocumentTile(
          code: r.returnNo,
          title: r.purchaseOrderNo,
          subtitle: r.reasonLabel,
          status: r.status,
          amount: r.grandTotal,
          currency: r.currencyCode,
          icon: Icons.assignment_return_outlined,
          onTap: () => context.push(AppRoutes.returnNoteFor(r.id)),
        ),
      );
}

class ReturnNoteDetailView extends StatelessWidget {
  final int returnNoteId;

  const ReturnNoteDetailView({super.key, required this.returnNoteId});

  Future<void> _accept(BuildContext context, ReturnNote r, DetailCubit<ReturnNote> cubit) async {
    final ok = await showOtpAcceptance(
      context,
      documentType: 'return_note',
      documentId: r.id,
      title: 'rn.accept_title'.tr(),
      subtitle: r.returnNo,
      submit: (code) => _repo.setReturnNoteStatus(r.id, 'accepted', otpCode: code),
    );
    if (ok) await cubit.succeeded('rn.accepted'.tr());
  }

  Future<void> _reject(BuildContext context, ReturnNote r, DetailCubit<ReturnNote> cubit) async {
    final reason = await showAppReasonDialog(
      context,
      title: 'rn.reject_title'.tr(),
      confirmLabel: 'rn.reject'.tr(),
      required: true,
      destructive: true,
    );
    if (reason == null) return;
    await cubit.run(() => _repo.setReturnNoteStatus(r.id, 'rejected', reason: reason));
  }

  @override
  Widget build(BuildContext context) => DetailScreen<ReturnNote>(
        title: 'rn.detail_title'.tr(),
        fetch: () => _repo.returnNote(returnNoteId),
        children: (context, r, cubit) {
          final locale = context.locale.toString();
          final theme = Theme.of(context);
          final busy = cubit.state.action.isSubmitting;
          // The server names the accepting side; the viewer's side is the
          // active workspace.
          final mySide = _viewerSide(context);
          final canDecide = r.status == 'requested' && r.acceptingSide == mySide;
          final canMarkReturned =
              mySide == 'supplier' && (r.status == 'accepted' || r.status == 'credit_issued');
          return [
            DocumentHeaderCard(
              number: r.returnNo,
              title: r.purchaseOrderNo,
              status: r.status,
              statusLabel: r.statusLabel,
              rows: [
                DetailRow(label: 'rn.reason'.tr(), value: Text(r.reasonLabel)),
                if (r.reasonNotes.isNotEmpty) DetailRow(label: 'rn.notes'.tr(), value: Text(r.reasonNotes)),
                if (r.hasInvoice) DetailRow(label: 'rn.invoice'.tr(), value: Text(r.invoiceNo)),
                DetailRow(label: 'rn.requested_by'.tr(), value: Text('agreement.side_${r.requestedBySide}'.tr())),
                if (r.acceptedAt != null) DetailRow(label: 'rn.accepted_at'.tr(), value: Text(AppDates.riyadh(r.acceptedAt, locale))),
                if (r.goodsReturnedAt != null)
                  DetailRow(label: 'rn.goods_returned_at'.tr(), value: Text(AppDates.riyadh(r.goodsReturnedAt, locale))),
                if (r.hasCreditNote) DetailRow(label: 'rn.credit_note'.tr(), value: Text(r.creditNoteNo)),
                DetailRow(label: 'quotation.total'.tr(), value: MoneyText(r.grandTotal, currency: r.currencyCode)),
              ],
            ),
            AppSectionLabel('rn.lines'.tr()),
            AppCard(
              child: Column(
                children: [
                  for (final l in r.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                      child: Row(
                        children: [
                          Expanded(child: Text(l.skuName, style: theme.textTheme.titleSmall)),
                          Text('× ${_qty(l.qty)}', style: theme.textTheme.bodyMedium),
                          const SizedBox(width: AppTokens.space3),
                          MoneyText(l.lineTotal, currency: r.currencyCode),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),
            PdfButton(path: ApiPaths.returnNotePdf(r.id), title: r.returnNo, fileName: '${r.returnNo}.pdf'),
            if (r.hasCreditNote) ...[
              const SizedBox(height: AppTokens.space3),
              PdfButton(path: ApiPaths.creditNotePdf(r.creditNoteId), title: r.creditNoteNo, fileName: '${r.creditNoteNo}.pdf'),
            ],
            const SizedBox(height: AppTokens.space4),
            ActionMessage(cubit.state.action),
            if (canDecide) ...[
              AppButton.primary(
                label: 'rn.accept'.tr(),
                icon: Icons.verified_outlined,
                onPressed: busy ? null : () => _accept(context, r, cubit),
              ),
              const SizedBox(height: AppTokens.space3),
              AppButton.outlineDanger(label: 'rn.reject'.tr(), onPressed: busy ? null : () => _reject(context, r, cubit)),
            ],
            if (canMarkReturned) ...[
              const SizedBox(height: AppTokens.space4),
              AppButton.primary(
                label: 'rn.mark_returned'.tr(),
                icon: Icons.inventory_2_outlined,
                busy: busy,
                onPressed: busy ? null : () => cubit.run(() => _repo.setReturnNoteStatus(r.id, 'goods_returned')),
              ),
            ],
          ];
        },
      );
}

String _viewerSide(BuildContext context) =>
    context.read<WorkspaceCubit>().state?.active == Workspace.supplier ? 'supplier' : 'trader';

/// A new return, capped by `returnable_quantities` and limited to the reasons
/// the order's supply model allows (`unsold_consignment` only on
/// consignment).
class ReturnNoteFormView extends StatefulWidget {
  final int purchaseOrderId;
  final int? invoiceId;

  const ReturnNoteFormView({super.key, required this.purchaseOrderId, this.invoiceId});

  @override
  State<ReturnNoteFormView> createState() => _ReturnNoteFormViewState();
}

class _ReturnNoteFormViewState extends State<ReturnNoteFormView> {
  ApiResult<Returnable>? _caps;
  String? _reason;
  final Map<int, TextEditingController> _inputs = {};
  final _notes = TextEditingController();
  SubmitState _submit = const SubmitState();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _inputs.values) {
      c.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _caps = null);
    final result = await _repo.returnable(widget.purchaseOrderId);
    if (!mounted) return;
    setState(() => _caps = result);
  }

  Future<void> _save(Returnable caps) async {
    final qtys = {for (final e in _inputs.entries) e.key: double.tryParse(e.value.text.trim()) ?? 0};
    final over = qtys.entries.any((e) => e.value > (caps.qtyBySku[e.key] ?? 0));
    if (_reason == null || qtys.values.every((v) => v <= 0) || over) {
      setState(() => _submit = SubmitState(
            status: FormStatus.failure,
            message: over ? 'rn.over_cap'.tr() : 'rn.form_incomplete'.tr(),
          ));
      return;
    }
    setState(() => _submit = const SubmitState(status: FormStatus.submitting));
    final result = await _repo.createReturnNote(
      purchaseOrderId: widget.purchaseOrderId,
      invoiceId: widget.invoiceId,
      reason: _reason!,
      qtyBySku: qtys,
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    if (result case Ok(:final data)) {
      context.pushReplacement(AppRoutes.returnNoteFor(data.id));
      return;
    }
    setState(() => _submit = result.failureState);
  }

  @override
  Widget build(BuildContext context) {
    final caps = _caps;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('rn.new'.tr())),
      body: Builder(builder: (context) {
        if (caps == null) return const FormSkeleton(fields: 4);
        if (caps is! Ok<Returnable>) {
          if (caps.isOffline) return AppOfflineState(onRetry: _load);
          return AppErrorState(message: messageOr(caps.failureMessage), onRetry: _load);
        }
        final data = caps.data;
        final skus = data.qtyBySku.keys.where((k) => (data.qtyBySku[k] ?? 0) > 0).toList();
        if (skus.isEmpty) {
          return AppEmptyState(icon: Icons.assignment_return_outlined, title: 'rn.nothing_returnable'.tr());
        }
        for (final sku in skus) {
          _inputs.putIfAbsent(sku, () => TextEditingController());
        }
        return ListView(
          padding: AppTokens.pagePadding,
          children: [
            CodePicker(
              label: 'rn.reason'.tr(),
              value: _reason,
              codes: [for (final r in data.reasons) r.key],
              labelOf: (k) => data.reasons.firstWhere((r) => r.key == k).label,
              error: _submit.fieldError('reason_type'),
              onChanged: (v) => setState(() => _reason = v),
            ),
            AppSectionLabel('rn.lines'.tr()),
            for (final sku in skus)
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SKU #$sku', style: theme.textTheme.titleSmall, textDirection: TextDirection.ltr),
                          Text(
                            'rn.returnable'.tr(namedArgs: {'qty': _qty(data.qtyBySku[sku] ?? 0)}),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: AppField(
                        controller: _inputs[sku]!,
                        label: 'quotation.qty'.tr(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            AppField(controller: _notes, label: 'rn.notes'.tr(), hint: 'common.optional'.tr(), maxLines: 3),
            const SizedBox(height: AppTokens.space4),
            FormMessage(message: _submit.message),
            SubmitButton(busy: _submit.isSubmitting, label: 'rn.submit'.tr(), onPressed: () => _save(data)),
          ],
        );
      }),
    );
  }
}

// ----------------------------------------------------------- custody ledger

/// «توريد أماني»: what of the supplier's goods is still in the trader's
/// custody — received − sold − returned − losses.
class CustodyLedgerView extends StatefulWidget {
  const CustodyLedgerView({super.key});

  @override
  State<CustodyLedgerView> createState() => _CustodyLedgerViewState();
}

class _CustodyLedgerViewState extends State<CustodyLedgerView> {
  late Future<ApiResult<List<CustodyRow>>> _future = _repo.custodyLedger();

  Future<void> _reload() async {
    setState(() => _future = _repo.custodyLedger());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('custody.title'.tr())),
      body: FutureBuilder<ApiResult<List<CustodyRow>>>(
        future: _future,
        builder: (context, snap) {
          final result = snap.data;
          if (result == null) return const ListSkeleton(rows: 5);
          if (result is! Ok<List<CustodyRow>>) {
            if (result.isOffline) return AppOfflineState(onRetry: _reload);
            return AppErrorState(message: messageOr(result.failureMessage), onRetry: _reload);
          }
          final rows = result.data;
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: AppEmptyState(icon: Icons.warehouse_outlined, title: 'custody.empty'.tr(), body: 'custody.empty_hint'.tr()),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                Text('custody.formula'.tr(), style: theme.textTheme.labelSmall),
                const SizedBox(height: AppTokens.space3),
                for (final r in rows)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.skuName.isEmpty ? 'SKU #${r.skuId}' : r.skuName, style: theme.textTheme.titleSmall),
                        if (r.supplierName.isNotEmpty) Text(r.supplierName, style: theme.textTheme.labelSmall),
                        const SizedBox(height: AppTokens.space2),
                        DetailRow(label: 'custody.received'.tr(), value: Text(_qty(r.received))),
                        DetailRow(label: 'custody.sold'.tr(), value: Text(_qty(r.sold))),
                        DetailRow(label: 'custody.returned'.tr(), value: Text(_qty(r.returned))),
                        DetailRow(label: 'custody.losses'.tr(), value: Text(_qty(r.losses))),
                        DetailRow(
                          label: 'custody.balance'.tr(),
                          value: Text(_qty(r.balance), style: theme.textTheme.titleSmall),
                        ),
                        if (r.returnDeadline != null)
                          DetailRow(
                            label: 'custody.return_deadline'.tr(),
                            value: Text(
                              AppDates.date(r.returnDeadline, context.locale.toString()),
                              style: r.returnDeadline!.isBefore(DateTime.now()) && r.balance > 0
                                  ? theme.textTheme.titleSmall?.copyWith(color: context.tokens.dangerText)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The consignment terms of an order, editable until it is accepted
/// (defaults 14 / 14 / 60, return cost on the buyer).
Future<bool> showConsignmentTermsSheet(BuildContext context, int purchaseOrderId, {ConsignmentTerms? current}) async {
  final terms = current ?? ConsignmentTerms.defaults;
  final stocktake = TextEditingController(text: '${terms.stocktakeCycleDays}');
  final remit = TextEditingController(text: '${terms.remittanceDaysAfterSale}');
  final unsold = TextEditingController(text: '${terms.unsoldReturnDays}');
  var bearer = terms.returnCostBearer;
  var submit = const SubmitState();
  final saved = await showAppSheet<bool>(
    context: context,
    title: 'consignment.terms_title'.tr(),
    subtitle: 'consignment.terms_hint'.tr(),
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        Future<void> save() async {
          setSheet(() => submit = const SubmitState(status: FormStatus.submitting));
          final result = await _repo.setConsignmentTerms(
            purchaseOrderId,
            ConsignmentTerms(
              stocktakeCycleDays: int.tryParse(stocktake.text) ?? 14,
              remittanceDaysAfterSale: int.tryParse(remit.text) ?? 14,
              unsoldReturnDays: int.tryParse(unsold.text) ?? 60,
              returnCostBearer: bearer,
            ),
          );
          if (!sheet.mounted) return;
          if (result is Ok || result is NoContent) {
            Navigator.of(sheet).pop(true);
            return;
          }
          setSheet(() => submit = result.failureState);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (c, key, field) in [
              (stocktake, 'consignment.stocktake_days', 'stocktake_cycle_days'),
              (remit, 'consignment.remit_days', 'remittance_days_after_sale'),
              (unsold, 'consignment.unsold_days', 'unsold_return_days'),
            ])
              AppField(
                controller: c,
                label: key.tr(),
                suffixText: 'rr.days'.tr(),
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                serverError: submit.fieldError(field),
              ),
            CodePicker(
              label: 'consignment.cost_bearer'.tr(),
              value: bearer,
              codes: const ['buyer', 'supplier'],
              labelOf: (c) => 'consignment.bearer_$c'.tr(),
              onChanged: (v) => setSheet(() => bearer = v ?? 'buyer'),
            ),
            const SizedBox(height: AppTokens.space3),
            FormMessage(message: submit.message),
            SubmitButton(busy: submit.isSubmitting, label: 'common.save'.tr(), onPressed: save),
          ],
        );
      },
    ),
  );
  return saved ?? false;
}

// ------------------------------------------------------------ dispute packs

class DisputePacksView extends StatelessWidget {
  const DisputePacksView({super.key});

  @override
  Widget build(BuildContext context) => PagedScreen<DisputePack>(
        title: 'dispute.title'.tr(),
        fetch: (page) => _repo.disputePacks(page: page),
        emptyIcon: Icons.inventory_outlined,
        emptyTitle: 'dispute.empty'.tr(),
        emptyBody: 'dispute.empty_hint'.tr(),
        itemBuilder: (context, p) => DocumentTile(
          code: p.packNo,
          title: 'dispute.scope_${p.scopeType}'.tr(),
          subtitle: AppDates.riyadh(p.generatedAt, context.locale.toString()),
          status: 'completed',
          icon: Icons.inventory_outlined,
          onTap: () => context.push(AppRoutes.disputePackFor(p.id)),
        ),
      );
}

class DisputePackDetailView extends StatelessWidget {
  final int packId;

  const DisputePackDetailView({super.key, required this.packId});

  @override
  Widget build(BuildContext context) => DetailScreen<DisputePack>(
        title: 'dispute.detail_title'.tr(),
        fetch: () => _repo.disputePack(packId),
        children: (context, p, cubit) {
          final locale = context.locale.toString();
          final theme = Theme.of(context);
          final t = context.tokens;
          return [
            DocumentHeaderCard(
              number: p.packNo,
              title: 'dispute.scope_${p.scopeType}'.tr(),
              status: 'completed',
              statusLabel: 'dispute.ready'.tr(),
              rows: [
                DetailRow(label: 'dispute.generated_at'.tr(), value: Text(AppDates.riyadh(p.generatedAt, locale))),
                DetailRow(label: 'dispute.items'.tr(), value: Text('${p.itemsCount}')),
                DetailRow(label: 'dispute.principal'.tr(), value: MoneyText(p.principalOutstanding)),
              ],
            ),
            AppSectionLabel('dispute.contents'.tr()),
            AppCard(
              child: Column(
                children: [
                  for (final item in p.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.isLive ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
                            size: 18,
                            color: t.iconMuted,
                          ),
                          const SizedBox(width: AppTokens.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.label} · ${item.number}', style: theme.textTheme.titleSmall),
                                Text(
                                  item.isLive ? 'dispute.live_item'.tr() : 'dispute.source_${item.source}'.tr(),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (p.zipSha256.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space2),
              Text('ZIP SHA-256: ${p.zipSha256}', textDirection: TextDirection.ltr, style: AppType.code(t.textSecondary)),
            ],
            const SizedBox(height: AppTokens.space4),
            AppButton.primary(
              label: 'dispute.download'.tr(),
              icon: Icons.download_rounded,
              onPressed: () => shareOrSaveFile(context, path: ApiPaths.disputePackFile(p.id), fileName: '${p.packNo}.zip'),
            ),
          ];
        },
      );
}

// --------------------------------------------------------- late-payment notices

class LatePaymentNoticesView extends StatelessWidget {
  const LatePaymentNoticesView({super.key});

  @override
  Widget build(BuildContext context) => PagedScreen<LatePaymentNotice>(
        title: 'late.title'.tr(),
        fetch: (page) => _repo.latePaymentNotices(page: page),
        emptyIcon: Icons.mark_email_unread_outlined,
        emptyTitle: 'late.empty'.tr(),
        emptyBody: 'late.empty_hint'.tr(),
        // No amount on a notice row: notices never show a penalty, and the
        // principal is on the invoice itself.
        itemBuilder: (context, n) => DocumentTile(
          code: n.noticeNo,
          title: 'late.kind_${n.kind}'.tr(),
          subtitle: n.invoiceNo,
          status: n.status,
          icon: Icons.mark_email_unread_outlined,
          onTap: () => context.push(AppRoutes.latePaymentNoticeFor(n.id)),
        ),
      );
}

class LatePaymentNoticeDetailView extends StatelessWidget {
  final int noticeId;

  const LatePaymentNoticeDetailView({super.key, required this.noticeId});

  @override
  Widget build(BuildContext context) => DetailScreen<LatePaymentNotice>(
        title: 'late.detail_title'.tr(),
        fetch: () => _repo.latePaymentNotice(noticeId),
        children: (context, n, cubit) {
          final locale = context.locale.toString();
          return [
            DocumentHeaderCard(
              number: n.noticeNo,
              title: 'late.kind_${n.kind}'.tr(),
              status: n.status,
              statusLabel: n.statusLabel,
              rows: [
                if (n.invoiceNo.isNotEmpty) DetailRow(label: 'rn.invoice'.tr(), value: Text(n.invoiceNo)),
                DetailRow(label: 'late.issued_at'.tr(), value: Text(AppDates.riyadh(n.issuedAt, locale))),
                if (n.graceEndsAt != null)
                  DetailRow(label: 'late.grace_ends'.tr(), value: Text(AppDates.riyadh(n.graceEndsAt, locale))),
              ],
            ),
            AppBanner(message: 'late.principal_only_note'.tr(), tone: AppTone.info),
            if (n.invoiceId > 0)
              AppButton.outline(
                label: 'late.open_invoice'.tr(),
                height: 48,
                // Straight to the invoice, on either side.
                onPressed: () => context.push(_viewerSide(context) == 'trader'
                    ? AppRoutes.invoiceDetailFor(n.invoiceId)
                    : AppRoutes.invoiceComplianceFor(n.invoiceId)),
              ),
          ];
        },
      );
}

// --------------------------------------------------------- service invoices

/// «فواتير الخدمة» (`/b2b/service-invoices`), for both sides: the free period
/// and its extension progress, the overdue block on new orders, and the
/// `SINV-` invoices (subscription, documentation, the monthly 1% platform
/// fees, …).
class ServiceInvoicesView extends StatefulWidget {
  const ServiceInvoicesView({super.key});

  @override
  State<ServiceInvoicesView> createState() => _ServiceInvoicesViewState();
}

class _ServiceInvoicesViewState extends State<ServiceInvoicesView> {
  ApiResult<ServiceInvoices>? _result;
  bool _loadingMore = false;
  final _overdueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final result = await _repo.serviceInvoices();
    if (mounted) setState(() => _result = result);
  }

  Future<void> _loadMore(ServiceInvoices current) async {
    setState(() => _loadingMore = true);
    final next = await _repo.serviceInvoices(page: current.currentPage + 1);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (next case Ok(:final data)) _result = Ok(current.append(data));
    });
  }

  void _showOverdue(ServiceInvoice? overdue) {
    final target = _overdueKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.1);
    } else if (overdue != null) {
      _ServiceInvoiceSheet.show(context, overdue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text('fees.title'.tr())),
      body: Builder(
        builder: (context) {
          if (result == null) return const ListSkeleton(rows: 4);
          if (result is! Ok<ServiceInvoices>) {
            if (result.isOffline) return AppOfflineState(onRetry: _reload);
            return AppErrorState(message: messageOr(result.failureMessage), onRetry: _reload);
          }
          final data = result.data;
          final overdue = data.firstOverdue;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                if (data.newOrdersRestricted)
                  ServiceInvoiceOverdueBanner(
                    actionLabel: 'fees.show_overdue'.tr(),
                    onAction: () => _showOverdue(overdue),
                  ),
                _FreePeriodCard(data: data),
                const SizedBox(height: AppTokens.space4),
                if (data.invoices.isEmpty)
                  AppEmptyState(
                    icon: Icons.receipt_outlined,
                    title: 'fees.empty'.tr(),
                    body: 'fees.empty_hint'.tr(),
                  )
                else ...[
                  for (final s in data.invoices)
                    Padding(
                      key: identical(s, overdue) ? _overdueKey : null,
                      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
                      child: _ServiceInvoiceTile(invoice: s),
                    ),
                  if (data.hasMore)
                    AppButton.outline(
                      label: 'fees.load_more'.tr(),
                      height: 44,
                      onPressed: _loadingMore ? null : () => _loadMore(data),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// `2026-10` → «أكتوبر 2026» / "October 2026".
String _billingMonth(String period, String locale) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(period);
  if (m == null) return period;
  return DateFormat.yMMMM(locale).format(DateTime(int.parse(m[1]!), int.parse(m[2]!)));
}

String _kindLabel(ServiceInvoice s) {
  if (s.kindLabel.isNotEmpty) return s.kindLabel;
  final key = 'fees.kind_${s.kind}';
  final translated = key.tr();
  return translated == key ? 'fees.kind_'.tr() : translated;
}

class _ServiceInvoiceTile extends StatelessWidget {
  final ServiceInvoice invoice;

  const _ServiceInvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final s = invoice;
    final locale = context.locale.toString();
    final due = AppDates.date(AppDates.toRiyadh(s.dueAt), locale);
    return DocumentTile(
      code: s.number,
      title: [
        _kindLabel(s),
        if (s.period.isNotEmpty) _billingMonth(s.period, locale),
      ].join(' · '),
      subtitle: due.isNotEmpty
          ? 'fees.due_on'.tr(namedArgs: {'date': due})
          : AppDates.date(AppDates.toRiyadh(s.issuedAt), locale),
      status: s.status,
      amount: s.total.major,
      currency: s.currencyCode,
      icon: Icons.receipt_outlined,
      badge: s.isOverdue
          ? AppBadge('fees.overdue'.tr(), tone: AppTone.danger, icon: Icons.schedule_rounded)
          : null,
      onTap: () => _ServiceInvoiceSheet.show(context, s),
    );
  }
}

/// One invoice's header. The list already carries every field the detail
/// endpoint sends, so no second read is spent on it.
class _ServiceInvoiceSheet extends StatelessWidget {
  final ServiceInvoice invoice;

  const _ServiceInvoiceSheet({required this.invoice});

  static Future<void> show(BuildContext context, ServiceInvoice s) => showAppSheet<void>(
    context: context,
    title: s.number.isEmpty ? _kindLabel(s) : s.number,
    subtitle: _kindLabel(s),
    builder: (_) => _ServiceInvoiceSheet(invoice: s),
  );

  @override
  Widget build(BuildContext context) {
    final s = invoice;
    final locale = context.locale.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.isOverdue) ...[
          AppBanner(tone: AppTone.danger, message: 'fees.overdue_row_hint'.tr()),
        ],
        DetailRow(
          label: 'fees.status'.tr(),
          value: StatusChip(status: s.status, label: s.statusLabel.isEmpty ? null : s.statusLabel),
        ),
        if (s.period.isNotEmpty)
          DetailRow(label: 'fees.period'.tr(), value: Text(_billingMonth(s.period, locale))),
        if (s.issuedAt != null)
          DetailRow(
            label: 'fees.issued_at'.tr(),
            value: Text(AppDates.date(AppDates.toRiyadh(s.issuedAt), locale)),
          ),
        if (s.dueAt != null)
          DetailRow(
            label: 'fees.due_at'.tr(),
            value: Text(AppDates.date(AppDates.toRiyadh(s.dueAt), locale)),
          ),
        DetailRow(
          label: 'fees.amount'.tr(),
          emphasis: true,
          value: MoneyText(s.total.major, currency: s.currencyCode),
        ),
      ],
    );
  }
}

/// The free period, its extension progress, or — once it is over — how the
/// platform fee is billed.
class _FreePeriodCard extends StatelessWidget {
  final ServiceInvoices data;

  const _FreePeriodCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final free = data.freePeriod;
    final ext = free.extension;

    if (!free.inFreePeriod) {
      return AppBanner(
        key: const Key('free_period_over'),
        tone: AppTone.neutral,
        icon: Icons.percent_rounded,
        margin: EdgeInsetsDirectional.zero,
        message: 'fees.free_over'.tr(namedArgs: {'rate': data.platformFeeRateLabel}),
      );
    }

    final until = AppDates.date(AppDates.toRiyadh(free.freeUntil), locale);
    final days = free.daysLeft(DateTime.now().toUtc());
    return AppCard(
      key: const Key('free_period_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconCircle(Icons.celebration_outlined, size: 40),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'fees.free_until_title'.tr(namedArgs: {'date': until}),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.space1),
                    Text(
                      'fees.days_left'.tr(namedArgs: {'days': '$days'}),
                      style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ext.extended) ...[
            const SizedBox(height: AppTokens.space3),
            AppBanner(
              key: const Key('free_period_extended'),
              tone: AppTone.brand,
              margin: EdgeInsetsDirectional.zero,
              message: 'fees.extended'.tr(),
            ),
          ] else if (ext.hasTargets) ...[
            const SizedBox(height: AppTokens.space4),
            _TargetBar(
              key: const Key('extension_invoices'),
              value: ext.invoicesProgress,
              done: '${ext.invoices}',
              target: '${ext.invoicesTarget}',
              unit: 'fees.unit_invoices'.tr(),
            ),
            const SizedBox(height: AppTokens.space3),
            _TargetBar(
              key: const Key('extension_gmv'),
              value: ext.gmvProgress,
              done: AppMoney.plain(ext.gmvExVat.major, locale: locale),
              target: AppMoney.plain(ext.gmvTarget.major, locale: locale),
              unit: 'fees.unit_gmv'.tr(),
            ),
            const SizedBox(height: AppTokens.space3),
            Text(
              'fees.extension_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            if (ext.pendingExtension) ...[
              const SizedBox(height: AppTokens.space3),
              AppBanner(
                key: const Key('extension_pending'),
                tone: AppTone.brand,
                margin: EdgeInsetsDirectional.zero,
                message: 'fees.extension_met'.tr(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// `7 / 20 فاتورة مجمّدة` over its bar. Numbers stay LTR inside RTL text.
class _TargetBar extends StatelessWidget {
  final double value;
  final String done;
  final String target;
  final String unit;

  const _TargetBar({
    super.key,
    required this.value,
    required this.done,
    required this.target,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap, not a Row: «38,250.00 / 100,000.00» and its unit do not
        // fit side by side on a narrow phone in Arabic.
        Wrap(
          spacing: AppTokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$done / $target',
              textDirection: TextDirection.ltr,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            Text(unit, style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: AppTokens.space1 + 2),
        ClipRRect(
          borderRadius: AppTokens.fullRadius,
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: t.neutralTint,
            color: t.primary,
          ),
        ),
      ],
    );
  }
}
