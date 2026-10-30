import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/supplier_summary.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../view_models/suppliers_cubits.dart';

/// Find suppliers. The only thing that matters on each row is whether the
/// trader can actually order from them — `order_entry_ready`.
class SuppliersView extends StatelessWidget {
  const SuppliersView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SuppliersCubit(getIt<CatalogRepository>())..load(),
        child: const _SuppliersBody(),
      );
}

class _SuppliersBody extends StatefulWidget {
  const _SuppliersBody();

  @override
  State<_SuppliersBody> createState() => _SuppliersBodyState();
}

class _SuppliersBodyState extends State<_SuppliersBody> {
  /// The API notes call for at least this much; a keystroke is never a request.
  static const _debounce = Duration(milliseconds: 400);

  final _search = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => context.read<SuppliersCubit>().setSearch(value));
  }

  Future<void> _open(SupplierSummary supplier) async {
    final cubit = context.read<SuppliersCubit>();
    final updated = await context.push<SupplierSummary>(AppRoutes.supplierDetailFor(supplier.id));
    if (updated != null) cubit.replace(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SuppliersCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('supplier.title'.tr())),
      body: Column(
        children: [
          AppSearchField(
            controller: _search,
            onChanged: _onChanged,
            onSubmitted: context.read<SuppliersCubit>().setSearch,
            hint: 'supplier.search_hint'.tr(),
          ),
          Expanded(
            child: PagedListView<SupplierSummary>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.storefront_outlined,
              emptyTitle: 'supplier.empty'.tr(),
              emptyBody: _search.text.isEmpty ? null : 'lookup.empty_search'.tr(),
              itemBuilder: (supplier) => _SupplierCard(
                supplier: supplier,
                onTap: () => _open(supplier),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierSummary supplier;
  final VoidCallback onTap;

  const _SupplierCard({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return AppCard.item(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInitialAvatar(name: supplier.displayName),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        supplier.displayName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    // Already asked: say it in words, not as a raw status.
                    if (supplier.isRequestPending)
                      AppBadge(
                        'supplier.request_sent'.tr(),
                        tone: AppTone.info,
                        icon: Icons.hourglass_top_rounded,
                      )
                    else if (supplier.canRequestAgain)
                      AppBadge(
                        'supplier.request_declined'.tr(),
                        tone: AppTone.warning,
                        icon: Icons.replay_rounded,
                      )
                    else
                      StatusChip(status: supplier.relationshipStatus),
                  ],
                ),
                const SizedBox(height: AppTokens.space1),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: t.iconMuted),
                    const SizedBox(width: AppTokens.space1),
                    Expanded(
                      child: Text(
                        'supplier.counts'.tr(namedArgs: {
                          'products': '${supplier.productsCount}',
                          'skus': '${supplier.skusCount}',
                        }),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space3),
                OrderReadinessBadge(supplier: supplier),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppTokens.space3),
            child: DirectionalChevron(size: 20, color: t.iconMuted),
          ),
        ],
      ),
    );
  }
}

/// The single gate on ordering, stated plainly rather than as a disabled
/// button with no explanation: a teal pill when the trader can order, a
/// danger-tinted one with the reason when they cannot.
class OrderReadinessBadge extends StatelessWidget {
  final SupplierSummary supplier;

  const OrderReadinessBadge({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final reason = supplier.orderBlockedReason;
    final ready = reason == null;
    // A sent request is waiting on the supplier, not a problem to fix — it
    // reads in the calm info tone rather than danger red.
    final waiting = supplier.isRequestPending;

    final fg = ready ? t.primary : (waiting ? t.info : t.dangerText);
    final bg = ready ? t.primaryTint : (waiting ? t.infoTint : t.dangerTint);

    // A pill that can wrap: the blocked reasons are whole sentences.
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppTokens.mdRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: Icon(
              ready
                  ? Icons.check_circle_outline_rounded
                  : (waiting ? Icons.hourglass_top_rounded : Icons.lock_outline_rounded),
              size: 16,
              color: fg,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              ready ? 'supplier.order_ready'.tr() : 'supplier.blocked_$reason'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
