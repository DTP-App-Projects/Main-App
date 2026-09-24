import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_dates.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/trade/invoice.dart';
import '../../../data/repositories/receivables_repository.dart';
import '../view_models/supplier_cubits.dart';

/// Payment claims waiting on the supplier.
///
/// A trader claim is "I paid — please confirm"; confirming it is what settles
/// the invoice, and a full settlement fires `invoice.paid`.
class CollectionsInboxView extends StatelessWidget {
  const CollectionsInboxView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CollectionsInboxCubit(getIt<ReceivablesRepository>())..load(),
        child: const _CollectionsBody(),
      );
}

/// The payment-method code, in words when the app has them
/// (`invoice.method_*`), otherwise as the server sent it.
String _methodLabel(String code) {
  if (code.isEmpty) return '—';
  final key = 'invoice.method_$code';
  final translated = key.tr();
  return translated == key ? code : translated;
}

class _CollectionsBody extends StatelessWidget {
  const _CollectionsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CollectionsInboxCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('collections.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              for (final status in [null, 'pending', 'confirmed', 'rejected'])
                AppFilterOption(
                  label: status == null ? 'order.filter_all'.tr() : 'status.$status'.tr(),
                  selected: cubit.status == status,
                  onTap: () => cubit.setStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<CollectionReceipt>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.account_balance_wallet_outlined,
              emptyTitle: 'collections.empty'.tr(),
              itemBuilder: (claim) => _ClaimCard(claim: claim),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final CollectionReceipt claim;

  const _ClaimCard({required this.claim});

  Future<void> _confirm(BuildContext context, CollectionsInboxCubit cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'collections.confirm'.tr(),
      confirmLabel: 'collections.confirm'.tr(),
    );
    if (!ok) return;
    await cubit.decide(id: claim.id, status: 'confirmed');
  }

  Future<void> _reject(BuildContext context, CollectionsInboxCubit cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'collections.reject'.tr(),
      confirmLabel: 'collections.reject'.tr(),
      destructive: true,
    );
    if (!ok) return;
    await cubit.decide(id: claim.id, status: 'rejected');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CollectionsInboxCubit>();
    final t = context.tokens;
    final locale = context.locale.toString();

    return AppCard.item(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MoneyText(claim.amount, style: AppType.ledger(t.textPrimary, size: 20)),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: claim.status),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          DetailRow(
            label: 'invoice.payment_method'.tr(),
            value: Text(_methodLabel(claim.paymentMethod)),
          ),
          if (claim.referenceNo.isNotEmpty)
            DetailRow(
              label: 'invoice.reference_no'.tr(),
              value: Text(claim.referenceNo, textDirection: TextDirection.ltr),
            ),
          if (claim.receivedAt != null)
            DetailRow(
              label: 'collections.received_at'.tr(),
              value: Text(AppDates.date(claim.receivedAt, locale)),
            ),
          if (claim.isPending) ...[
            const SizedBox(height: AppTokens.space3),
            Row(
              children: [
                Expanded(
                  child: AppButton.solid(
                    label: 'collections.confirm'.tr(),
                    height: 48,
                    onPressed: () => _confirm(context, cubit),
                  ),
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: AppButton.outlineDanger(
                    label: 'collections.reject'.tr(),
                    height: 48,
                    onPressed: () => _reject(context, cubit),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Returns raised by traders. Approving one issues the credit note.
class ReturnsInboxView extends StatelessWidget {
  const ReturnsInboxView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ReturnsInboxCubit(getIt<ReceivablesRepository>())..load(),
        child: const _ReturnsBody(),
      );
}

/// A return still waiting on the supplier's decision. The documented
/// outcomes (`post_invoice_return.approved` / `.rejected`) — and a cancelled
/// one — are final, so they get no actions (mirrors `CollectionReceipt.isPending`).
bool _returnIsPending(PostInvoiceReturn request) =>
    !const {'approved', 'rejected', 'canceled'}.contains(request.status);

class _ReturnsBody extends StatelessWidget {
  const _ReturnsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ReturnsInboxCubit>();
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('returns_inbox.title'.tr())),
      body: PagedListView<PostInvoiceReturn>(
        state: cubit.state,
        onRefresh: cubit.refresh,
        onLoadMore: cubit.loadMore,
        emptyIcon: Icons.assignment_return_outlined,
        emptyTitle: 'returns_inbox.empty'.tr(),
        itemBuilder: (request) => AppCard.item(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'returns.reason_${request.reasonType}'.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  StatusChip(status: request.status),
                ],
              ),
              if (request.reasonNotes.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space1),
                Text(
                  request.reasonNotes,
                  style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
              if (request.lines.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                for (final line in request.lines)
                  DetailRow(
                    label: line.skuName,
                    value: Text(_fmt(line.qty), textDirection: TextDirection.ltr),
                  ),
              ],
              // Only an undecided return can be approved or rejected.
              if (_returnIsPending(request)) ...[
                const SizedBox(height: AppTokens.space3),
                AppBanner(
                  message: 'returns_inbox.approve_hint'.tr(),
                  margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                ),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.solid(
                        label: 'returns_inbox.approve'.tr(),
                        height: 48,
                        onPressed: () => cubit.decide(id: request.id, status: 'approved'),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppButton.outlineDanger(
                        label: 'returns_inbox.reject'.tr(),
                        height: 48,
                        onPressed: () => _reject(context, cubit, request.id),
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

  Future<void> _reject(BuildContext context, ReturnsInboxCubit cubit, int id) async {
    // A rejection must say why: the dialog keeps its confirm disabled until
    // a note is typed.
    final reason = await showAppReasonDialog(
      context,
      title: 'returns_inbox.reject'.tr(),
      hint: 'order.note_required'.tr(),
      confirmLabel: 'returns_inbox.reject'.tr(),
      required: true,
      destructive: true,
    );
    if (reason == null) return;
    await cubit.decide(id: id, status: 'rejected', reason: reason);
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}
