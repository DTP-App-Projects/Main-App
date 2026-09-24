import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../view_models/orders_cubits.dart';

/// The statuses a trader filters by. They are the server's own values; only
/// the ordering here is a client choice.
const _traderStatuses = [
  'submitted',
  'under_review',
  'approved',
  'ready',
  'rejected',
  'canceled',
];

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OrdersCubit(getIt<OrdersRepository>())..load(),
        child: const _OrdersBody(),
      );
}

class _OrdersBody extends StatelessWidget {
  const _OrdersBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OrdersCubit>();
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('order.my_orders'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.statuses.isEmpty,
                onTap: cubit.clearStatuses,
              ),
              for (final status in _traderStatuses)
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
              emptyIcon: Icons.receipt_long_outlined,
              emptyTitle: 'order.empty'.tr(),
              emptyBody: 'order.empty_hint'.tr(),
              itemBuilder: (order) => DocumentTile(
                code: order.code,
                title: order.supplier?.name ?? '',
                subtitle: order.requestedDeliveryDate == null
                    ? ''
                    : '${'order.requested_delivery'.tr()}: '
                        '${AppDates.date(order.requestedDeliveryDate, locale)}',
                status: order.status,
                amount: order.grandTotal,
                currency: order.currency,
                icon: Icons.receipt_long_outlined,
                onTap: () => context.push(AppRoutes.orderDetailFor(order.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
