import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/models/compliance/quotation.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';
import '../otp_acceptance_sheet.dart';

ComplianceRepository get _repo => getIt<ComplianceRepository>();

const _supplyModels = ['direct', 'credit', 'consignment'];

class QuotationsView extends StatelessWidget {
  const QuotationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isSupplier = context.watch<WorkspaceCubit>().state?.active == Workspace.supplier;
    return PagedScreen<Quotation>(
      title: 'quotation.title'.tr(),
      fetch: (page) => _repo.quotations(page: page),
      emptyIcon: Icons.request_page_outlined,
      emptyTitle: 'quotation.empty'.tr(),
      emptyBody: isSupplier ? 'quotation.empty_hint_supplier'.tr() : 'quotation.empty_hint_trader'.tr(),
      fab: isSupplier
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.quotationNew),
              icon: const Icon(Icons.add_rounded),
              label: Text('quotation.new'.tr()),
            )
          : null,
      itemBuilder: (context, q) => DocumentTile(
        code: q.quotationNo,
        title: q.counterparty?.name ?? '',
        subtitle: [
          q.supplyModelLabel,
          if (q.validUntil != null)
            'quotation.valid_until'.tr(namedArgs: {'date': AppDates.date(AppDates.toRiyadh(q.validUntil), context.locale.toString())}),
        ].where((s) => s.isNotEmpty).join(' · '),
        status: q.status,
        amount: q.grandTotal,
        currency: q.currencyCode,
        icon: Icons.request_page_outlined,
        badge: q.canAccept ? AppBadge('quotation.awaiting_you'.tr(), tone: AppTone.info) : null,
        onTap: () => context.push(AppRoutes.quotationFor(q.id)),
      ),
    );
  }
}

class QuotationDetailView extends StatelessWidget {
  final int quotationId;

  const QuotationDetailView({super.key, required this.quotationId});

  Future<void> _accept(BuildContext context, Quotation q, DetailCubit<Quotation> cubit) async {
    final ok = await showOtpAcceptance(
      context,
      documentType: q.otpDocumentType,
      documentId: q.id,
      title: 'quotation.accept_title'.tr(),
      subtitle: q.quotationNo,
      submit: (code) => _repo.setQuotationStatus(q.id, 'accepted', otpCode: code),
    );
    if (ok) await cubit.succeeded('quotation.accepted'.tr());
  }

  Future<void> _cancel(BuildContext context, Quotation q, DetailCubit<Quotation> cubit) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'quotation.cancel_confirm'.tr(),
      confirmLabel: 'quotation.cancel'.tr(),
      destructive: true,
    );
    if (confirmed) await cubit.run(() => _repo.setQuotationStatus(q.id, 'cancelled'));
  }

  @override
  Widget build(BuildContext context) => DetailScreen<Quotation>(
        title: 'quotation.detail_title'.tr(),
        fetch: () => _repo.quotation(quotationId),
        children: (context, q, cubit) {
          final locale = context.locale.toString();
          final theme = Theme.of(context);
          final busy = cubit.state.action.isSubmitting;
          final expired = !q.isValidNow && q.status != 'accepted';
          return [
            DocumentHeaderCard(
              number: q.quotationNo,
              title: q.counterparty?.name ?? '',
              status: q.status,
              statusLabel: q.statusLabel,
              rows: [
                DetailRow(label: 'quotation.supply_model'.tr(), value: Text(q.supplyModelLabel)),
                DetailRow(
                  label: 'quotation.expiry'.tr(),
                  value: Text(
                    AppDates.date(AppDates.toRiyadh(q.validUntil), locale),
                    style: expired ? TextStyle(color: context.tokens.dangerText) : null,
                  ),
                ),
                if (q.deliveryPlace.isNotEmpty) DetailRow(label: 'quotation.delivery_place'.tr(), value: Text(q.deliveryPlace)),
                if (q.supplyDays != null)
                  DetailRow(
                    label: 'quotation.supply_days'.tr(),
                    value: Text('rr.term_days'.tr(namedArgs: {'days': '${q.supplyDays}'})),
                  ),
                if (q.sentAt != null) DetailRow(label: 'quotation.sent_at'.tr(), value: Text(AppDates.riyadh(q.sentAt, locale))),
                if (q.acceptedAt != null)
                  DetailRow(label: 'quotation.accepted_at'.tr(), value: Text(AppDates.riyadh(q.acceptedAt, locale))),
              ],
            ),
            if (expired) AppBanner(message: 'quotation.expired_hint'.tr(), tone: AppTone.warning),
            AppSectionLabel('quotation.lines'.tr()),
            AppCard(
              child: Column(
                children: [
                  for (final l in q.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.name, style: theme.textTheme.titleSmall),
                                Text(
                                  '${_qty(l.qty)} ${l.unit} × ${l.unitPrice.toStringAsFixed(2)} · ${'quotation.vat'.tr(namedArgs: {'rate': _qty(l.vatRate)})}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          MoneyText(l.lineTotal, currency: q.currencyCode),
                        ],
                      ),
                    ),
                  const Divider(),
                  DetailRow(label: 'quotation.subtotal'.tr(), value: MoneyText(q.subtotal, currency: q.currencyCode)),
                  DetailRow(label: 'quotation.tax'.tr(), value: MoneyText(q.taxTotal, currency: q.currencyCode)),
                  DetailRow(label: 'quotation.total'.tr(), value: MoneyText(q.grandTotal, currency: q.currencyCode)),
                ],
              ),
            ),
            FrozenTextCard(text: q.bodyText, hash: q.documentHash),
            if (q.purchaseOrderId != null) ...[
              const SizedBox(height: AppTokens.space3),
              AppBanner(message: 'quotation.po_created'.tr(), tone: AppTone.brand),
            ],
            const SizedBox(height: AppTokens.space4),
            ActionMessage(cubit.state.action),
            if (q.canAccept && !expired)
              AppButton.primary(
                label: 'quotation.accept'.tr(),
                icon: Icons.verified_outlined,
                onPressed: busy ? null : () => _accept(context, q, cubit),
              ),
            if (q.canSend)
              AppButton.primary(
                label: 'quotation.send'.tr(),
                icon: Icons.send_rounded,
                busy: busy,
                onPressed: busy ? null : () => cubit.run(() => _repo.setQuotationStatus(q.id, 'sent'), successMessage: 'quotation.sent'.tr()),
              ),
            if (q.canCancel) ...[
              const SizedBox(height: AppTokens.space3),
              AppButton.outlineDanger(label: 'quotation.cancel'.tr(), onPressed: busy ? null : () => _cancel(context, q, cubit)),
            ],
          ];
        },
      );

  static String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Supplier: a quotation to a trader the supplier already has a relationship
