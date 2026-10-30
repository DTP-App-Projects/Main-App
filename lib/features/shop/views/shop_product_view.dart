import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/form_status.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/repositories/shop_repository.dart';
import '../view_models/shop_cubits.dart';
import 'shop_browse_views.dart';

/// One product.
///
/// Opening this screen is what **increments the product's view counter**, so
/// it is only ever reached by a deliberate tap.
class ShopProductView extends StatelessWidget {
  final int productId;

  const ShopProductView({super.key, required this.productId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ProductDetailCubit(getIt<ShopRepository>(), productId)..load(),
        child: const _ProductBody(),
      );
}

class _ProductBody extends StatelessWidget {
  const _ProductBody();

  Future<void> _addToCart(BuildContext context) async {
    final added = await context.read<ProductDetailCubit>().addToCart();
    if (!context.mounted || !added) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('shop.added_to_cart'.tr()),
        action: SnackBarAction(
          label: 'shop.cart'.tr(),
          onPressed: () => context.push(AppRoutes.shopCart),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductDetailCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;

    if (state.loading) {
      return Scaffold(appBar: AppBar(), body: const DetailSkeleton());
    }
    if (state.detail == null) {
      final message = state.errorMessage;
      return Scaffold(
        appBar: AppBar(),
        body: state.offline
            ? AppOfflineState(onRetry: cubit.load)
            : AppErrorState(
                message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
                onRetry: cubit.load,
              ),
      );
    }

    final detail = state.detail!;
    final product = detail.product;
    final price = product.price;
    // A variable product carries its stock on the variation, not the product.
    final variation = state.variation;
    final available = product.isVariable ? (variation?.count ?? 0) : price.count;
    final needsVariation = product.isVariable && variation == null;
    final canAdd = available > 0 && !needsVariation;
    final gallery = [
      if (product.image.isNotEmpty) product.image,
      ...product.images.where((url) => url != product.image),
    ];
    final discounted = price.onSale && price.salePrice > 0;

    // Why the button is off, said next to it rather than left to guesswork.
    final String? blockedReason = canAdd
        ? null
        : needsVariation
            ? 'shop.choose_variation'.tr()
            : 'shop.out_of_stock'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text('shop.product'.tr()),
        actions: [
          AppCircleButton(
            size: 40,
            tooltip: 'shop.favorite'.tr(),
            icon: product.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            onPressed: cubit.toggleFavorite,
          ),
          const SizedBox(width: AppTokens.space4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(
          top: AppTokens.space2,
          bottom: AppTokens.space8,
        ),
        children: [
          if (gallery.isNotEmpty) _Gallery(images: gallery),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              AppTokens.space5,
              AppTokens.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppTokens.space2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  children: [
                    MoneyText(price.effective, style: AppType.stat(t.textPrimary)),
                    if (discounted)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 2),
                        child: MoneyText(
                          price.price,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: t.textTertiary,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: t.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (price.onSale && price.saleTill != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
                    child: Wrap(
                      spacing: AppTokens.space1,
                      children: [
                        Text('shop.sale_until'.tr(), style: theme.textTheme.bodySmall),
                        DateText(price.saleTill, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                const SizedBox(height: AppTokens.space3),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space2,
                  children: [
                    if (product.rate > 0)
                      AppBadge(
                        product.rate.toStringAsFixed(1),
                        tone: AppTone.warning,
                        icon: Icons.star_rounded,
                      ),
                    AppBadge(
                      available > 0
                          ? 'shop.in_stock'.tr(args: ['$available'])
                          : 'shop.out_of_stock'.tr(),
                      tone: available > 0 ? AppTone.brand : AppTone.danger,
                      icon: available > 0
                          ? Icons.inventory_2_outlined
                          : Icons.remove_shopping_cart_outlined,
                    ),
                    if (product.isNegotiated)
                      AppBadge(
                        'shop.negotiable'.tr(),
                        tone: AppTone.info,
                        icon: Icons.handshake_outlined,
                      ),
                  ],
                ),
                if (product.variations.isNotEmpty) ...[
                  AppSectionLabel('shop.variation'.tr()),
                  Wrap(
                    spacing: AppTokens.space2,
                    runSpacing: AppTokens.space2,
                    children: [
                      for (final option in product.variations)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: variation?.id == option.id,
                          onSelected: (_) => cubit.setVariation(option),
                        ),
                    ],
                  ),
                ],
                if (product.description.isNotEmpty || product.custom.isNotEmpty) ...[
                  AppSectionLabel('shop.description'.tr()),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.description.isNotEmpty)
                          _ExpandableText(text: product.description),
                        if (product.description.isNotEmpty && product.custom.isNotEmpty)
                          const SizedBox(height: AppTokens.space3),
                        if (product.custom.isNotEmpty)
                          Text(product.custom, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
                if (detail.seller case final seller?) ...[
                  const SizedBox(height: AppTokens.space5),
                  AppCard.item(
                    margin: EdgeInsetsDirectional.zero,
                    child: Row(
                      children: [
                        _Avatar(name: seller.displayName, image: seller.image),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seller.displayName,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (seller.companyName.isNotEmpty)
                                Text(
                                  seller.companyName,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        AppCircleButton(
                          size: 40,
                          tooltip: 'shop.chat'.tr(),
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () => context.push(
                            AppRoutes.shopChatWith(seller.id),
                            extra: seller.displayName,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (detail.similars.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.gutter,
                AppTokens.sectionGap,
                AppTokens.gutter,
                AppTokens.space3,
              ),
              child: Text('shop.similar'.tr(), style: theme.textTheme.titleSmall),
            ),
            ProductRail(products: detail.similars),
          ],
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        leading: (state.action.status == FormStatus.failure &&
                    (state.action.message ?? '').isNotEmpty) ||
                blockedReason != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.action.status == FormStatus.failure &&
                      (state.action.message ?? '').isNotEmpty)
                    AppBanner(
                      message: state.action.message!,
                      tone: AppTone.danger,
                      margin: blockedReason == null
                          ? EdgeInsetsDirectional.zero
                          : const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
                    ),
                  if (blockedReason != null)
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: t.iconMuted),
                        const SizedBox(width: AppTokens.space1 + 2),
                        Expanded(
                          child: Text(blockedReason, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                ],
              )
            : null,
        child: Row(
          children: [
            _QuantityStepper(
              value: state.quantity,
              max: available,
              onChanged: cubit.setQuantity,
            ),
            const SizedBox(width: AppTokens.space3),
            Expanded(
              child: consumerCheckoutOpen()
                  ? SubmitButton(
                      busy: state.action.isSubmitting,
                      label: 'shop.add_to_cart'.tr(),
                      onPressed: canAdd ? () => _addToCart(context) : null,
                    )
                  : Text('shop.checkout_closed'.tr(), style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// The product photos, one per page, with dots.
class _Gallery extends StatefulWidget {
  final List<String> images;

  const _Gallery({required this.images});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.gutter),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: ClipRRect(
              borderRadius: AppTokens.xlRadius,
              child: PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) =>
                    ShopImage(url: widget.images[index], iconSize: 40),
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

/// A long description, clamped to a few lines until the reader asks for more.
class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.tokens.textSecondary,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: AlignmentDirectional.topStart,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              AppButton.text(
                label: _expanded ? 'shop.show_less'.tr() : 'shop.show_more'.tr(),
                height: 40,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
          ],
        );
      },
    );
  }
}

/// A picture when there is one, the initial otherwise.
class _Avatar extends StatelessWidget {
  final String name;
  final String image;

  const _Avatar({required this.name, required this.image});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    if (image.isEmpty) return AppInitialAvatar(name: name, size: size);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => AppInitialAvatar(name: name, size: size),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: t.inputFill,
        border: Border.all(color: t.inputBorder),
        borderRadius: AppTokens.lgRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 20,
            color: t.textPrimary,
            icon: const Icon(Icons.remove_rounded),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                style: AppType.ledger(t.textPrimary),
              ),
            ),
          ),
          IconButton(
            iconSize: 20,
            color: t.textPrimary,
            icon: const Icon(Icons.add_rounded),
            // Stock is the server's rule too — over it is
            // `insufficient_product_count`, so the stepper stops first.
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
