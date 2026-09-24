import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/shop/shop_product.dart';
import '../../../data/repositories/shop_repository.dart';
import '../view_models/shop_cubits.dart';

/// A state view never shows an empty message.
String _messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

/// The shop landing page.
class ShopHomeView extends StatelessWidget {
  const ShopHomeView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShopHomeCubit(getIt<ShopRepository>())..load(),
        child: const _ShopHomeBody(),
      );
}

class _ShopHomeBody extends StatelessWidget {
  const _ShopHomeBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShopHomeCubit>();
    final state = cubit.state;

    return Scaffold(
      appBar: AppBar(
        title: Text('shop.title'.tr()),
        actions: [
          AppCircleButton(
            size: 40,
            tooltip: 'shop.search'.tr(),
            icon: Icons.search_rounded,
            onPressed: () => context.push(AppRoutes.shopSearch),
          ),
          const SizedBox(width: AppTokens.space2),
          AppCircleButton(
            size: 40,
            tooltip: 'shop.favorites'.tr(),
            icon: Icons.favorite_border_rounded,
            onPressed: () => context.push(AppRoutes.shopFavorites),
          ),
          const SizedBox(width: AppTokens.space2),
          AppCircleButton(
            size: 40,
            tooltip: 'shop.cart'.tr(),
            icon: Icons.shopping_cart_outlined,
            count: state.home?.cartCount ?? 0,
            onPressed: () => context.push(AppRoutes.shopCart),
          ),
          const SizedBox(width: AppTokens.space4),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.loading && state.home == null) return const _ShopHomeSkeleton();
          if (state.home == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
          }

          final home = state.home!;
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsetsDirectional.only(
                top: AppTokens.space3,
                bottom: AppTokens.space8,
              ),
              children: [
                if (home.sliders.isNotEmpty) _BannerCarousel(sliders: home.sliders),

                if (home.categories.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space5),
                  _SectionHeader(
                    title: 'shop.categories'.tr(),
                    onMore: () => context.push(AppRoutes.shopCategories),
                  ),
                  _CategoryStrip(categories: home.categories),
                ],

                _ProductRail(
                  title: 'shop.best_selling'.tr(),
                  products: home.bestSelling,
                  feedType: ProductFeed.bestSelling,
                ),
                _ProductRail(
                  title: 'shop.most_viewed'.tr(),
                  products: home.mostViewed,
                  feedType: ProductFeed.mostViewed,
                ),
                _ProductRail(
                  title: 'shop.discounted'.tr(),
                  products: home.discounted,
                  feedType: ProductFeed.discount,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The home banners, one per page with dots underneath. They carry no
/// action here — the model's link is not opened by the app.
class _BannerCarousel extends StatefulWidget {
  final List<HomeSlider> sliders;

  const _BannerCarousel({required this.sliders});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.sliders.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.gutter),
          child: AspectRatio(
            aspectRatio: 2.2,
            child: ClipRRect(
              borderRadius: AppTokens.lgRadius,
              child: PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => ShopImage(url: widget.sliders[index].image),
              ),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: AppTokens.space3),
          PageDots(count: count, index: _page),
        ],
      ],
    );
  }
}

/// Page indicator dots: the current page is a teal pill, the rest quiet dots.
class PageDots extends StatelessWidget {
  final int count;
  final int index;

  const PageDots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsetsDirectional.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? t.primary : t.border,
                borderRadius: AppTokens.fullRadius,
              ),
            ),
        ],
      ),
    );
  }
}

/// A network image with the neutral placeholder for empty and broken URLs.
class ShopImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double iconSize;

  const ShopImage({super.key, required this.url, this.width, this.height, this.iconSize = 28});

  @override
  Widget build(BuildContext context) {
    final placeholder = _ImagePlaceholder(width: width, height: height, iconSize: iconSize);
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      width: width ?? double.infinity,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double iconSize;

  const _ImagePlaceholder({this.width, this.height, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: t.neutralTint,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: iconSize, color: t.iconMuted),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;

  const _SectionHeader({required this.title, this.onMore});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.gutter,
          0,
          AppTokens.space2,
          AppTokens.space1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (onMore != null)
              AppButton.text(label: 'shop.see_all'.tr(), onPressed: onMore, height: 40),
          ],
        ),
      );
}