/// with — lines of SKU, quantity and unit price; VAT is the server's.
class QuotationFormView extends StatefulWidget {
  const QuotationFormView({super.key});

  @override
  State<QuotationFormView> createState() => _QuotationFormViewState();
}

class _LineDraft {
  LookupItem? sku;
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _QuotationFormViewState extends State<QuotationFormView> {
  LookupItem? _relationship;
  String _supplyModel = 'direct';
  DateTime _validUntil = DateTime.now().add(const Duration(days: 14));
  final _notes = TextEditingController();
  final _deliveryPlace = TextEditingController();
  final List<_LineDraft> _lines = [_LineDraft()];
  SubmitState _submit = const SubmitState();

  @override
  void dispose() {
    _notes.dispose();
    _deliveryPlace.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _save() async {
    final lines = <QuotationLineInput>[
      for (final l in _lines)
        if (l.sku != null)
          QuotationLineInput(
            skuId: l.sku!.id,
            qty: double.tryParse(l.qty.text.trim()) ?? 0,
            unitPrice: double.tryParse(l.price.text.trim()) ?? 0,
          ),
    ];
    if (_relationship == null || lines.isEmpty) {
      setState(() => _submit = SubmitState(status: FormStatus.failure, message: 'quotation.form_incomplete'.tr()));
      return;
    }
    setState(() => _submit = const SubmitState(status: FormStatus.submitting));
    final result = await _repo.createQuotation(
      relationshipId: _relationship!.id,
      supplyModel: _supplyModel,
      validUntil: _validUntil,
      lines: lines,
      deliveryPlace: _deliveryPlace.text.trim(),
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    if (result case Ok(:final data)) {
      context.pushReplacement(AppRoutes.quotationFor(data.id));
      return;
    }
    setState(() => _submit = result.failureState);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    return Scaffold(
      appBar: AppBar(title: Text('quotation.new'.tr())),
      body: ListView(
        padding: AppTokens.pagePadding,
        children: [
          LookupField(
            label: 'quotation.relationship'.tr(),
            lookup: Lookup.relationships,
            value: _relationship,
            required: true,
            error: _submit.fieldError('relationship_id'),
            onChanged: (v) => setState(() => _relationship = v),
          ),
          CodePicker(
            label: 'quotation.supply_model'.tr(),
            value: _supplyModel,
            codes: _supplyModels,
            labelOf: (c) => 'compliance.model_$c'.tr(),
            error: _submit.fieldError('supply_model'),
            onChanged: (v) => setState(() => _supplyModel = v ?? 'direct'),
          ),
          AppDateField(
            label: 'quotation.expiry'.tr(),
            value: _validUntil,
            required: true,
            error: _submit.fieldError('valid_until'),
            onTap: _pickDate,
          ),
          AppField(controller: _deliveryPlace, label: 'quotation.delivery_place'.tr(), hint: 'common.optional'.tr()),
          AppSectionLabel('quotation.lines'.tr()),
          for (var i = 0; i < _lines.length; i++)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LookupField(
                    label: 'quotation.sku'.tr(),
                    lookup: Lookup.skus,
                    value: _lines[i].sku,
                    required: true,
                    error: _submit.fieldError('lines.$i.sku_id'),
                    onChanged: (v) => setState(() => _lines[i].sku = v),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                          controller: _lines[i].qty,
                          label: 'quotation.qty'.tr(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textDirection: TextDirection.ltr,
                          serverError: _submit.fieldError('lines.$i.qty'),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        child: AppField(
                          controller: _lines[i].price,
                          label: 'quotation.unit_price'.tr(),
                          suffixText: 'SAR',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textDirection: TextDirection.ltr,
                          serverError: _submit.fieldError('lines.$i.unit_price'),
                        ),
                      ),
                    ],
                  ),
                  if (_lines.length > 1)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: AppButton.text(
                        label: 'quotation.remove_line'.tr(),
                        onPressed: () => setState(() => _lines.removeAt(i).dispose()),
                      ),
                    ),
                ],
              ),
            ),
          AppButton.outline(
            label: 'quotation.add_line'.tr(),
            icon: Icons.add_rounded,
            height: 48,
            onPressed: () => setState(() => _lines.add(_LineDraft())),
          ),
          AppField(controller: _notes, label: 'quotation.notes'.tr(), hint: 'common.optional'.tr(), maxLines: 3),
          const SizedBox(height: AppTokens.space4),
          Text(
            'quotation.valid_until'.tr(namedArgs: {'date': AppDates.date(_validUntil, locale)}),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppTokens.space2),
          FormMessage(message: _submit.message),
          SubmitButton(busy: _submit.isSubmitting, label: 'quotation.save_draft'.tr(), onPressed: _save),
        ],
      ),
    );
  }
}
