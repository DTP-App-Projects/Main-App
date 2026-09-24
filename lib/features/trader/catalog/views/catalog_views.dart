import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/catalog.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../view_models/catalog_cubits.dart';

/// Browse the catalogue across every supplier the trader can see.
class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ProductsCubit(getIt<CatalogRepository>())..load(),
        child: const _ProductsBody(),
      );
}

class _ProductsBody extends StatefulWidget {
  const _ProductsBody();

  @override
  State<_ProductsBody> createState() => _ProductsBodyState();
}

class _ProductsBodyState extends State<_ProductsBody> {
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
    _timer = Timer(
      const Duration(milliseconds: 400),
      () => context.read<ProductsCubit>().setSearch(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductsCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('catalog.title'.tr())),
      body: Column(
        children: [
          AppSearchField(
            controller: _search,
            onChanged: _onChanged,
            onSubmitted: context.read<ProductsCubit>().setSearch,
            hint: 'catalog.search_hint'.tr(),
          ),
          Expanded(
            child: PagedListView<Product>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.inventory_2_outlined,
              emptyTitle: 'catalog.empty'.tr(),
              emptyBody: _search.text.isEmpty ? null : 'lookup.empty_search'.tr(),
              itemBuilder: (product) => _ProductCard(product: product),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    return AppCard.item(
      onTap: () => context.push(AppRoutes.productDetailFor(product.id)),
      child: Row(
        children: [
          const AppIconCircle(Icons.inventory_2_outlined, size: 40),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.displayName(locale),
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTokens.space1),
                Row(
                  children: [
                    if (product.supplier != null) ...[
                      Icon(Icons.storefront_outlined, size: 16, color: t.iconMuted),
                      const SizedBox(width: AppTokens.space1),
                      Flexible(
                        child: Text(
                          product.supplier!.name,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                    ],
                    Text(
                      'catalog.sku_count'.tr(namedArgs: {'count': '${product.skusCount}'}),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          DirectionalChevron(size: 20, color: t.iconMuted),
        ],
      ),
    );
  }
}

/// One product and its SKUs. **Read-only for the trader** — the rules shown
/// here (minimum quantity, order step, pack size) are the supplier's, and are
/// exactly what will reject an order line if ignored.
class ProductDetailView extends StatelessWidget {
  final int productId;

  const ProductDetailView({super.key, required this.productId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ProductDetailCubit(getIt<CatalogRepository>(), productId)..load(),
        child: const _ProductDetailBody(),
      );
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductDetailCubit>();
    final state = cubit.state;
    final product = state.product;
    final locale = context.locale.toString();
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      // The product's name leads the header card below.
      appBar: AppBar(title: Text('catalog.title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading && product == null) return const DetailSkeleton();
          if (product == null) {
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
                AppCard(
                  shadow: true,
                  child: Row(
                    children: [
                      const AppIconCircle(Icons.inventory_2_outlined, size: 56),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.displayName(locale), style: theme.textTheme.titleLarge),
                            if (product.supplier != null) ...[
                              const SizedBox(height: AppTokens.space1),
                              Row(
                                children: [
                                  Icon(Icons.storefront_outlined, size: 16, color: t.iconMuted),
                                  const SizedBox(width: AppTokens.space1),
                                  Expanded(
                                    child: Text(
                                      product.supplier!.name,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppSectionLabel(
                  'catalog.skus'.tr(),
                  trailing: product.skus.isEmpty ? null : AppCountBadge(product.skus.length),
                ),
                AppBanner(
                  message: 'catalog.rules_hint'.tr(),
                  tone: AppTone.info,
                  margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                ),
                if (product.skus.isEmpty)
                  AppCard(
                    child: Text(
                      'catalog.no_skus'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  for (final sku in product.skus)
                    SkuCard(
                      sku: sku,
                      price: state.prices[sku.id],
                      resolving: state.resolving.contains(sku.id),
                      onResolve: () => cubit.resolvePrice(sku),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A SKU with its ordering rules and, on demand, the price that applies to
/// this trader.
class SkuCard extends StatelessWidget {
  final Sku sku;
  final PriceResolution? price;
  final bool resolving;
  final VoidCallback onResolve;

  const SkuCard({
    super.key,
    required this.sku,
    required this.price,
    required this.resolving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final unit = sku.unitLabel(locale);

    return AppCard.item(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(sku.displayName(locale), style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: sku.status),
            ],
          ),
          if (sku.skuCode.isNotEmpty || sku.barcode.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space1),
            Wrap(
              spacing: AppTokens.space3,
              runSpacing: AppTokens.space1,
              children: [
                if (sku.skuCode.isNotEmpty)
                  _CodeMeta(icon: Icons.tag_rounded, value: sku.skuCode),
                if (sku.barcode.isNotEmpty)
                  _CodeMeta(icon: Icons.qr_code_2_rounded, value: sku.barcode),
              ],
            ),
          ],
          const SizedBox(height: AppTokens.space3),

          // These are what the server checks on every add; showing them here
          // is how a rejection stops being a surprise.
          _RuleGrid(
            cells: [
              (label: 'catalog.min_order_qty'.tr(), value: _qty(sku.minOrderQty, unit)),
              (label: 'catalog.order_step'.tr(), value: _qty(sku.orderStepQty, unit)),
              (label: 'catalog.pack_quantity'.tr(), value: _qty(sku.packQuantity, unit)),
              if (sku.trackInventory)
                (label: 'catalog.available'.tr(), value: _qty(sku.availableQty, unit)),
            ],
          ),

          const SizedBox(height: AppTokens.space3),
          if (price == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _TintedPillButton(
                label: 'catalog.show_price'.tr(),
                icon: Icons.sell_outlined,
                busy: resolving,
                onPressed: resolving ? null : onResolve,
              ),
            )
          else
            Container(
              padding: const EdgeInsetsDirectional.all(AppTokens.space3),
              decoration: BoxDecoration(color: t.primaryTint, borderRadius: AppTokens.mdRadius),
              child: PriceSummary(price: price!),
            ),
        ],
      ),
    );
  }

  static String _qty(double value, String unit) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3);
    return unit.isEmpty ? text : '$text $unit';
  }
}

/// A code or barcode: Latin, so it reads left-to-right in Arabic too.
class _CodeMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CodeMeta({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: t.iconMuted),
        const SizedBox(width: AppTokens.space1),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Up to four label/value pairs in a two-column grid on a quiet well: no
/// rules, so the card never draws a double line.
class _RuleGrid extends StatelessWidget {
  final List<({String label, String value})> cells;

  const _RuleGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    const gap = AppTokens.space3;

    return Container(
      padding: const EdgeInsetsDirectional.all(AppTokens.space3),
      decoration: BoxDecoration(color: t.background, borderRadius: AppTokens.mdRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final cell in cells)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cell.label, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(cell.value, style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A teal-tinted pill button, sized to its label (Driver chip button).
class _TintedPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  const _TintedPillButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);

    return Material(
      color: t.primaryTint,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppTokens.space4,
              vertical: AppTokens.space2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
                  )
                else
                  Icon(icon, size: 18, color: t.primary),
                const SizedBox(width: AppTokens.space2),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The resolved price, or the reason there isn't one.
class PriceSummary extends StatelessWidget {
  final PriceResolution price;

  const PriceSummary({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    // No matching rule means the SKU cannot be ordered at all. Saying so here
    // is the whole point of resolving before the add.
    if (!price.canOrder) {
      return AppBanner(
        message: 'errors.pricing_not_found_for_sku'.tr(),
        tone: AppTone.danger,
        icon: Icons.block_rounded,
        margin: EdgeInsetsDirectional.zero,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppTokens.space3,
            runSpacing: AppTokens.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MoneyText(
                price.finalPrice,
                currency: price.currencyCode,
                style: AppType.ledger(t.primary),
              ),
              if (price.hasDiscount)
                MoneyText(
                  price.unitPrice,
                  currency: price.currencyCode,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.textTertiary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ),
        if (price.priceListName.isNotEmpty) ...[
          const SizedBox(width: AppTokens.space2),
          Flexible(child: AppBadge(price.priceListName, tone: AppTone.neutral)),
        ],
      ],
    );
  }
}
