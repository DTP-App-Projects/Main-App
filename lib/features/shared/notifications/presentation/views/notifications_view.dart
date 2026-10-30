import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/deeplink/deep_link.dart';
import '../../../../../core/deeplink/deep_link_router.dart';
import '../../../../../core/i18n/app_dates.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/models/notifications/app_notification.dart';
import '../view_models/notifications_cubit.dart';

/// The bell list. Rendered inline as a shell tab, and as its own route when a
/// deep link has nowhere more specific to go.
class NotificationsView extends StatefulWidget {
  final bool showAppBar;

  const NotificationsView({super.key, this.showAppBar = false});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // The cubit is session-scoped for the badge, so the list may already
    // hold rows from earlier — re-read them behind the old ones, or a list
    // of one or two never showed what arrived since.
    context.read<NotificationsCubit>().refresh(quiet: true);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final remaining = _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining < 400) context.read<NotificationsCubit>().loadMore();
  }

  Future<void> _open(AppNotification notification) async {
    final cubit = context.read<NotificationsCubit>();
    await cubit.markRead(notification);
    if (!mounted) return;

    await getIt<DeepLinkRouter>().open(
      DeepLink(
        clickAction: notification.clickAction,
        entityType: notification.entityType,
        entityId: notification.entityId,
        eventCode: notification.eventCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NotificationsCubit>();
    final state = cubit.state;
    final locale = context.locale.toString();

    final body = Builder(
      builder: (context) {
        if (state.loading) return const ListSkeleton(rows: 6);
        if (state.offline && state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: AppOfflineState(onRetry: cubit.refresh),
          );
        }
        if (state.errorMessage != null && state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: AppErrorState(message: state.errorMessage!, onRetry: cubit.refresh),
          );
        }
        if (state.isEmpty) {
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'notifications.empty'.tr(),
              body: state.unreadOnly ? 'notifications.empty_unread'.tr() : null,
              actionLabel: state.unreadOnly ? 'notifications.show_all'.tr() : null,
              onAction: state.unreadOnly ? cubit.toggleUnreadOnly : null,
            ),
          );
        }

        final rows = _grouped(state.items);
        return RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              0,
              AppTokens.gutter,
              AppTokens.space8,
            ),
            itemCount: rows.length + (state.loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppTokens.space4),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }
              final row = rows[index];
              if (row is String) {
                return AppSectionLabel(
                  row,
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppTokens.space1,
                    index == 0 ? AppTokens.space2 : AppTokens.space5,
                    AppTokens.space1,
                    AppTokens.space3,
                  ),
                );
              }
              final notification = row as AppNotification;
              return _NotificationTile(
                notification: notification,
                locale: locale,
                onTap: () => _open(notification),
              );
            },
          ),
        );
      },
    );

    final t = context.tokens;
    final actions = [
      AppCircleButton(
        size: 40,
        tooltip: state.unreadOnly
            ? 'notifications.show_all'.tr()
            : 'notifications.show_unread'.tr(),
        icon: state.unreadOnly ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
        onPressed: cubit.toggleUnreadOnly,
      ),
      AppCircleButton(
        size: 40,
        tooltip: 'notifications.mark_all_read'.tr(),
        icon: Icons.done_all_rounded,
        onPressed: state.unreadCount == 0 ? null : cubit.markAllRead,
      ),
    ];

    // A refresh that fails while the list is showing keeps the list, but
    // says so instead of failing silently.
    final listened = BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.errorMessage != previous.errorMessage &&
          current.items.isNotEmpty,
      listener: (context, current) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(current.errorMessage!))),
      child: body,
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text('nav.notifications'.tr()),
          actions: [
            for (final action in actions) ...[action, const SizedBox(width: AppTokens.space2)],
            const SizedBox(width: AppTokens.space2),
          ],
        ),
        body: listened,
      );
    }

    // A shell tab: one header on the page (Driver tab pages have no bar).
    return ColoredBox(
      color: t.background,
      child: Column(
        children: [
          AppHeader(
            title: 'nav.notifications'.tr(),
            subtitle: state.unreadCount > 0
                ? 'notifications.unread_count'.tr(args: ['${state.unreadCount}'])
                : null,
            actions: actions,
          ),
          Expanded(child: listened),
        ],
      ),
    );
  }

  /// Interleaves "Today" / "Earlier" labels into the loaded list — a pure
  /// presentation grouping; order and paging are the cubit's.
  List<Object> _grouped(List<AppNotification> items) {
    final now = DateTime.now();
    bool isToday(DateTime? at) =>
        at != null && at.year == now.year && at.month == now.month && at.day == now.day;

    final rows = <Object>[];
    String? current;
    for (final item in items) {
      final label = isToday(item.createdAt)
          ? 'notifications.today'.tr()
          : 'notifications.earlier'.tr();
      if (label != current) {
        rows.add(label);
        current = label;
      }
      rows.add(item);
    }
    return rows;
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String locale;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.locale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final detail = notification.detail(locale);
    final unread = !notification.isRead;

    return AppCard.item(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconCircle(
            _iconFor(notification.clickAction),
            size: 40,
            tone: unread ? AppTone.brand : AppTone.neutral,
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.headline(locale),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (notification.createdAt != null) ...[
                  const SizedBox(height: AppTokens.space1),
                  Text(
                    AppDates.dateTime(notification.createdAt, locale),
                    style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (unread)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppTokens.space2, top: 6),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(String clickAction) => switch (clickAction) {
    'purchase_order' => Icons.receipt_long_outlined,
    'delivery_note' => Icons.local_shipping_outlined,
    'goods_receipt' => Icons.inventory_2_outlined,
    'invoice' => Icons.request_quote_outlined,
    'post_invoice_return' => Icons.assignment_return_outlined,
    'supplier_fleet_contract' => Icons.handshake_outlined,
    'chat' => Icons.chat_bubble_outline_rounded,
    _ => Icons.notifications_none_rounded,
  };
}
