import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/models/trade/invoice.dart';
import '../../../../data/models/trade/payment_notice.dart';
import '../../../../data/repositories/lookups_repository.dart';
import '../../../../data/repositories/receivables_repository.dart';
import 'payment_notice_widgets.dart';

String _qty(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);

// ------------------------------------------------ invoice from a receipt

/// «إصدار فاتورة من الاستلام المقبول» (guide Part 13.1): the supplier invoices
/// what the trader accepted on this receipt — never more. For credit and
/// consignment orders the server also requires the trader's confirmation,
/// and says so if it is missing.
class IssueInvoiceFromReceiptButton extends StatelessWidget {
  final GoodsReceipt receipt;
  final bool needsConfirmation;

  const IssueInvoiceFromReceiptButton({super.key, required this.receipt, required this.needsConfirmation});

  Future<void> _open(BuildContext context) async {
    final invoice = await showAppSheet<Invoice>(
      context: context,
      title: 'invoice_from_grn.title'.tr(),
      builder: (_) => _InvoiceFromReceiptForm(receipt: receipt),
    );
    if (invoice == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invoice_from_grn.issued'.tr())));
    context.push(AppRoutes.invoiceComplianceFor(invoice.id));
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (needsConfirmation)
            AppBanner(message: 'invoice_from_grn.needs_confirmation'.tr(), tone: AppTone.info),
          AppButton.primary(
            label: 'invoice_from_grn.title'.tr(),
            icon: Icons.request_quote_outlined,
            onPressed: () => _open(context),
          ),
        ],
      );
}

class _InvoiceFromReceiptForm extends StatefulWidget {
  final GoodsReceipt receipt;

  const _InvoiceFromReceiptForm({required this.receipt});

  @override
  State<_InvoiceFromReceiptForm> createState() => _InvoiceFromReceiptFormState();
}

class _InvoiceFromReceiptFormState extends State<_InvoiceFromReceiptForm> {
  late final Map<int, TextEditingController> _qtyFields = {
    for (final line in widget.receipt.lines) line.id: TextEditingController(text: _qty(line.receivedQty)),
  };
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _qtyFields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final lines = <InvoiceLineInput>[];
    for (final line in widget.receipt.lines) {
      final qty = double.tryParse(_qtyFields[line.id]!.text.trim()) ?? 0;
      if (qty > line.receivedQty) {
        setState(() => _error = 'invoice_from_grn.over_accepted'.tr());
        return;
      }
      if (qty > 0) lines.add(InvoiceLineInput(skuId: line.skuId, qty: qty));
    }
    if (lines.isEmpty) {
      setState(() => _error = 'invoice_from_grn.nothing'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await getIt<ReceivablesRepository>().issueInvoice(
      purchaseOrderId: widget.receipt.purchaseOrderId,
      deliveryNoteId: widget.receipt.deliveryNoteId,
      invoiceDate: _date,
      currencyCode: 'SAR',
      lines: lines,
    );
    if (!mounted) return;
    if (result case Ok(:final data)) {
      Navigator.of(context).pop(data);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.failureMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDateField(
          label: 'invoice_from_grn.date'.tr(),
          value: _date,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        Text('invoice_from_grn.lines'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppTokens.space2),
        for (final line in widget.receipt.lines)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.skuName, style: theme.textTheme.titleSmall),
                      Text(
                        'invoice_from_grn.accepted'.tr(namedArgs: {'qty': _qty(line.receivedQty)}),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: AppField(
                    controller: _qtyFields[line.id]!,
                    label: 'invoice_from_grn.qty'.tr(),
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ),
        FormMessage(message: _error),
        SubmitButton(busy: _busy, label: 'invoice_from_grn.issue'.tr(), onPressed: _submit),
      ],
    );
  }
}

// ------------------------------------------------------ lines and dues

/// «البنود» — what the invoice bills.
class InvoiceLinesSection extends StatelessWidget {
  final Invoice invoice;

