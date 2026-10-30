import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/api_paths.dart';
import '../../../../data/models/compliance/returns_and_evidence.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/models/trade/invoice.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../../../../data/repositories/receivables_repository.dart';
import '../../../../data/repositories/shipments_repository.dart';
import '../../../trader/receipts/views/edit_window_card.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';
import '../otp_acceptance_sheet.dart';
import 'invoice_money_sections.dart';

ComplianceRepository get _repo => getIt<ComplianceRepository>();

String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// ----------------------------------------------------------- goods receipts

class GoodsReceiptsView extends StatelessWidget {
  const GoodsReceiptsView({super.key});

  @override
  Widget build(BuildContext context) => PagedScreen<GoodsReceipt>(
        title: 'grn.title'.tr(),
        fetch: (page) => getIt<ShipmentsRepository>().goodsReceipts(page: page),
        emptyIcon: Icons.fact_check_outlined,
        emptyTitle: 'grn.empty'.tr(),
        emptyBody: 'grn.empty_hint'.tr(),
        itemBuilder: (context, g) => DocumentTile(
          code: g.compliance.receiptNo,
          title: 'grn.recorded_by_${g.compliance.recordedByRole.isEmpty ? 'unknown' : g.compliance.recordedByRole}'.tr(),
          subtitle: AppDates.dateTime(g.receivedAt, context.locale.toString()),
          status: g.compliance.isConfirmed ? 'confirmed' : (g.compliance.confirmationStatus.isEmpty ? g.status : g.compliance.confirmationStatus),
          icon: Icons.fact_check_outlined,
          badge: g.compliance.requiresTraderConfirmation
              ? AppBadge(g.compliance.confirmationLabel.isEmpty ? 'grn.unconfirmed'.tr() : g.compliance.confirmationLabel, tone: AppTone.warning)
              : null,
          onTap: () => context.push(AppRoutes.goodsReceiptDetailFor(g.id)),
        ),
      );
}

class GoodsReceiptDetailView extends StatelessWidget {
  final int receiptId;

  const GoodsReceiptDetailView({super.key, required this.receiptId});

  Future<void> _confirmWithOtp(BuildContext context, GoodsReceipt g, DetailCubit<GoodsReceipt> cubit) async {
    final ok = await showOtpAcceptance(
      context,
      documentType: 'goods_receipt',
      documentId: g.id,
      title: 'grn.confirm_title'.tr(),
      subtitle: g.compliance.receiptNo,
      submit: (code) => _repo.confirmReceiptWithOtp(g.id, code),
    );
    if (ok) await cubit.succeeded('grn.confirmed'.tr());
  }

