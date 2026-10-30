import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_dates.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/trade/invoice.dart';
import '../../../data/models/trade/payment_notice.dart';
import '../../../data/repositories/receivables_repository.dart';
import '../../shared/compliance/views/invoice_money_sections.dart';
import '../../shared/compliance/views/payment_notice_widgets.dart';
import '../view_models/supplier_cubits.dart';

/// «مدفوعات للمراجعة»: what traders say they paid.
///
/// The first tab is the website's flow — payment notices, `submitted` by
/// default, confirmed or rejected where the server says `can_review`. The
/// second keeps the older trader claims (draft collections) until they are
/// all settled. Confirming either is what moves the invoice balance.
class CollectionsInboxView extends StatelessWidget {
  const CollectionsInboxView({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CollectionsInboxCubit(getIt<ReceivablesRepository>())..load()),
          BlocProvider(create: (_) => PaymentNoticesInboxCubit(getIt<ReceivablesRepository>())..load()),
        ],
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text('payment_notice.to_review'.tr()),
              bottom: TabBar(
                tabs: [
                  Tab(text: 'payment_notice.title'.tr()),
                  Tab(text: 'collections.title'.tr()),
                ],
              ),
            ),
            body: const TabBarView(children: [_NoticesBody(), _CollectionsBody()]),
          ),
        ),
      );
}

class _NoticesBody extends StatelessWidget {
  const _NoticesBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PaymentNoticesInboxCubit>();

    return Column(
      children: [
        AppFilterBar(
          options: [
            for (final status in PaymentNoticesInboxCubit.filters)
              AppFilterOption(
                label: status == null ? 'order.filter_all'.tr() : 'status.$status'.tr(),
                selected: cubit.status == status,
                onTap: () => cubit.setStatus(status),
              ),
          ],
        ),
        Expanded(
          child: PagedListView<PaymentNotice>(
            state: cubit.state,
            onRefresh: cubit.refresh,
            onLoadMore: cubit.loadMore,
            emptyIcon: Icons.account_balance_wallet_outlined,
            emptyTitle: 'payment_notice.empty'.tr(),
            itemBuilder: (notice) => PaymentNoticeCard(
              notice: notice,
              showInvoice: true,
              onReviewed: cubit.refresh,
            ),
          ),
        ),
      ],
    );
  }
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

    return Material(
      type: MaterialType.transparency,
      child: Column(
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
          // The invoice it pays, the trader's note and the proof — what the
          // supplier checks before confirming (guide Part 13.4).
          if (claim.invoice != null || claim.invoiceId != null)
            DetailRow(
              label: 'collections.invoice'.tr(),
              value: InkWell(
                onTap: claim.invoiceId == null
                    ? null
                    : () => context.push(AppRoutes.invoiceComplianceFor(claim.invoiceId!)),
                child: Text(
                  (claim.invoice?.name.isNotEmpty ?? false) ? claim.invoice!.name : '#${claim.invoiceId}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: t.primary),
                ),
              ),
            ),
          if (claim.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.space1),
              child: Text(claim.note, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (claim.proofFile.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.text(
                label: 'collections.view_proof'.tr(),
                icon: Icons.attach_file_rounded,
                height: 36,
                onPressed: () => openProof(claim.proofFile),
              ),
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
