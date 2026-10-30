import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/models/advanced/contract.dart';
import '../../../../data/repositories/contracts_repository.dart';
import '../view_models/approvals_cubit.dart';

/// «صندوق الموافقات» — tabs all / purchase orders / contracts (guide 8.7).
class ApprovalsView extends StatelessWidget {
  const ApprovalsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ApprovalsCubit(getIt<ContractsRepository>())..load(),
        child: const _ApprovalsBody(),
      );
}

class _ApprovalsBody extends StatelessWidget {
  const _ApprovalsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ApprovalsCubit>();
    final state = cubit.state;
    final inbox = state.inbox;
    final showOrders = state.filter != ApprovalsFilter.contracts;
    final showContracts = state.filter != ApprovalsFilter.purchaseOrders;
    final orders = showOrders ? inbox.purchaseOrders : const <PurchaseOrderApproval>[];
    final contracts = showContracts ? inbox.contracts : const <Contract>[];

    return Scaffold(
      appBar: AppBar(title: Text('approvals.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              for (final filter in ApprovalsFilter.values)
                AppFilterOption(
                  label: '${'approvals.filter_${filter.name}'.tr()}  ${switch (filter) {
                    ApprovalsFilter.all => inbox.total,
                    ApprovalsFilter.purchaseOrders => inbox.purchaseOrders.length,
                    ApprovalsFilter.contracts => inbox.contracts.length,
                  }}',
                  selected: state.filter == filter,
                  onTap: () => cubit.setFilter(filter),
                ),
            ],
          ),
          if ((state.action.message ?? '').isNotEmpty)
            AppBanner(
              message: state.action.message!,
              tone: AppTone.danger,
              margin: const EdgeInsetsDirectional.fromSTEB(AppTokens.gutter, 0, AppTokens.gutter, AppTokens.space2),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.loading && inbox.total == 0) return const ListSkeleton(rows: 4);
                if (state.errorMessage != null && inbox.total == 0) {
                  if (state.offline) return AppOfflineState(onRetry: cubit.load);
                  return AppErrorState(
                    message: state.errorMessage!.isEmpty ? 'errors.generic'.tr() : state.errorMessage!,
                    onRetry: cubit.load,
                  );
                }
                if (orders.isEmpty && contracts.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'approvals.empty'.tr(),
                    body: 'approvals.empty_hint'.tr(),
                  );
                }
                return RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: AppTokens.pagePadding,
                    children: [
                      for (final approval in orders) _OrderApprovalCard(approval: approval),
                      for (final contract in contracts) _ContractApprovalCard(contract: contract),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderApprovalCard extends StatelessWidget {
  final PurchaseOrderApproval approval;

  const _OrderApprovalCard({required this.approval});

  void _openOrder(BuildContext context) {
    final id = approval.purchaseOrderId;
    if (id == null) return;
    final supplier = getIt<WorkspaceCubit>().state?.active == Workspace.supplier;
    context.push(supplier ? AppRoutes.supplierOrderDetailFor(id) : AppRoutes.orderDetailFor(id));
  }

  Future<void> _reject(BuildContext context) async {
    final cubit = context.read<ApprovalsCubit>();
    final reason = await showAppReasonDialog(
      context,
      title: 'approvals.reject_title'.tr(),
      hint: 'approvals.reject_hint'.tr(),
      required: true,
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    await cubit.decide(approval, 'rejected', note: reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ApprovalsCubit>();
    final deciding = context.select<ApprovalsCubit, bool>((c) => c.state.decidingId == approval.id);
    final title = approval.orderCode.isNotEmpty
        ? approval.orderCode
        : (approval.purchaseOrderId == null ? '#${approval.id}' : '#${approval.purchaseOrderId}');

    return AppCard.item(
      onTap: approval.purchaseOrderId == null ? null : () => _openOrder(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconCircle(Icons.receipt_long_outlined),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall, textDirection: TextDirection.ltr),
                    if (approval.counterpartyName.isNotEmpty || approval.stepLabel.isNotEmpty)
                      Text(
                        [approval.counterpartyName, approval.stepLabel].where((s) => s.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (approval.amount != null) MoneyText(approval.amount!, style: theme.textTheme.titleSmall),
            ],
          ),
          if (approval.isPending) ...[
            const SizedBox(height: AppTokens.space3),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: 'approvals.reject'.tr(),
                    height: 44,
                    onPressed: deciding ? null : () => _reject(context),
                  ),
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: AppButton.primary(
                    label: 'approvals.approve'.tr(),
                    height: 44,
                    busy: deciding,
                    onPressed: deciding ? null : () => cubit.decide(approval, 'approved'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppTokens.space2),
            Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(status: approval.status)),
          ],
        ],
      ),
    );
  }
}

/// Contracts carry their own approval chain; the decision is made on the
/// contract's page, where the chain and its notes are.
class _ContractApprovalCard extends StatelessWidget {
  final Contract contract;

  const _ContractApprovalCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    return AppCard.item(
      onTap: () => context.push(AppRoutes.contractDetailFor(contract.id)),
      child: Row(
        children: [
          const AppIconCircle(Icons.description_outlined),
          const SizedBox(width: AppTokens.space3),
          Expanded(child: Text(contract.label(locale), style: Theme.of(context).textTheme.titleSmall)),
          StatusChip(status: contract.status),
          const SizedBox(width: AppTokens.space2),
          DirectionalChevron(size: 20, color: context.tokens.iconMuted),
        ],
      ),
    );
  }
}
