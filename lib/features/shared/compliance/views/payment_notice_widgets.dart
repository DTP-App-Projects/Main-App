import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/i18n/money.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/payment_notice.dart';
import '../../../../data/repositories/receivables_repository.dart';
import '../../orders/views/order_detail_view.dart' show askForReason;
import 'invoice_money_sections.dart' show openProof;

/// The payment-method code, in words when the app has them.
String paymentMethodLabel(String code) {
  if (code.isEmpty) return '—';
  final key = 'invoice.method_$code';
  final translated = key.tr();
  return translated == key ? code : translated;
}

/// One «إشعار سداد»: amount, method, date, reference, proof, the supplier's
/// review note — and, **only when the server says `can_review`**, the
/// Confirm / Reject buttons. A rejection needs a note (3–1000 characters);
/// the dialog will not close without one.
class PaymentNoticeCard extends StatefulWidget {
  final PaymentNotice notice;

  /// Re-reads whatever lists this notice (and the invoice balance) after a
  /// review.
  final Future<void> Function() onReviewed;

  /// Draws attention to the notice a push opened.
  final bool highlighted;

  /// The inbox links each notice to its invoice; the invoice screen does not.
  final bool showInvoice;

  const PaymentNoticeCard({
    super.key,
    required this.notice,
    required this.onReviewed,
    this.highlighted = false,
    this.showInvoice = false,
  });

  @override
  State<PaymentNoticeCard> createState() => _PaymentNoticeCardState();
}

class _PaymentNoticeCardState extends State<PaymentNoticeCard> {
  bool _busy = false;
  String? _message;

  Future<void> _review(String status, {String? note}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await getIt<ReceivablesRepository>().reviewPaymentNotice(
      id: widget.notice.id,
      status: status,
      reviewNote: note,
    );
    if (!mounted) return;
    final ok = result is Ok<PaymentNotice> || result is NoContent<PaymentNotice>;
    setState(() {
      _busy = false;
      _message = ok ? null : result.failureMessage;
    });
    if (ok) await widget.onReviewed();
  }

  Future<void> _confirm() async {
    final ok = await showAppConfirm(
      context,
      title: 'payment_notice.confirm_title'.tr(),
      body: 'payment_notice.confirm_body'.tr(),
      confirmLabel: 'payment_notice.confirm'.tr(),
    );
    if (ok) await _review('confirmed');
  }

  Future<void> _reject() async {
    final note = await askForReason(
      context,
      title: 'payment_notice.reject'.tr(),
      hint: 'payment_notice.reject_hint'.tr(),
      minLength: 3,
      maxLength: 1000,
      destructive: true,
    );
    if (note == null) return;
    await _review('rejected', note: note);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final t = context.tokens;
    final theme = Theme.of(context);
    final locale = context.locale.toString();

    return AppCard.item(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: widget.highlighted
              ? BorderDirectional(start: BorderSide(color: t.primary, width: 3))
              : null,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: widget.highlighted ? AppTokens.space3 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: MoneyText(
                        n.amount,
                        currency: n.currencyCode.isEmpty ? AppMoney.defaultCurrency : n.currencyCode,
                        style: AppType.ledger(t.textPrimary, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  StatusChip(status: n.status),
                ],
              ),
              const SizedBox(height: AppTokens.space2),
              DetailRow(
                label: 'payment_notice.number'.tr(),
                value: Text(n.label, textDirection: TextDirection.ltr),
              ),
              DetailRow(
                label: 'invoice.payment_method'.tr(),
                value: Text(paymentMethodLabel(n.paymentMethod)),
              ),
              if (n.paidAt != null)
                DetailRow(
                  label: 'invoice.paid_at'.tr(),
                  value: Text(AppDates.date(n.paidAt, locale)),
                ),
              if (n.referenceNo.isNotEmpty)
                DetailRow(
                  label: 'invoice.reference_no'.tr(),
                  value: Text(n.referenceNo, textDirection: TextDirection.ltr),
                ),
              if (widget.showInvoice && n.invoiceId != null)
                DetailRow(
                  label: 'collections.invoice'.tr(),
                  value: InkWell(
                    onTap: () => context.push(AppRoutes.invoiceComplianceFor(n.invoiceId!)),
                    child: Text(
                      n.invoiceNo.isNotEmpty ? n.invoiceNo : '#${n.invoiceId}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: t.primary),
                    ),
                  ),
                ),
              if (n.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.space1),
                  child: Text(n.note, style: theme.textTheme.bodySmall),
                ),
              // The trader sees why it was refused; the supplier sees what it wrote.
              if (n.reviewNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.space2),
                  child: AppBanner(
                    tone: n.status == 'rejected' ? AppTone.danger : AppTone.neutral,
                    margin: EdgeInsetsDirectional.zero,
                    title: 'payment_notice.review_note'.tr(),
                    message: n.reviewNote,
                  ),
                ),
              if (n.isPending && !n.canReview)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.space1),
                  child: Text(
                    'payment_notice.waiting'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                ),
              if (n.proofUrl.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton.text(
                    label: 'collections.view_proof'.tr(),
                    icon: Icons.attach_file_rounded,
                    height: 36,
                    onPressed: () => openProof(n.proofUrl),
                  ),
                ),
              FormMessage(message: _message),
              if (n.canReview) ...[
                const SizedBox(height: AppTokens.space3),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.solid(
                        label: 'payment_notice.confirm'.tr(),
                        height: 48,
                        busy: _busy,
                        onPressed: _busy ? null : _confirm,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppButton.outlineDanger(
                        label: 'payment_notice.reject'.tr(),
                        height: 48,
                        onPressed: _busy ? null : _reject,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
