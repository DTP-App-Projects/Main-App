import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/session_cubit.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/shop/cart.dart';
import '../../../data/repositories/shop_repository.dart';
import '../view_models/shop_cubits.dart';
import 'shop_browse_views.dart';

/// A state view never shows an empty message.
String _messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

/// The cart, with checkout on the same screen.
///
/// **Buyers only** — a seller account gets `400 validation_error` from the
/// cart endpoint, which the error text explains rather than the empty state.
class ShopCartView extends StatelessWidget {
  const ShopCartView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CartCubit(getIt<ShopRepository>())..load(),
        child: const _CartBody(),
      );
}

class _CartBody extends StatelessWidget {
  const _CartBody();

  /// Checkout is a one-shot: whatever comes back, the buyer is sent to the
  /// orders list, because orders may exist even on the failure path.
  Future<void> _checkout(BuildContext context) async {
    final cubit = context.read<CartCubit>();
    final succeeded = await cubit.checkout();
    if (!context.mounted) return;

    if (!succeeded) {
      final message = cubit.state.action.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'shop.checkout_partial'.tr())),
      );
    }
    // Success or not, the orders list is the only truthful record.
    context.go(AppRoutes.shopOrders);
  }

  Future<void> _remove(BuildContext context, CartLine line) async {
    final cubit = context.read<CartCubit>();
    final confirmed = await showAppConfirm(
      context,
      title: 'shop.remove_confirm'.tr(),
      body: line.name,
      confirmLabel: 'shop.remove'.tr(),
      destructive: true,
    );
    if (confirmed) await cubit.removeLine(line.id);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CartCubit>();
    final state = cubit.state;
    final cart = state.cart;
    final theme = Theme.of(context);
    final t = context.tokens;
    final showCart = !state.loading && !state.offline && !cart.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('shop.cart'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading) return const ListSkeleton(rows: 4);
          if (state.offline) return AppOfflineState(onRetry: cubit.load);
          if (state.errorMessage != null && cart.isEmpty) {
            return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
          }
          if (cart.isEmpty) {
            return AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'shop.cart_empty'.tr(),
              actionLabel: 'shop.browse'.tr(),
              onAction: () => context.go(AppRoutes.shop),
            );
          }

          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              for (final line in cart.lines)
                _CartLineCard(line: line, onRemove: () => _remove(context, line)),
              const SizedBox(height: AppTokens.space2),
              // Checkout splits the cart by seller and creates one order per
              // seller. The payload does not say how many that is, so the
              // notice does not pretend to know.
              AppBanner(message: 'shop.checkout_split_notice'.tr(), tone: AppTone.info),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'shop.subtotal'.tr(), value: MoneyText(cart.totals.net)),
                    DetailRow(label: 'shop.tax'.tr(), value: MoneyText(cart.totals.tax)),
                    Divider(height: AppTokens.space4, color: t.divider),
                    DetailRow(
                      label: 'shop.total'.tr(),
                      emphasis: true,
                      value: MoneyText(
                        cart.totals.total,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              AppSectionLabel('shop.delivery_address'.tr()),
              if (cart.addresses.isEmpty)
                AppBanner(
                  title: 'shop.no_address_title'.tr(),
                  message: 'shop.no_address'.tr(),
                  tone: AppTone.warning,
                  icon: Icons.location_off_outlined,
                )
              else
                IdPicker<CartAddress>(
                  label: '',
                  value: state.addressId,
                  items: cart.addresses,
                  idOf: (address) => address.id,
                  labelOf: (address) => address.text,
                  onChanged: (id) {
                    if (id != null) cubit.setAddress(id);
                  },
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: showCart
          ? AppBottomBar(
              leading: Row(
                children: [
                  Expanded(child: Text('shop.total'.tr(), style: theme.textTheme.bodySmall)),
                  MoneyText(cart.totals.total, style: AppType.ledger(t.textPrimary)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // A refused checkout is answered right above the button.
                  if (state.action.status == FormStatus.failure)
                    FormMessage(message: state.action.message),
                  SubmitButton(
                    busy: state.action.isSubmitting,
                    label: 'shop.checkout'.tr(),
                    // No address, no checkout — and never a second tap while
                    // the first is in flight.
                    onPressed: state.addressId == null ? null : () => _checkout(context),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _CartLineCard extends StatelessWidget {
  final CartLine line;
  final VoidCallback onRemove;

  const _CartLineCard({required this.line, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return AppCard.item(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.space3,
        AppTokens.space3,
        AppTokens.space1,
        AppTokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.mdRadius,
            child: ShopImage(url: line.product?.image ?? '', width: 64, height: 64, iconSize: 22),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppTokens.space1),
                Text('shop.qty'.tr(args: ['${line.count}']), style: theme.textTheme.bodySmall),
                const SizedBox(height: AppTokens.space1),
                // `price` on a cart row is the row's total, as the server
                // computed it (count × unit), not the unit price.
                Wrap(
                  spacing: AppTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('shop.line_total'.tr(), style: theme.textTheme.bodySmall),
                    MoneyText(line.price, style: AppType.ledger(t.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'shop.remove'.tr(),
            color: t.iconMuted,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

/// Marketplace orders.
///
/// The endpoint works out which side the caller is on from their account
/// type, so this one screen serves buyer and seller; `merchant` on each row
/// is always **the other party**.
class ShopOrdersView extends StatelessWidget {
  const ShopOrdersView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShopOrdersCubit(getIt<ShopRepository>())..load(),
        child: const _OrdersBody(),
      );
}

class _OrdersBody extends StatelessWidget {
  const _OrdersBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShopOrdersCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('shop.orders'.tr())),
      body: Column(
        children: [
          // Fixed above the list, so the filter never scrolls away.
          AppFilterBar(
            options: [
              for (final status in ShopOrder.filters)
                AppFilterOption(
                  label: 'shop.order_status.$status'.tr(),
                  selected: cubit.status == status,
                  onTap: () => cubit.setStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<ShopOrder>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.receipt_long_outlined,
              emptyTitle: 'shop.no_orders'.tr(),
              emptyActionLabel: 'shop.browse'.tr(),
              onEmptyAction: () => context.go(AppRoutes.shop),
              itemBuilder: (order) => _OrderTile(
                order: order,
                onTap: () => context.push(AppRoutes.shopOrderFor(order.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A marketplace order as a Driver item card, the same shape as
/// [DocumentTile] but with the server's own status label.
class _OrderTile extends StatelessWidget {
  final ShopOrder order;
  final VoidCallback onTap;

  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final merchant = order.merchant?.displayName ?? '';

    return Semantics(
      button: true,
      child: AppCard.item(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'shop.order_code'.tr(args: [order.code]),
                          style: AppType.code(t.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      StatusChip(status: order.status, label: order.statusLabel),
                    ],
                  ),
                  if (merchant.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space1),
                    Text(
                      merchant,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppTokens.space1),
                  Row(
                    children: [
                      Expanded(
                        child: DateText(
                          order.placedAt,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      MoneyText(order.totalFee, style: AppType.ledger(t.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            DirectionalChevron(size: 20, color: t.iconMuted),
          ],
        ),
      ),
    );
  }
}

/// One order: what is in it, who the other party is, and the two actions —
/// a buyer uploads a payment receipt, a seller moves the status on.
class ShopOrderDetailView extends StatelessWidget {
  final int orderId;

  const ShopOrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShopOrderDetailCubit(getIt<ShopRepository>(), orderId)..load(),
        child: const _OrderDetailBody(),
      );
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody();

  /// v1 takes the file itself on a direct multipart post — there is no
  /// `/v2/uploads` step here.
  Future<void> _uploadReceipt(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;

    final cubit = context.read<ShopOrderDetailCubit>();
    final ok = await cubit.uploadReceipt(picked.path);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'shop.receipt_uploaded'.tr() : _messageOr(cubit.state.action.message),
        ),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, String status) async {
    final cubit = context.read<ShopOrderDetailCubit>();
    // Declining ends the order, so it is confirmed first.
    if (status == 'declined') {
      final confirmed = await showAppConfirm(
        context,
        title: 'shop.decline_confirm'.tr(),
        confirmLabel: 'shop.order_status.declined'.tr(),
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }
    final ok = await cubit.setStatus(status);
    if (!context.mounted || ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageOr(cubit.state.action.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShopOrderDetailCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;

    // The v1 order endpoints pick the caller's side from the legacy
    // `users.type` (`buyer` / `seller`), which bootstrap still carries. The
    // status transitions are the seller's; the receipt is the buyer's.
    final legacyType = context.select<SessionCubit, String>(
      (c) => c.state.bootstrap?.user.legacyType ?? '',
    );
    final isSeller = legacyType == 'seller';
    final isBuyer = legacyType == 'buyer';
    final roleKnown = isSeller || isBuyer;

    if (state.loading) {
      return Scaffold(appBar: AppBar(), body: const DetailSkeleton());
    }
    if (state.order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: state.offline
            ? AppOfflineState(onRetry: cubit.load)
            : AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load),
      );
    }

    final order = state.order!;
    final busy = state.action.isSubmitting;
    final showSellerActions = !roleKnown || isSeller;
    final showReceipt = !roleKnown || isBuyer;
    final transitions = [
      for (final next in ShopOrder.sellerTransitions)
        if (next != order.status) next,
    ];

    final sellerActions = Wrap(
      spacing: AppTokens.space2,
      runSpacing: AppTokens.space2,
      children: [
        for (final next in transitions)
          next == 'declined'
              ? AppButton.outlineDanger(
                  label: 'shop.order_status.$next'.tr(),
                  expand: false,
                  height: 48,
                  onPressed: busy ? null : () => _setStatus(context, next),
                )
              : AppButton.outline(
                  label: 'shop.order_status.$next'.tr(),
                  expand: false,
                  height: 48,
                  onPressed: busy ? null : () => _setStatus(context, next),
                ),
      ],
    );
    final receiptButton = SubmitButton(
      busy: busy,
      icon: Icons.receipt_long_outlined,
      label: 'shop.upload_receipt'.tr(),
      onPressed: busy ? null : () => _uploadReceipt(context),
    );
    final sellerLabel = Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
      child: Text('shop.as_seller'.tr(), style: theme.textTheme.labelSmall),
    );
    final buyerLabel = Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
      child: Text('shop.as_buyer'.tr(), style: theme.textTheme.labelSmall),
    );

    // A refused action is answered right above the buttons, in the bar.
    final failed = state.action.status == FormStatus.failure;
    Widget answered(Widget actions) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failed) FormMessage(message: state.action.message),
            actions,
          ],
        );

    Widget? bottomBar;
    if (showReceipt && showSellerActions) {
      // The side could not be read — both are offered, each labelled, and
      // the API refuses the one that is not the caller's.
      bottomBar = AppBottomBar(
        leading: transitions.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (failed) FormMessage(message: state.action.message),
                  sellerLabel,
                  sellerActions,
                  const SizedBox(height: AppTokens.space2),
                  buyerLabel,
                ],
              ),
        child: transitions.isEmpty ? answered(receiptButton) : receiptButton,
      );
    } else if (showReceipt) {
      bottomBar = AppBottomBar(child: answered(receiptButton));
    } else if (showSellerActions && transitions.isNotEmpty) {
      bottomBar = AppBottomBar(child: answered(sellerActions));
    }

    return Scaffold(
      appBar: AppBar(title: Text('shop.order_code'.tr(args: [order.code]))),
      bottomNavigationBar: bottomBar,
      body: RefreshIndicator(
        onRefresh: cubit.load,
        child: ListView(
          padding: AppTokens.pagePadding,
          children: [
            // No action bar to answer from: the message stays on top.
            if (bottomBar == null && failed) FormMessage(message: state.action.message),
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
                            Text(
                              'shop.order_code'.tr(args: [order.code]),
                              style: AppType.code(t.textPrimary),
                            ),
                            if (order.placedAt != null) ...[
                              const SizedBox(height: 2),
                              DateText(
                                order.placedAt,
                                withTime: true,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      StatusChip(status: order.status, label: order.statusLabel),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text('shop.total'.tr(), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  MoneyText(order.totalFee, style: AppType.ledgerLarge(t.textPrimary)),
                  const SizedBox(height: AppTokens.space3),
                  DetailRow(label: 'shop.items'.tr(), value: Text('${order.itemsCount}')),
                  DetailRow(label: 'shop.subtotal'.tr(), value: MoneyText(order.itemsFee)),
                  DetailRow(label: 'shop.tax'.tr(), value: MoneyText(order.taxFee)),
                  if (order.address.isNotEmpty)
                    DetailRow(
                      label: 'shop.delivery_address'.tr(),
                      value: Text(order.address),
                    ),
                ],
              ),
            ),
            if (order.merchant case final merchant?) ...[
              // The endpoint names the *other* party, whichever side the
              // caller is on.
              AppSectionLabel(
                isBuyer
                    ? 'shop.seller'.tr()
                    : isSeller
                        ? 'shop.buyer'.tr()
                        : 'shop.other_party'.tr(),
              ),
              AppCard.item(
                margin: EdgeInsetsDirectional.zero,
                child: Row(
                  children: [
                    _Avatar(name: merchant.displayName, image: merchant.image),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(merchant.displayName, style: theme.textTheme.titleSmall),
                          if (merchant.bankInfo.isNotEmpty)
                            Text(merchant.bankInfo, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    AppCircleButton(
                      size: 40,
                      tooltip: 'shop.chat'.tr(),
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () => context.push(
                        AppRoutes.shopChatWith(merchant.id),
                        extra: merchant.displayName,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (order.items.isNotEmpty) ...[
              AppSectionLabel('shop.items'.tr()),
              // The backend drops per-line quantity from this payload, so the
              // rows list products only — the count above is the total.
              AppCard.section(
                child: Column(
                  children: [
                    for (var i = 0; i < order.items.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppTokens.space4 + 48 + AppTokens.space3,
                          ),
                          child: Divider(height: 1, color: t.divider),
                        ),
                      InkWell(
                        onTap: () => context.push(AppRoutes.shopProductFor(order.items[i].id)),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppTokens.space4,
                            vertical: AppTokens.space3,
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: AppTokens.mdRadius,
                                child: ShopImage(
                                  url: order.items[i].image,
                                  width: 48,
                                  height: 48,
                                  iconSize: 20,
                                ),
                              ),
                              const SizedBox(width: AppTokens.space3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.items[i].name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    MoneyText(
                                      order.items[i].price.effective,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppTokens.space2),
                              DirectionalChevron(size: 20, color: t.iconMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
