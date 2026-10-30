import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/supplier_summary.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../shared/compliance/views/relationship_request_sheet.dart';
import '../view_models/suppliers_cubits.dart';
import 'suppliers_view.dart';

/// One supplier: who they are, whether a relationship exists, what they sell,
/// and the single button that starts an order.
class SupplierDetailView extends StatelessWidget {
  final int supplierOrganizationId;

  const SupplierDetailView({super.key, required this.supplierOrganizationId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SupplierDetailCubit(getIt<CatalogRepository>(), supplierOrganizationId)..load(),
    child: const _SupplierDetailBody(),
  );
}

class _SupplierDetailBody extends StatelessWidget {
  const _SupplierDetailBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SupplierDetailCubit>();
    final state = cubit.state;
    final supplier = state.supplier;
    final locale = context.locale.toString();

    // Leaving hands the latest row back, so the list can show a request
    // sent here without reloading.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(state.supplier);
      },
      child: Scaffold(
        // The name leads the header card; the bar names the kind of screen.
        appBar: AppBar(
          title: Text('supplier.detail_title'.tr()),
          actions: [
            if (supplier != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppTokens.space4),
                child: AppCircleButton(
                  size: 40,
                  tooltip: state.isFollowing ? 'supplier.unfollow'.tr() : 'supplier.follow'.tr(),
                  icon: state.isFollowing ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  onPressed: cubit.toggleFollow,
                ),
              ),
          ],
        ),
        bottomNavigationBar: supplier == null ? null : _OrderGate(supplier: supplier, state: state),
        body: Builder(
          builder: (context) {
            if (state.loading && supplier == null) return const DetailSkeleton();
            if (supplier == null) {
              if (state.offline) return AppOfflineState(onRetry: cubit.load);
              final message = state.errorMessage;
              return AppErrorState(
                message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
                onRetry: cubit.load,
              );
            }

            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: AppTokens.pagePadding,
                children: [
                  _SupplierHeader(supplier: supplier),
                  const SizedBox(height: AppTokens.space3),
                  Row(
                    children: [
                      Expanded(
                        child: AppStatTile(
                          label: 'supplier.contracts'.tr(),
                          value: '${supplier.activeContractsCount}',
                          tone: AppTone.neutral,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        child: AppStatTile(
                          label: 'home.products'.tr(),
                          value: '${supplier.productsCount}',
                          tone: AppTone.neutral,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        child: AppStatTile(
                          label: 'home.skus'.tr(),
                          value: '${supplier.skusCount}',
                          tone: AppTone.neutral,
                        ),
                      ),
                    ],
                  ),

                  AppSectionLabel('supplier.catalog'.tr()),
                  if (state.publicCatalog.isEmpty)
                    AppCard(
                      child: Column(
                        children: [
                          const AppIconCircle(Icons.inventory_2_outlined, tone: AppTone.neutral),
                          const SizedBox(height: AppTokens.space3),
                          Text(
                            'catalog.empty'.tr(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    AppMenuGroup(
                      children: [
                        for (final product in state.publicCatalog)
                          AppMenuRow(
                            icon: Icons.inventory_2_outlined,
                            title: product.displayName(locale),
                            subtitle: 'catalog.sku_count'.tr(
                              namedArgs: {'count': '${product.skusCount}'},
                            ),
                            onTap: () => context.push(AppRoutes.productDetailFor(product.detailId)),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppTokens.space1,
                      AppTokens.space3,
                      AppTokens.space1,
                      0,
                    ),
                    child: Text(
                      'supplier.catalog_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Avatar, name, standing and sectors: the screen's one bold anchor.
class _SupplierHeader extends StatelessWidget {
  final SupplierSummary supplier;

  const _SupplierHeader({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppInitialAvatar(name: supplier.displayName, size: 56),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.displayName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppTokens.space2),
                    StatusChip(status: supplier.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          DetailRow(
            label: 'supplier.relationship'.tr(),
            value: StatusChip(status: supplier.relationshipStatus),
          ),
          if (supplier.sectors.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space2),
            Wrap(
              spacing: AppTokens.space2,
              runSpacing: AppTokens.space2,
              children: [
                for (final sector in supplier.sectors) AppBadge(sector.name, tone: AppTone.neutral),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The one gate: `order_entry_ready` is approved relationship *and* an
/// active contract. Anything less and the server refuses the draft, so the
/// button does not pretend otherwise, and the reason is said once, here.
class _OrderGate extends StatelessWidget {
  final SupplierSummary supplier;
  final SupplierDetailState state;

  const _OrderGate({required this.supplier, required this.state});

  /// Asks for the supply model first (guide Part 6.2), sends the request,
  /// then confirms it — the button turning into "Request sent" is the
  /// lasting sign, this is the moment's one.
  Future<void> _request(BuildContext context, SupplierDetailCubit cubit) async {
    final draft = await showRelationshipRequestSheet(context, counterpartyName: supplier.displayName);
    if (draft == null || !context.mounted) return;
    await cubit.requestRelationship(draft);
    if (!context.mounted || !cubit.state.action.isSuccess) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('supplier.request_sent_toast'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SupplierDetailCubit>();
    final message = state.action.message;
    final reason = supplier.orderBlockedReason;

    final Widget action;
    if (supplier.canStartOrder) {
      action = AppButton.primary(
        label: 'order.create'.tr(),
        icon: Icons.add_shopping_cart_rounded,
        onPressed: () => context.push(AppRoutes.newOrder(supplierOrganizationId: supplier.id)),
      );
    } else if (!supplier.hasRelationship || supplier.canRequestAgain) {
      action = SubmitButton(
        busy: state.action.isSubmitting,
        label: supplier.canRequestAgain
            ? 'supplier.request_again'.tr()
            : 'supplier.request_relationship'.tr(),
        onPressed: () => _request(context, cubit),
      );
    } else if (supplier.isRequestPending) {
      // Already asked: say so, and do not offer to ask twice.
      action = AppButton.primary(
        label: 'supplier.request_sent'.tr(),
        icon: Icons.hourglass_top_rounded,
        onPressed: null,
      );
    } else {
      action = AppButton.primary(
        label: 'order.create'.tr(),
        icon: Icons.lock_outline_rounded,
        onPressed: null,
      );
    }

    final showReason = !supplier.canStartOrder && reason != null;
    final hasMessage = message != null && message.isNotEmpty;

    return AppBottomBar(
      leading: (!showReason && !hasMessage)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasMessage)
                  AppBanner(
                    message: message,
                    tone: AppTone.danger,
                    margin: showReason
                        ? const EdgeInsetsDirectional.only(bottom: AppTokens.space2)
                        : EdgeInsetsDirectional.zero,
                  ),
                if (showReason)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OrderReadinessBadge(supplier: supplier),
                  ),
              ],
            ),
      child: action,
    );
  }
}
