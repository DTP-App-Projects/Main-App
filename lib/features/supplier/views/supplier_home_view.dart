import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../shared/compliance/compliance_widgets.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../core/workspace/workspace.dart';
import '../../../core/workspace/workspace_cubit.dart';
import '../../../data/repositories/ops_repository.dart';
import '../../trader/home/view_models/ops_panel_cubit.dart';
import '../../shared/home/trade_hub.dart';
import '../../trader/home/views/ops_home_view.dart';

/// The supplier home: `/ops/panel?workspace=supplier`.
///
/// Same structure as the trader home, different actions — which is the whole
/// point of the server-driven panel.
class SupplierHomeView extends StatelessWidget {
  const SupplierHomeView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OpsPanelCubit(
          getIt<OpsRepository>(),
          getIt<WorkspaceCubit>(),
          Workspace.supplier,
        )..load(),
        child: OpsHomeView(
          workspace: Workspace.supplier,
          title: 'home.supplier_title'.tr(),
          actionHandlers: {
            'create_delivery_note': (context) =>
                () => context.push(AppRoutes.supplierOrders),
            'dispatch_delivery': (context) =>
                () => context.push(AppRoutes.supplierOutbound),
            'track_outbound_shipments': (context) =>
                () => context.push(AppRoutes.supplierOutbound),
            'issue_invoice': (context) => () => context.push(AppRoutes.supplierInvoices),
            'record_collection': (context) =>
                () => context.push(AppRoutes.supplierCollections),
            'confirm_collection': (context) =>
                () => context.push(AppRoutes.supplierCollections),
            'approve_purchase_order': (context) =>
                () => context.push(AppRoutes.supplierOrders),
          },
          documentRoutes: const {
            'order': AppRoutes.supplierOrders,
            'deliver': AppRoutes.supplierOutbound,
            'outbound': AppRoutes.supplierOutbound,
            'shipment': AppRoutes.supplierOutbound,
            'invoice': AppRoutes.supplierInvoices,
            'receivable': AppRoutes.supplierInvoices,
            'collection': AppRoutes.supplierCollections,
            // Return notes (RN-), accepted with a code — not the legacy inbox.
            'return': AppRoutes.returnNotes,
            'contract': AppRoutes.contracts,
          },
        ),
      );
}

/// The supplier's Trade hub: sales, logistics, money, catalog and partners.
class SupplierDocumentsTab extends StatelessWidget {
  const SupplierDocumentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // The fleet entries follow their read permissions (the owner has all);
    // the shell itself is supplier-only, so a trader never sees them.
    final workspace = context.watch<WorkspaceCubit>().state;
    final fleet = workspace?.can('fleet.view') ?? false;
    final transfers = workspace?.can('internal_transfers.view') ?? false;

    return TradeHub(
        sections: [
          (
            label: 'trade.section_sales'.tr(),
            entries: [
              (label: 'order.inbox'.tr(), icon: Icons.inbox_outlined, route: AppRoutes.supplierOrders),
              (label: 'quotation.title'.tr(), icon: Icons.request_page_outlined, route: AppRoutes.quotations),
            ],
          ),
          // The contract chain: request → framework agreement → quotation →
          // order → acknowledgment (compliance release).
          (
            label: 'trade.section_contracts'.tr(),
            entries: [
              (label: 'rr.title'.tr(), icon: Icons.handshake_outlined, route: AppRoutes.relationshipRequests),
              (label: 'approvals.title'.tr(), icon: Icons.task_alt_rounded, route: AppRoutes.approvals),
              (label: 'agreement.fa_title'.tr(), icon: Icons.description_outlined, route: AppRoutes.agreementsFor(AgreementKind.framework)),
              (label: 'agreement.addenda_title'.tr(), icon: Icons.note_add_outlined, route: AppRoutes.agreementsFor(AgreementKind.addendum)),
              (label: 'agreement.ack_title'.tr(), icon: Icons.fact_check_outlined, route: AppRoutes.agreementsFor(AgreementKind.acknowledgment)),
            ],
          ),
          (
            label: 'trade.section_logistics'.tr(),
            entries: [
              (label: 'outbound.title'.tr(), icon: Icons.local_shipping_outlined, route: AppRoutes.supplierOutbound),
              (label: 'grn.title'.tr(), icon: Icons.fact_check_outlined, route: AppRoutes.goodsReceipts),
              (label: 'rn.title'.tr(), icon: Icons.assignment_return_outlined, route: AppRoutes.returnNotes),
              (label: 'consignment.title'.tr(), icon: Icons.inventory_2_outlined, route: AppRoutes.consignment),
              (label: 'custody.title'.tr(), icon: Icons.warehouse_outlined, route: AppRoutes.custodyLedger),
            ],
          ),
          (
            label: 'trade.section_finance'.tr(),
            entries: [
              (label: 'invoice.receivables'.tr(), icon: Icons.request_quote_outlined, route: AppRoutes.supplierInvoices),
              (label: 'collections.title'.tr(), icon: Icons.account_balance_wallet_outlined, route: AppRoutes.supplierCollections),
              (label: 'late.title'.tr(), icon: Icons.mark_email_unread_outlined, route: AppRoutes.latePaymentNotices),
              (label: 'dispute.title'.tr(), icon: Icons.inventory_outlined, route: AppRoutes.disputePacks),
            ],
          ),
          (
            label: 'trade.section_catalog'.tr(),
            entries: [
              (label: 'supplier_catalog.title'.tr(), icon: Icons.inventory_2_outlined, route: AppRoutes.supplierCatalog),
              (label: 'pricing.title'.tr(), icon: Icons.sell_outlined, route: AppRoutes.supplierPricing),
              // «الكتالوج والمخزون», as on the web: van sales, delivery contracts and
              // internal transfers sit with the catalog.
              if (fleet)
                (label: 'van.title'.tr(), icon: Icons.local_shipping_outlined, route: AppRoutes.vanSales),
              if (fleet)
                (label: 'fleet_contract.title'.tr(), icon: Icons.handshake_outlined, route: AppRoutes.deliveryContracts),
              if (transfers)
                (label: 'transfer.title'.tr(), icon: Icons.swap_horiz_rounded, route: AppRoutes.internalTransfers),
            ],
          ),
          (
            label: 'trade.section_partners'.tr(),
            entries: [
              (label: 'traders.title'.tr(), icon: Icons.storefront_outlined, route: AppRoutes.supplierTraders),
              (label: 'relationship.title'.tr(), icon: Icons.handshake_outlined, route: AppRoutes.supplierRelationships),
              (label: 'marketer.supplier_title'.tr(), icon: Icons.campaign_outlined, route: AppRoutes.supplierMarketers),
            ],
          ),
        ],
      );
  }
}
