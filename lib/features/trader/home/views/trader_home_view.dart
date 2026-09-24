import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/repositories/ops_repository.dart';
import '../view_models/ops_panel_cubit.dart';
import '../../../shared/home/trade_hub.dart';
import 'ops_home_view.dart';

/// The trader home: `/ops/panel?workspace=trader`.
///
/// Quick actions are navigated by **`key`**, never by the `route` field the
/// server still ships — that one carries pre-REST RPC paths.
class TraderHomeView extends StatelessWidget {
  const TraderHomeView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OpsPanelCubit(
          getIt<OpsRepository>(),
          getIt<WorkspaceCubit>(),
          Workspace.trader,
        )..load(),
        child: OpsHomeView(
          workspace: Workspace.trader,
          title: 'home.trader_title'.tr(),
          actionHandlers: {
            // Ordering starts at the supplier, because a draft needs one and
            // `order_entry_ready` is checked there.
            'create_purchase_draft': (context) =>
                () => context.push(AppRoutes.traderSuppliers),
            'confirm_goods_receipt': (context) =>
                () => context.push(AppRoutes.traderShipments),
            'claim_payment': (context) => () => context.push(AppRoutes.traderInvoices),
            'approve_purchase_order': (context) =>
                () => context.push(AppRoutes.traderOrders),
          },
          documentRoutes: const {
            'order': AppRoutes.traderOrders,
            'deliver': AppRoutes.traderShipments,
            'shipment': AppRoutes.traderShipments,
            'invoice': AppRoutes.traderInvoices,
            'payable': AppRoutes.traderInvoices,
            'contract': AppRoutes.contracts,
          },
        ),
      );
}

/// The trader's Trade hub: buying, logistics and money, in the order a
/// purchase moves through them.
class TraderDocumentsTab extends StatelessWidget {
  const TraderDocumentsTab({super.key});

  @override
  Widget build(BuildContext context) => TradeHub(
        sections: [
          (
            label: 'trade.section_buying'.tr(),
            entries: [
              (label: 'supplier.title'.tr(), icon: Icons.storefront_outlined, route: AppRoutes.traderSuppliers),
              (label: 'catalog.title'.tr(), icon: Icons.inventory_2_outlined, route: AppRoutes.traderCatalog),
              (label: 'order.my_orders'.tr(), icon: Icons.receipt_long_outlined, route: AppRoutes.traderOrders),
            ],
          ),
          (
            label: 'trade.section_logistics'.tr(),
            entries: [
              (label: 'shipment.title'.tr(), icon: Icons.local_shipping_outlined, route: AppRoutes.traderShipments),
            ],
          ),
          (
            label: 'trade.section_finance'.tr(),
            entries: [
              (label: 'invoice.payables'.tr(), icon: Icons.request_quote_outlined, route: AppRoutes.traderInvoices),
            ],
          ),
        ],
      );
}
