import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/models/advanced/contract.dart';
import '../../../../data/repositories/contracts_repository.dart';
import '../view_models/advanced_cubits.dart';

/// A state view never shows an empty message.
String _messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

/// The contract type is a server enum the app cannot enumerate: a known one
/// is translated, anything else is shown as readable words.
String _typeLabel(String type) {
  if (type.isEmpty) return '—';
  final key = 'contract.type_$type';
  final translated = key.tr();
  if (translated != key) return translated;
  final words = type.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

/// Statuses that stop a contract — confirmed as destructive.
const _stoppingStatuses = {'suspended', 'terminated', 'expired'};

/// Contracts. An **active** one is half of what unlocks ordering, so its
/// status is the headline rather than a detail.
class ContractsView extends StatelessWidget {
  const ContractsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ContractsCubit(getIt<ContractsRepository>())..load(),
        child: const _ContractsBody(),
      );
}

class _ContractsBody extends StatelessWidget {
  const _ContractsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ContractsCubit>();
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('contract.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.status == null,
                onTap: () => cubit.setStatus(null),
              ),
              for (final status in Contract.statuses)
                AppFilterOption(
                  label: 'contract.status_$status'.tr(),
                  selected: cubit.status == status,
                  onTap: () => cubit.setStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<Contract>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.description_outlined,
              emptyTitle: 'contract.empty'.tr(),
              emptyBody: 'contract.empty_hint'.tr(),
              itemBuilder: (contract) => DocumentTile(
                code: contract.code,
                title: contract.label(locale),
                subtitle: _typeLabel(contract.contractType),
                status: contract.status,
                icon: Icons.description_outlined,
                badge: contract.pendingApprovals.isEmpty
                    ? null
                    : AppBadge(
                        'contract.pending_approvals'.tr(
                          namedArgs: {'count': '${contract.pendingApprovals.length}'},
                        ),
                        tone: AppTone.info,
                        icon: Icons.how_to_reg_outlined,
                      ),
                onTap: () => context.push(AppRoutes.contractDetailFor(contract.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One contract: its terms, and the approval chain that decides it.
class ContractDetailView extends StatelessWidget {
  final int contractId;

  const ContractDetailView({super.key, required this.contractId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            ContractDetailCubit(getIt<ContractsRepository>(), contractId)..load(),
        child: const _ContractDetailBody(),
      );
}

class _ContractDetailBody extends StatelessWidget {
  const _ContractDetailBody();

  Future<void> _changeStatus(BuildContext context, String status) async {
    final cubit = context.read<ContractDetailCubit>();
    final label = 'contract.status_$status'.tr();
    final confirmed = await showAppConfirm(
      context,
      title: 'contract.change_status_confirm'.tr(namedArgs: {'status': label}),
      confirmLabel: label,
      destructive: _stoppingStatuses.contains(status),
    );
    if (confirmed) await cubit.setStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ContractDetailCubit>();
    final state = cubit.state;
    final contract = state.contract;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final workspace = context.watch<WorkspaceCubit>().state;

    // `contracts.approve` is a separate permission from `contracts.manage`;
    // an owner passes both.
    final canApprove = workspace?.can('contracts.approve') ?? false;
    final canManage = workspace?.can('contracts.manage') ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('contract.detail_title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading && contract == null) return const DetailSkeleton();
          if (contract == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                FormMessage(message: state.action.message),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contract.label(locale), style: theme.textTheme.titleMedium),
                                if (contract.code.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    contract.code,
                                    style: AppType.code(t.textSecondary),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: contract.status),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space3),
                      DetailRow(
                        label: 'contract.type'.tr(),
                        value: Text(_typeLabel(contract.contractType)),
                      ),
                      DetailRow(
                        label: 'contract.starts'.tr(),
                        value: DateText(contract.startDate),
                      ),
                      DetailRow(
                        label: 'contract.ends'.tr(),
                        value: DateText(contract.endDate),
                      ),
                      DetailRow(
                        label: 'contract.auto_renew'.tr(),
                        value: Text(contract.autoRenew ? 'common.yes'.tr() : '—'),
                      ),
                    ],
                  ),
                ),

                if (contract.terms.isNotEmpty) ...[
                  AppSectionLabel('contract.terms'.tr()),
                  AppCard(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppTokens.cardPadding,
                      vertical: AppTokens.space3,
                    ),
                    child: Column(
                      children: [
                        for (final term in contract.terms)
                          DetailRow(
                            label: term.label.isEmpty ? term.key : term.label,
                            value: Text(term.value),
                          ),
                      ],
                    ),
                  ),
                ],

                if (contract.approvals.isNotEmpty) ...[
                  AppSectionLabel('contract.approvals'.tr()),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < contract.approvals.length; i++)
                          _ApprovalStep(
                            number: i + 1,
                            last: i == contract.approvals.length - 1,
                            approval: contract.approvals[i],
                            canApprove: canApprove,
                            busy: state.action.isSubmitting,
                          ),
                      ],
                    ),
                  ),
                ],

                if (canManage) ...[
                  AppSectionLabel('contract.change_status'.tr()),
                  Wrap(
                    spacing: AppTokens.space2,
                    runSpacing: AppTokens.space2,
                    children: [
                      for (final status in Contract.statuses)
                        if (status != contract.status)
                          _stoppingStatuses.contains(status)
                              ? AppButton.outlineDanger(
                                  label: 'contract.status_$status'.tr(),
                                  expand: false,
                                  height: 48,
                                  onPressed: state.action.isSubmitting
                                      ? null
                                      : () => _changeStatus(context, status),
                                )
                              : AppButton.outline(
                                  label: 'contract.status_$status'.tr(),
                                  expand: false,
                                  height: 48,
                                  onPressed: state.action.isSubmitting
                                      ? null
                                      : () => _changeStatus(context, status),
                                ),
                    ],
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

/// One approval in the chain, as a numbered step on a vertical rail.
class _ApprovalStep extends StatelessWidget {
  final int number;
  final bool last;
  final ContractApproval approval;
  final bool canApprove;
  final bool busy;

  const _ApprovalStep({
    required this.number,
    required this.last,
    required this.approval,
    required this.canApprove,
    required this.busy,
  });

  Future<void> _reject(BuildContext context) async {
    final cubit = context.read<ContractDetailCubit>();
    final confirmed = await showAppConfirm(
      context,
      title: 'contract.reject_confirm'.tr(),
      confirmLabel: 'returns_inbox.reject'.tr(),
      destructive: true,
    );
    if (confirmed) {
      await cubit.decideApproval(approvalId: approval.id, status: 'rejected');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final cubit = context.read<ContractDetailCubit>();
    final locale = context.locale.toString();
    final tone = toneForStatus(approval.status);
    final decided = !approval.isPending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: decided ? t.toneTint(tone) : t.neutralTint,
                  shape: BoxShape.circle,
                ),
                child: decided && tone == StatusTone.good
                    ? Icon(Icons.check_rounded, size: 18, color: t.toneColor(tone))
                    : decided && tone == StatusTone.danger
                        ? Icon(Icons.close_rounded, size: 18, color: t.toneColor(tone))
                        : Text(
                            '$number',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: t.textSecondary,
                            ),
                          ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space1),
                    decoration: BoxDecoration(
                      color: t.divider,
                      borderRadius: AppTokens.fullRadius,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: last ? 0 : AppTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          approval.approverName.isEmpty
                              ? 'contract.approval'.tr()
                              : approval.approverName,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      StatusChip(status: approval.status.isEmpty ? 'pending' : approval.status),
                    ],
                  ),
                  if (approval.decidedAt != null)
                    Text(
                      AppDates.dateTime(approval.decidedAt, locale),
                      style: theme.textTheme.labelSmall,
                    ),
                  if (approval.note.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space1),
                    Text(approval.note, style: theme.textTheme.bodySmall),
                  ],
                  if (approval.isPending && canApprove) ...[
                    const SizedBox(height: AppTokens.space3),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.solid(
                            label: 'returns_inbox.approve'.tr(),
                            height: 48,
                            onPressed: busy
                                ? null
                                : () => cubit.decideApproval(
                                      approvalId: approval.id,
                                      status: 'approved',
                                    ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: AppButton.outlineDanger(
                            label: 'returns_inbox.reject'.tr(),
                            height: 48,
                            onPressed: busy ? null : () => _reject(context),
                          ),
                        ),
                      ],
                    ),
                  ] else if (approval.isPending && !canApprove) ...[
                    const SizedBox(height: AppTokens.space2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 16, color: t.iconMuted),
                        const SizedBox(width: AppTokens.space1 + 2),
                        Expanded(
                          child: Text(
                            'contract.approve_permission'.tr(),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