  /// The alternative to the code: a photo of the goods and the declaration.
  Future<void> _confirmWithPhoto(BuildContext context, GoodsReceipt g, DetailCubit<GoodsReceipt> cubit) async {
    final declared = await showAppConfirm(
      context,
      title: 'grn.declaration_title'.tr(),
      body: 'grn.declaration_body'.tr(),
      confirmLabel: 'grn.take_photo'.tr(),
    );
    if (!declared) return;
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null) return;
    await cubit.run(() => _repo.confirmReceiptWithPhoto(g.id, photo.path), successMessage: 'grn.confirmed'.tr());
  }

  @override
  Widget build(BuildContext context) => DetailScreen<GoodsReceipt>(
        title: 'grn.detail_title'.tr(),
        fetch: () => getIt<ShipmentsRepository>().goodsReceipt(receiptId),
        children: (context, g, cubit) {
          final c = g.compliance;
          final locale = context.locale.toString();
          final theme = Theme.of(context);
          final isTrader = context.read<WorkspaceCubit>().state?.active == Workspace.trader;
          final busy = cubit.state.action.isSubmitting;
          return [
            DocumentHeaderCard(
              number: c.receiptNo,
              title: 'grn.detail_title'.tr(),
              status: c.isConfirmed ? 'confirmed' : (c.confirmationStatus.isEmpty ? g.status : c.confirmationStatus),
              statusLabel: c.confirmationLabel,
              rows: [
                DetailRow(label: 'grn.received_at'.tr(), value: Text(AppDates.dateTime(g.receivedAt, locale))),
                DetailRow(
                  label: 'grn.recorded_by'.tr(),
                  value: Text('grn.recorded_by_${c.recordedByRole.isEmpty ? 'unknown' : c.recordedByRole}'.tr()),
                ),
                DetailRow(
                  label: 'grn.pod_method'.tr(),
                  value: Text(c.podMethod.isEmpty ? '—' : 'grn.pod_${c.podMethod}'.tr()),
                ),
                if (c.receiverName.isNotEmpty) DetailRow(label: 'grn.receiver'.tr(), value: Text(c.receiverName)),
                if (c.buyerConfirmedAt != null)
                  DetailRow(label: 'grn.confirmed_at'.tr(), value: Text(AppDates.riyadh(c.buyerConfirmedAt, locale))),
                if (c.carrierNote.isNotEmpty) DetailRow(label: 'grn.carrier_note'.tr(), value: Text(c.carrierNote)),
              ],
            ),
            // «وصل ولم يُؤكَّد»: recorded is not accepted.
            if (c.requiresTraderConfirmation)
              AppBanner(
                tone: AppTone.warning,
                title: c.confirmationLabel.isEmpty ? 'grn.unconfirmed'.tr() : c.confirmationLabel,
                message: isTrader ? 'grn.unconfirmed_trader'.tr() : 'grn.unconfirmed_supplier'.tr(),
              ),
            // The correction window after the handoff, with its countdown.
            if (isTrader) ReceiptEditWindowCard(receipt: g, onChanged: cubit.load),
            AppSectionLabel('grn.lines'.tr()),
            AppCard(
              child: Column(
                children: [
                  for (final line in g.lines)
                    Builder(builder: (context) {
                      final lc = c.lines[line.id];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.skuName, style: theme.textTheme.titleSmall),
                            Wrap(
                              spacing: AppTokens.space3,
                              children: [
                                if (lc != null) Text('grn.expected'.tr(namedArgs: {'qty': _qty(lc.expectedQty)}), style: theme.textTheme.labelSmall),
                                Text('grn.received'.tr(namedArgs: {'qty': _qty(line.receivedQty)}), style: theme.textTheme.labelSmall),
                                if (lc != null && lc.shortageQty > 0)
                                  Text('grn.shortage'.tr(namedArgs: {'qty': _qty(lc.shortageQty)}),
                                      style: theme.textTheme.labelSmall?.copyWith(color: context.tokens.dangerText)),
                                if (lc != null && lc.defectQty > 0)
                                  Text('grn.defect'.tr(namedArgs: {'qty': _qty(lc.defectQty)}),
                                      style: theme.textTheme.labelSmall?.copyWith(color: context.tokens.dangerText)),
                              ],
                            ),
                            if (lc != null && lc.defectNote.isNotEmpty)
                              Text(lc.defectNote, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            if (c.documentHash.isNotEmpty) FrozenTextCard(text: '', hash: c.documentHash),
            const SizedBox(height: AppTokens.space4),
            PdfButton(path: ApiPaths.goodsReceiptPdf(g.id), title: c.receiptNo, fileName: '${c.receiptNo.isEmpty ? 'GRN-${g.id}' : c.receiptNo}.pdf'),
            const SizedBox(height: AppTokens.space4),
            ActionMessage(cubit.state.action),
            // The supplier invoices what was accepted here (guide 13.1).
            if (!isTrader) ...[
              IssueInvoiceFromReceiptButton(receipt: g, needsConfirmation: c.requiresTraderConfirmation),
              const SizedBox(height: AppTokens.space3),
            ],
            if (isTrader && c.requiresTraderConfirmation) ...[
              AppButton.primary(
                label: 'grn.confirm_otp'.tr(),
                icon: Icons.verified_outlined,
                onPressed: busy ? null : () => _confirmWithOtp(context, g, cubit),
              ),
              const SizedBox(height: AppTokens.space3),
              AppButton.outline(
                label: 'grn.confirm_photo'.tr(),
                icon: Icons.photo_camera_outlined,
                busy: busy,
                onPressed: busy ? null : () => _confirmWithPhoto(context, g, cubit),
              ),
            ],
          ];
        },
      );
}

// --------------------------------------------- invoice: tax & documents

/// One invoice as a tax document and as evidence: the ZATCA block with its
/// QR, the PDF, late payment (principal only — no penalty anywhere), the
/// Nafith promissory note, and the dispute pack. Opened from either side.
class InvoiceComplianceView extends StatelessWidget {
  final int invoiceId;

  const InvoiceComplianceView({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) => DetailScreen<Invoice>(
        title: 'tax.title'.tr(),
        fetch: () => getIt<ReceivablesRepository>().invoice(invoiceId),
        children: (context, inv, cubit) {
          final c = inv.compliance;
          final theme = Theme.of(context);
          final locale = context.locale.toString();
          return [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(c.documentTitle.isEmpty ? 'tax.document_title'.tr() : c.documentTitle,
                      style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: AppTokens.space1),
                  Text(inv.invoiceNo, style: AppType.code(context.tokens.textSecondary),
                      textAlign: TextAlign.center, textDirection: TextDirection.ltr),
                  const SizedBox(height: AppTokens.space3),
                  if (c.seller != null) ...[
                    DetailRow(label: 'tax.seller'.tr(), value: Text(c.seller!.name)),
                    DetailRow(label: 'tax.seller_vat'.tr(), value: Text(c.seller!.vatNo, textDirection: TextDirection.ltr)),
                  ],
                  if (c.buyer != null) ...[
                    DetailRow(label: 'tax.buyer'.tr(), value: Text(c.buyer!.name)),
                    DetailRow(label: 'tax.buyer_vat'.tr(), value: Text(c.buyer!.vatNo, textDirection: TextDirection.ltr)),
                  ],
                  DetailRow(label: 'tax.date'.tr(), value: DateText(inv.invoiceDate)),
                  if (c.issuedAt != null) DetailRow(label: 'tax.issued_at'.tr(), value: Text(AppDates.riyadh(c.issuedAt, locale))),
                  if (c.vatRate != null) DetailRow(label: 'tax.vat_rate'.tr(), value: Text('${_qty(c.vatRate!)}%')),
                  DetailRow(label: 'quotation.subtotal'.tr(), value: MoneyText(inv.subtotal, currency: inv.currencyCode)),
                  DetailRow(label: 'quotation.tax'.tr(), value: MoneyText(inv.taxTotal, currency: inv.currencyCode)),
                  DetailRow(label: 'quotation.total'.tr(), emphasis: true, value: MoneyText(inv.grandTotal, currency: inv.currencyCode)),
                  if (c.hasZatca) ...[
                    const SizedBox(height: AppTokens.space4),
                    // The TLV string is the QR payload as-is (ZATCA phase 1).
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(AppTokens.space2),
                        child: QrImageView(
                          key: const Key('zatca_qr'),
                          data: c.zatcaQr,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space1),
                    Text('tax.qr_caption'.tr(), style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            InvoiceLinesSection(invoice: inv),
            InvoiceDuesSection(invoice: inv),
            // The supplier sees the notices and collections and records one;
            // the trader pays from the invoice screen with «سداد».
            Builder(builder: (context) {
              final supplier = context.read<WorkspaceCubit>().state?.active == Workspace.supplier;
              if (supplier) return InvoiceCollectionsSection(invoice: inv, onChanged: cubit.load);
              if (inv.outstandingAmount <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsetsDirectional.only(top: AppTokens.space4),
                child: AppButton.primary(
                  label: 'invoice.pay'.tr(),
                  icon: Icons.payments_outlined,
                  onPressed: () => context.push(AppRoutes.invoiceDetailFor(inv.id)),
                ),
              );
            }),
            if (c.poNo.isNotEmpty || c.grnNos.isNotEmpty) ...[
              AppSectionLabel('compliance.chain'.tr()),
              AppCard(
                child: Column(
                  children: [
                    if (c.faNo.isNotEmpty) DetailRow(label: 'compliance.chain_fa'.tr(), value: Text(c.faNo, textDirection: TextDirection.ltr)),
                    if (c.poNo.isNotEmpty) DetailRow(label: 'compliance.chain_po'.tr(), value: Text(c.poNo, textDirection: TextDirection.ltr)),
                    for (final grn in c.grnNos) DetailRow(label: 'grn.detail_title'.tr(), value: Text(grn, textDirection: TextDirection.ltr)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTokens.space4),
            PdfButton(path: ApiPaths.invoicePdf(inv.id), title: inv.invoiceNo, fileName: '${inv.invoiceNo}.pdf'),
            _LatePaymentSection(invoice: inv),
            _PromissorySection(invoice: inv),
            const SizedBox(height: AppTokens.space3),
            DisputePackButton(scopeType: 'invoice', scopeId: inv.id),
            if (c.legalFooter.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space4),
              Text(c.legalFooter, style: theme.textTheme.labelSmall),
            ],
          ];
        },
      );
}

/// Late payment on one invoice: the relationship's supply status and the
/// supplier's notice actions. Shows the **principal** only — no amount here
/// is ever a penalty, interest or compensation.
class _LatePaymentSection extends StatelessWidget {
  final Invoice invoice;

  const _LatePaymentSection({required this.invoice});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DetailCubit<LatePaymentStatus>(() => _repo.invoiceLatePayment(invoice.id))..load(),
        child: BlocBuilder<DetailCubit<LatePaymentStatus>, DetailState<LatePaymentStatus>>(
          builder: (context, state) {
            final cubit = context.read<DetailCubit<LatePaymentStatus>>();
            final lp = state.data;
            if (lp == null) return state.loading ? const Padding(padding: EdgeInsets.only(top: AppTokens.space4), child: Skeleton(height: 72)) : const SizedBox.shrink();
            final locale = context.locale.toString();
            final busy = state.action.isSubmitting;

            Future<void> issue(String kind) async {
              final ok = await showAppConfirm(
                context,
                title: 'late.issue_confirm_$kind'.tr(),
                body: 'late.issue_body'.tr(),
                confirmLabel: 'late.issue_$kind'.tr(),
              );
              if (ok) await cubit.run(() => _repo.issueLatePaymentNotice(invoice.id, kind), successMessage: 'late.issued'.tr());
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionLabel('late.section'.tr()),
                AppCard(
                  child: Column(
                    children: [
                      DetailRow(label: 'rr.supply_status'.tr(), value: SupplyStatusPill(status: lp.supplyStatus, label: lp.supplyStatusLabel)),
                      DetailRow(label: 'late.principal'.tr(), value: MoneyText(lp.outstanding, currency: invoice.currencyCode)),
                      DetailRow(label: 'late.due_date'.tr(), value: DateText(lp.originalDueDate)),
                      DetailRow(label: 'late.past_due'.tr(), value: Text(lp.isPastDue ? 'common.yes'.tr() : 'common.no'.tr())),
                      if (lp.acceleratedAt != null)
                        DetailRow(label: 'late.accelerated_at'.tr(), value: Text(AppDates.riyadh(lp.acceleratedAt, locale))),
                      for (final n in lp.notices)
                        DetailRow(label: 'late.kind_${n.kind}'.tr(), value: Text(AppDates.riyadh(n.issuedAt, locale))),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
                ActionMessage(state.action),
                if (lp.canIssueFirst) ...[
                  const SizedBox(height: AppTokens.space3),
                  AppButton.outline(label: 'late.issue_first'.tr(), height: 48, onPressed: busy ? null : () => issue('first')),
                ],
                if (lp.canIssueSecond) ...[
                  const SizedBox(height: AppTokens.space3),
                  AppButton.outline(label: 'late.issue_second'.tr(), height: 48, onPressed: busy ? null : () => issue('second')),
                ],
                if (lp.canRestore && invoice.businessRelationshipId != null) ...[
                  const SizedBox(height: AppTokens.space3),
                  AppButton.primary(
                    label: 'late.restore_supply'.tr(),
                    height: 48,
                    busy: busy,
                    onPressed: busy ? null : () => cubit.run(() => _repo.restoreSupply(invoice.businessRelationshipId!), successMessage: 'late.restored'.tr()),
                  ),
                ],
              ],
            );
          },
        ),
      );
}

/// Nafith promissory note: no PDF upload. With the API off, open Nafith's own
/// site, then record the instrument number it issued. The amount is the
/// invoice's outstanding, to the halala.
class _PromissorySection extends StatelessWidget {
  final Invoice invoice;

  const _PromissorySection({required this.invoice});

  Future<void> _record(BuildContext context, DetailCubit<PromissoryNotes> cubit) async {
    final number = await showAppReasonDialog(
      context,
      title: 'nafith.record_title'.tr(),
      body: 'nafith.record_body'.tr(),
      hint: 'nafith.instrument_no'.tr(),
      confirmLabel: 'common.save'.tr(),
      required: true,
      maxLength: 64,
    );
    if (number == null || number.trim().isEmpty) return;
    await cubit.run(() => _repo.recordPromissoryNote(invoice.id, number.trim()), successMessage: 'nafith.recorded'.tr());
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DetailCubit<PromissoryNotes>(() => _repo.promissoryNotes(invoice.id))..load(),
        child: BlocBuilder<DetailCubit<PromissoryNotes>, DetailState<PromissoryNotes>>(
          builder: (context, state) {
            final cubit = context.read<DetailCubit<PromissoryNotes>>();
            final p = state.data;
            // Only credit invoices are eligible; a cash one shows nothing.
            if (p == null || (!p.eligible && p.notes.isEmpty)) return const SizedBox.shrink();
            final isSupplier = context.read<WorkspaceCubit>().state?.active == Workspace.supplier;
            final locale = context.locale.toString();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionLabel('nafith.section'.tr()),
                AppCard(
                  child: Column(
                    children: [
                      DetailRow(label: 'nafith.amount'.tr(), value: MoneyText(p.amount, currency: p.currency)),
                      DetailRow(label: 'nafith.maturity'.tr(), value: DateText(p.maturityDate)),
                      if (p.beneficiaryName.isNotEmpty) DetailRow(label: 'nafith.beneficiary'.tr(), value: Text(p.beneficiaryName)),
                      if (p.drawerName.isNotEmpty) DetailRow(label: 'nafith.drawer'.tr(), value: Text(p.drawerName)),
                      for (final n in p.notes)
                        DetailRow(
                          label: n.instrumentNo.isEmpty ? 'nafith.note'.tr() : n.instrumentNo,
                          value: StatusChip(status: n.status.isEmpty ? 'issued' : n.status),
                        ),
                    ],
                  ),
                ),
                if (isSupplier && p.eligible) ...[
                  const SizedBox(height: AppTokens.space3),
                  if (!p.apiEnabled && p.fallbackUrl.isNotEmpty) ...[
                    AppButton.outline(
                      label: 'nafith.open_site'.tr(),
                      icon: Icons.open_in_new_rounded,
                      height: 48,
                      onPressed: () => launchUrl(Uri.parse(p.fallbackUrl), mode: LaunchMode.externalApplication),
                    ),
                    const SizedBox(height: AppTokens.space3),
                  ],
                  ActionMessage(state.action),
                  AppButton.primary(
                    label: 'nafith.record'.tr(),
                    height: 48,
                    onPressed: state.action.isSubmitting ? null : () => _record(context, cubit),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space2),
                    child: Text(
                      'nafith.amount_rule'.tr(namedArgs: {'date': AppDates.date(DateTime.now(), locale)}),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
}