/// The home category circles. A leaf category opens its products, exactly as
/// the categories screen does; a parent opens the categories browser.
class _CategoryStrip extends StatelessWidget {
  final List<NamedCategory> categories;

  const _CategoryStrip({required this.categories});

  static const _itemWidth = 80.0;
  static const _circle = 64.0;

  void _open(BuildContext context, NamedCategory category) {
    if (category.listsProducts) {
      context.push(AppRoutes.shopCategoryFor(category.id), extra: category.name);
    } else {
      context.push(AppRoutes.shopCategories);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final label = theme.textTheme.labelSmall?.copyWith(color: t.textSecondary);
    // Room for the circle plus two lines of the label at the current text
    // scale, so a large font never clips the names.
    final height = _circle +
        AppTokens.space2 +
        _lineHeight(context, label) * 2 +
        AppTokens.space3;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.gutter - 4),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppTokens.space1),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Semantics(
            button: true,
            child: InkWell(
              onTap: () => _open(context, category),
              borderRadius: AppTokens.mdRadius,
              child: SizedBox(
                width: _itemWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
                  child: Column(
                    children: [
                      Container(
                        width: _circle,
                        height: _circle,
                        decoration: BoxDecoration(color: t.primaryTint, shape: BoxShape.circle),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: category.image.isEmpty
                            ? Icon(Icons.category_outlined, color: t.primary, size: 28)
                            : CachedNetworkImage(
                                imageUrl: category.image,
                                width: _circle,
                                height: _circle,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    Icon(Icons.category_outlined, color: t.primary, size: 28),
                              ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        category.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: label,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One line of [style] at the device's text scale.
double _lineHeight(BuildContext context, TextStyle? style) {
  final size = style?.fontSize ?? 14;
  return MediaQuery.textScalerOf(context).scale(size) * (style?.height ?? 1.3);
}

class _ProductRail extends StatelessWidget {
  final String title;
  final List<ShopProduct> products;
  final String feedType;

  const _ProductRail({
    required this.title,
    required this.products,
    required this.feedType,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTokens.space5),
        _SectionHeader(
          title: title,
          onMore: () => context.push(AppRoutes.shopFeedFor(feedType)),
        ),
        ProductRail(products: products),
      ],
    );
  }
}

/// A horizontal row of product cards whose height follows the text scale.
class ProductRail extends StatelessWidget {
  final List<ShopProduct> products;

  const ProductRail({super.key, required this.products});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: ProductCard.heightFor(context, ProductCard.railWidth),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.gutter),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppTokens.space3),
          itemBuilder: (context, index) => SizedBox(
            width: ProductCard.railWidth,
            child: ProductCard(product: products[index]),
          ),
        ),
      );
}

/// A product tile. Tapping it opens the detail — **which is what increments
/// the view counter**, so nothing here prefetches it.
class ProductCard extends StatelessWidget {
  final ShopProduct product;
  final VoidCallback? onFavorite;

  const ProductCard({super.key, required this.product, this.onFavorite});

  static const railWidth = 164.0;
  static const _imageAspect = 1.2;

  static TextStyle? _nameStyle(ThemeData theme, AppTokens t) =>
      theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: t.textPrimary);

  static TextStyle _priceStyle(AppTokens t) => AppType.ledger(t.textPrimary);

  /// The card's height at [width]: the image, two lines of name and the
  /// price line, all at the current text scale.
  static double heightFor(BuildContext context, double width) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return width / _imageAspect +
        AppTokens.space3 * 2 +
        _lineHeight(context, _nameStyle(theme, t)) * 2 +
        AppTokens.space2 +
        _lineHeight(context, _priceStyle(t)) +
        // Card border and rounding slack.
        6;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final price = product.price;
    final discounted = price.onSale && price.salePrice > 0;

    return AppCard(
      radius: AppTokens.lgRadius,
      padding: EdgeInsetsDirectional.zero,
      onTap: () => context.push(AppRoutes.shopProductFor(product.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: _imageAspect,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 6, 0),
                  child: ClipRRect(
                    borderRadius: AppTokens.mdRadius,
                    child: ShopImage(url: product.image),
                  ),
                ),
              ),
              if (discounted || !price.inStock)
                PositionedDirectional(
                  top: AppTokens.space3,
                  start: AppTokens.space3,
                  end: onFavorite == null ? AppTokens.space3 : 48,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: !price.inStock
                        ? AppBadge('shop.out_of_stock'.tr(), tone: AppTone.neutral)
                        : AppBadge('shop.discounted'.tr(), tone: AppTone.danger),
                  ),
                ),
              if (onFavorite != null)
                PositionedDirectional(
                  top: AppTokens.space2,
                  end: AppTokens.space2,
                  child: Material(
                    color: t.surface.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'shop.favorite'.tr(),
                      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: Icon(
                        product.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: t.primary,
                      ),
                      onPressed: onFavorite,
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _nameStyle(theme, t),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: MoneyText(price.effective, style: _priceStyle(t)),
                        ),
                      ),
                      if (discounted) ...[
                        const SizedBox(width: AppTokens.space1 + 2),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: MoneyText(
                              price.price,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: t.textTertiary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: t.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid of product cards with pull-to-refresh and a load-more spinner.
class _ProductGrid extends StatelessWidget {
  final List<ShopProduct> items;
  final bool loadingMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onNearEnd;
  final void Function(ShopProduct product) onFavorite;

  const _ProductGrid({
    required this.items,
    required this.loadingMore,
    required this.onRefresh,
    required this.onNearEnd,
    required this.onFavorite,
  });

  static const _maxTileWidth = 210.0;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = AppTokens.space3;
            final available = constraints.maxWidth - AppTokens.gutter * 2;
            final columns = ((available + spacing) / (_maxTileWidth + spacing)).ceil().clamp(2, 6);
            final tileWidth = (available - spacing * (columns - 1)) / columns;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.gutter,
                    AppTokens.space3,
                    AppTokens.gutter,
                    AppTokens.space4,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      mainAxisExtent: ProductCard.heightFor(context, tileWidth),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= items.length - 3) onNearEnd();
                        final product = items[index];
                        return ProductCard(
                          product: product,
                          onFavorite: () => onFavorite(product),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: loadingMore
                      ? const Padding(
                          padding: EdgeInsetsDirectional.only(bottom: AppTokens.space8),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      : const SizedBox(height: AppTokens.space6),
                ),
              ],
            );
          },
        ),
      );
}

