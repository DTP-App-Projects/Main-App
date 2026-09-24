import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_dates.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../core/workspace/workspace.dart';
import '../../../data/models/trade/purchase_order.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../trader/orders/view_models/orders_cubits.dart';

/// Orders waiting on the supplier.
///
/// `?role=supplier` is always sent, and the inbox opens on the two statuses
/// that actually need a decision — everything else is a filter tap away.
const _inboxDefault = ['submitted', 'under_review'];

const _supplierStatuses = [
  'submitted',
  'under_review',
  'approved',
  'ready',
  'rejected',
  'canceled',
];

class OrdersInboxView extends StatelessWidget {
  const OrdersInboxView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) {
          final cubit = OrdersCubit(getIt<OrdersRepository>(), role: Workspace.supplier);
          cubit.statuses.addAll(_inboxDefault);
          return cubit..load();
        },
        child: const _InboxBody(),
      );
}

class _InboxBody extends StatelessWidget {
  const _InboxBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OrdersCubit>();
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('order.inbox'.tr())),
      body: Column(
        children: [
          // The default preset (submitted + under review) shows as selected
          // pills, so the opening filter explains itself.
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.statuses.isEmpty,
                onTap: cubit.clearStatuses,
              ),
              for (final status in _supplierStatuses)
                AppFilterOption(
                  label: 'status.$status'.tr(),
                  selected: cubit.statuses.contains(status),
                  onTap: () => cubit.toggleStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<PurchaseOrder>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.inbox_outlined,
              emptyTitle: 'order.inbox_empty'.tr(),
              emptyBody: 'order.inbox_empty_hint'.tr(),
              itemBuilder: (order) => DocumentTile(
                code: order.code,
                // The counterparty on this side is the trader, not the supplier.
                title: order.trader?.name ?? '',
                subtitle: order.requestedDeliveryDate == null
                    ? ''
                    : '${'order.requested_delivery'.tr()}: '
                        '${AppDates.date(order.requestedDeliveryDate, locale)}',
                status: order.status,
                amount: order.grandTotal,
                currency: order.currency,
                icon: Icons.inbox_rounded,
                // A failed credit check is the reason an order sits here, so
                // it earns a danger-tint badge rather than a line of small print.
                badge: order.creditCheckStatus.isEmpty ||
                        order.creditCheckStatus == 'passed'
                    ? null
                    : AppBadge(
                        'order.credit_check'.tr(),
                        tone: AppTone.danger,
                        icon: Icons.credit_card_off_rounded,
                      ),
                onTap: () => context.push(AppRoutes.supplierOrderDetailFor(order.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