  const InvoiceLinesSection({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    if (invoice.lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('invoice.lines'.tr()),
        AppCard(
          child: Column(
            children: [
              for (final line in invoice.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.skuName, style: theme.textTheme.titleSmall),
                            Wrap(
                              spacing: AppTokens.space1,
                              children: [
                                Text('${_qty(line.qty)} ×', style: theme.textTheme.bodySmall),
                                MoneyText(line.unitPrice, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      MoneyText(line.lineTotal, currency: invoice.currencyCode, style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «الاستحقاقات» — each due, red once it is late (guide Part 13.2).
class InvoiceDuesSection extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDuesSection({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    if (invoice.dueSchedules.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('invoice.dues'.tr()),
        AppCard(
          child: Column(
            children: [
              for (final due in invoice.dueSchedules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'invoice.installment'.tr(namedArgs: {'no': '${due.installmentNo}'}),
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              AppDates.date(due.dueDate, locale),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: due.isOverdue ? t.dangerText : null,
                                fontWeight: due.isOverdue ? FontWeight.w700 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(due.dueAmount, currency: invoice.currencyCode, style: theme.textTheme.titleSmall),
                          StatusChip(status: due.isOverdue ? 'overdue' : due.status),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------- payment notices and collections

/// The supplier's side of payment (guide Part 13.4): the trader's notices
/// and the collections on this invoice, and «تسجيل تحصيل المورد».
class InvoiceCollectionsSection extends StatefulWidget {
  final Invoice invoice;
  final Future<void> Function() onChanged;

  const InvoiceCollectionsSection({super.key, required this.invoice, required this.onChanged});

  @override
  State<InvoiceCollectionsSection> createState() => _InvoiceCollectionsSectionState();
}

class _InvoiceCollectionsSectionState extends State<InvoiceCollectionsSection> {
  late Future<ApiResult<Paged<CollectionReceipt>>> _future = _load();
  late Future<ApiResult<Paged<PaymentNotice>>> _notices = _loadNotices();

  Future<ApiResult<Paged<CollectionReceipt>>> _load() =>
      getIt<ReceivablesRepository>().collections(invoiceId: widget.invoice.id);

  Future<ApiResult<Paged<PaymentNotice>>> _loadNotices() =>
      getIt<ReceivablesRepository>().paymentNotices(invoiceId: widget.invoice.id, limit: 50);

  /// A confirmed notice creates a collection and moves the balance: re-read
  /// the notices, the collections and the invoice.
  Future<void> _reviewed() async {
    setState(() {
      _notices = _loadNotices();
      _future = _load();
    });
    await widget.onChanged();
  }

  Future<void> _record() async {
    final saved = await showAppSheet<bool>(
      context: context,
      title: 'collections.record'.tr(),
      builder: (_) => RecordCollectionForm(invoice: widget.invoice),
    );
    if (saved != true || !mounted) return;
    setState(() => _future = _load());
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<ApiResult<Paged<PaymentNotice>>>(
          future: _notices,
          builder: (context, snapshot) {
            final rows = snapshot.data?.dataOrNull?.items ?? const <PaymentNotice>[];
            if (rows.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionLabel('payment_notice.title'.tr(), trailing: AppCountBadge(rows.length)),
                for (final notice in rows)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                    child: PaymentNoticeCard(notice: notice, onReviewed: _reviewed),
                  ),
              ],
            );
          },
        ),
        AppSectionLabel(
          'invoice.collections'.tr(),
          trailing: widget.invoice.outstandingAmount > 0
              ? AppButton.text(
                  label: 'collections.record'.tr(),
                  icon: Icons.add_rounded,
                  height: 32,
                  onPressed: _record,
                )
              : null,
        ),
        FutureBuilder<ApiResult<Paged<CollectionReceipt>>>(
          future: _future,
          builder: (context, snapshot) {
            final rows = snapshot.data?.dataOrNull?.items ?? const <CollectionReceipt>[];
            if (snapshot.connectionState != ConnectionState.done) return const Skeleton(height: 56);
            if (rows.isEmpty) {
              return AppCard(
                child: Text('invoice.no_collections'.tr(), style: Theme.of(context).textTheme.bodySmall),
              );
            }
            return AppCard(
              child: Column(
                children: [
                  for (final c in rows)
                    DetailRow(
                      label: '${c.receiptNo.isEmpty ? '#${c.id}' : c.receiptNo} · ${AppDates.date(c.receivedAt, locale)}',
                      value: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoneyText(c.amount),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: c.status),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// «تسجيل تحصيل المورد»: method, amount, received date, bank account,
/// reference and proof. Pops `true` once recorded.
class RecordCollectionForm extends StatefulWidget {
  final Invoice invoice;

  const RecordCollectionForm({super.key, required this.invoice});

  @override
  State<RecordCollectionForm> createState() => _RecordCollectionFormState();
}

class _RecordCollectionFormState extends State<RecordCollectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.invoice.outstandingAmount.toStringAsFixed(2));
  final _reference = TextEditingController();
  String? _method = ReceivablesRepository.supplierPaymentMethods.first;
  DateTime _receivedAt = DateTime.now();
  int? _bankAccountId;
  List<LookupItem> _accounts = const [];
  String? _proof;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    getIt<LookupsRepository>().items(Lookup.bankAccounts).then((result) {
      if (!mounted) return;
      final items = result.dataOrNull ?? const <LookupItem>[];
      setState(() {
        _accounts = items;
        _bankAccountId = items.isEmpty ? null : items.first.id;
      });
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await getIt<ReceivablesRepository>().recordCollection(
      amount: double.parse(_amount.text.trim()),
      invoiceId: widget.invoice.id,
      paymentMethod: _method,
      receivedAt: _receivedAt,
      bankAccountId: _bankAccountId,
      referenceNo: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      proofFile: _proof,
    );
    if (!mounted) return;
    if (result is Ok || result is NoContent) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.failureMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodePicker(
            label: 'invoice.payment_method'.tr(),
            value: _method,
            codes: ReceivablesRepository.supplierPaymentMethods,
            labelOf: (code) => 'invoice.method_$code'.tr(),
            onChanged: (value) => setState(() => _method = value),
          ),
          AppField(
            controller: _amount,
            label: 'invoice.amount'.tr(),
            required: true,
            suffixText: widget.invoice.currencyCode,
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => (double.tryParse((value ?? '').trim()) ?? 0) < 0.01 ? 'validation.required'.tr() : null,
          ),
          AppDateField(
            label: 'collections.received_at'.tr(),
            value: _receivedAt,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _receivedAt,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _receivedAt = picked);
            },
          ),
          if (_accounts.isNotEmpty)
            IdPicker<LookupItem>(
              label: 'collections.bank_account'.tr(),
              value: _bankAccountId,
              items: _accounts,
              idOf: (a) => a.id,
              labelOf: (a) => a.label(locale),
              required: false,
              onChanged: (id) => setState(() => _bankAccountId = id),
            ),
          AppField(
            controller: _reference,
            label: 'invoice.reference_no'.tr(),
            textDirection: TextDirection.ltr,
          ),
          ProofFileField(
            label: 'invoice.proof'.tr(),
            module: 'collections',
            fieldKey: 'proof_file',
            onUploaded: (path) => _proof = path,
          ),
          FormMessage(message: _error),
          SubmitButton(busy: _busy, label: 'collections.record'.tr(), onPressed: _submit),
        ],
      ),
    );
  }
}

/// Opens an uploaded proof (a full URL from `/v2/uploads`).
Future<void> openProof(String path) async {
  final uri = Uri.tryParse(path);
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