/// A grid of products: a feed, a category, or a search.
class ProductListView extends StatefulWidget {
  final String? feedType;
  final int? categoryId;
  final String title;
  final bool searchable;

  const ProductListView({
    super.key,
    required this.title,
    this.feedType,
    this.categoryId,
    this.searchable = false,
  });

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  final _search = TextEditingController();
  Timer? _timer;

  void _onChanged(BuildContext context, String value) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 400),
      () => context.read<ProductListCubit>().setSearch(value),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) {
          final cubit = ProductListCubit(
            getIt<ShopRepository>(),
            feedType: widget.feedType,
            categoryId: widget.categoryId,
          );
          // A search with no text asks for nothing, so it only loads once the
          // user types.
          if (!widget.searchable) cubit.load();
          return cubit;
        },
        child: Builder(
          builder: (context) {
            final cubit = context.watch<ProductListCubit>();

            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: Column(
                children: [
                  if (widget.searchable)
                    AppSearchField(
                      controller: _search,
                      autofocus: true,
                      hint: 'shop.search_hint'.tr(),
                      onChanged: (value) => _onChanged(context, value),
                      onSubmitted: cubit.setSearch,
                    ),
                  Expanded(
                    child: cubit.state.loading && widget.searchable && _search.text.isEmpty
                        ? AppEmptyState(
                            icon: Icons.search_rounded,
                            title: 'shop.search_prompt'.tr(),
                          )
                        : _Grid(cubit: cubit),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _Grid extends StatelessWidget {
  final ProductListCubit cubit;

  const _Grid({required this.cubit});

  @override
  Widget build(BuildContext context) {
    final state = cubit.state;

    if (state.loading) return const GridSkeleton();
    if (state.offline && state.items.isEmpty) {
      return AppOfflineState(onRetry: cubit.refresh);
    }
    if (state.failedOutright) {
      return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.refresh);
    }
    if (state.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'shop.no_products'.tr(),
      );
    }

    return _ProductGrid(
      items: state.items,
      loadingMore: state.loadingMore,
      onRefresh: cubit.refresh,
      onNearEnd: cubit.loadMore,
      onFavorite: cubit.toggleFavorite,
    );
  }
}

/// Categories, three levels deep. Only the deepest level lists products.
class ShopCategoriesView extends StatelessWidget {
  const ShopCategoriesView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CategoriesCubit(getIt<ShopRepository>())..load(),
        child: const _CategoriesBody(),
      );
}

class _CategoriesBody extends StatelessWidget {
  const _CategoriesBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CategoriesCubit>();
    final state = cubit.state;

    return PopScope(
      canPop: state.trail.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            state.trail.isEmpty ? 'shop.categories'.tr() : state.trail.last.name,
          ),
        ),
        body: Builder(
          builder: (context) {
            if (state.loading) return const ListSkeleton(rows: 6);
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            if (state.errorMessage != null) {
              return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
            }
            if (state.categories.isEmpty) {
              return AppEmptyState(
                icon: Icons.category_outlined,
                title: 'shop.no_categories'.tr(),
              );
            }

            return ListView(
              padding: AppTokens.pagePadding,
              children: [
                AppMenuGroup(
                  children: [
                    for (final category in state.categories)
                      _CategoryRow(
                        category: category,
                        onTap: () {
                          // Only a leaf category lists products; anything else
                          // drills down.
                          if (category.listsProducts) {
                            context.push(AppRoutes.shopCategoryFor(category.id),
                                extra: category.name);
                          } else {
                            cubit.drillInto(category);
                          }
                        },
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// An [AppMenuRow] whose disc can hold the category's own picture.
class _CategoryRow extends StatelessWidget {
  final NamedCategory category;
  final VoidCallback onTap;

  const _CategoryRow({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    const disc = 44.0;
    final fallback = Icon(Icons.category_outlined, size: 22, color: t.primary);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTokens.rowHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppTokens.space5,
            vertical: AppTokens.space3,
          ),
          child: Row(
            children: [
              Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(color: t.primaryTint, shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: category.image.isEmpty
                    ? fallback
                    : CachedNetworkImage(
                        imageUrl: category.image,
                        width: disc,
                        height: disc,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => fallback,
                      ),
              ),
              const SizedBox(width: AppTokens.space4),
              Expanded(child: Text(category.name, style: theme.textTheme.titleSmall)),
              const SizedBox(width: AppTokens.space2),
              DirectionalChevron(size: 20, color: t.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saved products.
class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FavoritesCubit(getIt<ShopRepository>())..load(),
        child: Builder(
          builder: (context) {
            final cubit = context.watch<FavoritesCubit>();
            final state = cubit.state;

            return Scaffold(
              appBar: AppBar(title: Text('shop.favorites'.tr())),
              body: Builder(
                builder: (context) {
                  if (state.loading) return const GridSkeleton();
                  if (state.offline && state.items.isEmpty) {
                    return AppOfflineState(onRetry: cubit.refresh);
                  }
                  if (state.failedOutright) {
                    return AppErrorState(
                      message: _messageOr(state.errorMessage),
                      onRetry: cubit.refresh,
                    );
                  }
                  if (state.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'shop.no_favorites'.tr(),
                      body: 'shop.no_favorites_hint'.tr(),
                      actionLabel: 'shop.browse'.tr(),
                      onAction: () => context.go(AppRoutes.shop),
                    );
                  }

                  return _ProductGrid(
                    items: state.items,
                    loadingMore: state.loadingMore,
                    onRefresh: cubit.refresh,
                    onNearEnd: cubit.loadMore,
                    onFavorite: cubit.remove,
                  );
                },
              ),
            );
          },
        ),
      );
}

class _ShopHomeSkeleton extends StatelessWidget {
  const _ShopHomeSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: ListView(
          padding: AppTokens.pagePadding,
          children: const [
            Skeleton.box(height: 150),
            SizedBox(height: AppTokens.space6),
            Row(
              children: [
                SkeletonCircle(size: 64),
                SizedBox(width: AppTokens.space4),
                SkeletonCircle(size: 64),
                SizedBox(width: AppTokens.space4),
                SkeletonCircle(size: 64),
              ],
            ),
            SizedBox(height: AppTokens.space6),
            Skeleton.line(widthFactor: 0.3, height: 13),
            SizedBox(height: AppTokens.space3),
            Row(
              children: [
                Expanded(child: Skeleton.box(height: 200)),
                SizedBox(width: AppTokens.space3),
                Expanded(child: Skeleton.box(height: 200)),
              ],
            ),
          ],
        ),
      );
}
