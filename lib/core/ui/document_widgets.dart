import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/models/trade/purchase_order.dart';
import '../i18n/app_dates.dart';
import '../utils/theme/tokens.dart';
import '../utils/theme/typography.dart';
import 'paged_cubit.dart';
import 'skeleton/skeleton_variants.dart';
import 'states/state_views.dart';
import 'app_surfaces.dart';
import 'value_widgets.dart';

/// What a status means, independent of the words it arrives in.
///
/// The status *values* come from the server; only the tone is decided here,
/// and an unrecognised one stays [StatusTone.unknown] rather than being
/// guessed into a colour it has not earned.
StatusTone toneForStatus(String status) => switch (status) {
      'approved' || 'ready' || 'delivered' || 'confirmed' || 'paid' || 'active' ||
      'completed' || 'passed' || 'success' || 'verified' =>
        StatusTone.good,
      'submitted' || 'under_review' || 'pending' || 'pending_review' || 'dispatched' ||
      'en_route' || 'arrived' || 'issued' || 'processing' || 'in_transit' ||
      'partially_paid' =>
        StatusTone.inFlight,
      'overdue' || 'disputed' || 'cancel_requested' || 'warning' || 'unpaid' => StatusTone.warn,
      'rejected' || 'canceled' || 'cancelled' || 'blacklisted' || 'suspended' ||
      'failed' || 'expired' || 'terminated' || 'blocked' || 'declined' =>
        StatusTone.danger,
      _ => StatusTone.unknown,
    };

/// A status, as a Driver pill: the word in its tone's colour on that tone's
/// own tint (the "متأخر" badge). The word still carries the meaning, so the
/// state stays legible to someone who cannot separate the hues.
class StatusChip extends StatelessWidget {
  final String status;

  /// A label already localized by the server, when it sent one.
  final String? label;

  const StatusChip({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final tone = toneForStatus(status);

    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.toneTint(tone),
        borderRadius: AppTokens.fullRadius,
      ),
      child: Text(
        label?.isNotEmpty == true ? label! : localize(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tokens.toneColor(tone),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// The server's own label wins; failing that the app translates the status
  /// itself, and only a status nobody has a word for falls through to
  /// [_humanize].
  static String localize(String status) {
    if (status.isEmpty) return '—';
    final key = 'status.$status';
    final translated = key.tr();
    // easy_localization echoes the key back when it has no entry for it.
    return translated == key ? _humanize(status) : translated;
  }

  /// `under_review` → `Under review`. A formatting fallback, not a
  /// translation — reached only for a status the app has never seen.
  static String _humanize(String status) {
    final words = status.replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// Legacy: a status mark down a row's reading-start edge. Kept for the rows
/// that have not moved to cards yet.
BoxBorder ledgerBorder(BuildContext context, String status) {
  final tokens = context.tokens;
  final mark = tokens.markFor(toneForStatus(status));

  return BorderDirectional(
    start: mark == null
        ? BorderSide.none
        : BorderSide(color: mark, width: AppTokens.markWidth),
    bottom: BorderSide(color: tokens.divider, width: AppTokens.ruleWidth),
  );
}

/// A document in a list, as a Driver item card: the serial on top with its
/// status pill at the end, the counterparty under it, then the meta line with
/// the amount aligned at the end so amounts still line up down the list.
class DocumentTile extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final String status;
  final num? amount;
  final String? currency;

  /// The document's kind — drawn as a leading disc only when there is no
  /// [code] to identify the row.
  final IconData icon;
  final Widget? badge;
  final VoidCallback onTap;

  const DocumentTile({
    super.key,
    required this.code,
    required this.title,
    required this.status,
    required this.icon,
    required this.onTap,
    this.subtitle = '',
    this.amount,
    this.currency,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final hasCode = code.isNotEmpty;
    final heading = hasCode ? code : title;

    return Semantics(
      button: true,
      child: AppCard.item(
        onTap: onTap,
        child: Row(
          children: [
            if (!hasCode) ...[
              AppIconCircle(icon, size: 40),
              const SizedBox(width: AppTokens.space3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          heading,
                          style: hasCode
                              ? AppType.code(tokens.textPrimary)
                              : theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      StatusChip(status: status),
                    ],
                  ),
                  if (hasCode && title.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space1),
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (subtitle.isNotEmpty || amount != null) ...[
                    const SizedBox(height: AppTokens.space1),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (amount != null) ...[
                          const SizedBox(width: AppTokens.space2),
                          MoneyText(
                            amount!,
                            currency: currency?.isNotEmpty == true ? currency! : 'SAR',
                            style: AppType.ledger(tokens.textPrimary),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(height: AppTokens.space2),
                    badge!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            DirectionalChevron(size: 20, color: tokens.iconMuted),
          ],
        ),
      ),
    );
  }
}

/// A vertical timeline, RTL-correct: the rail sits on the reading-start side
/// and the connector is drawn with directional padding rather than a fixed
/// left offset.
class DocumentTimeline extends StatelessWidget {
  final List<TimelineEvent> events;

  const DocumentTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final locale = context.locale.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    // The most recent entry is the teal one — the rest are
                    // history, drawn as tinted dots on a quiet rail.
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsetsDirectional.only(top: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0 ? tokens.primary : tokens.primaryTint,
                        border: i == 0
                            ? Border.all(
                                color: tokens.primaryTint,
                                width: 3,
                                strokeAlign: BorderSide.strokeAlignOutside,
                              )
                            : null,
                      ),
                    ),
                    if (i != events.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: tokens.divider,
                            borderRadius: AppTokens.fullRadius,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          events[i].title.isNotEmpty ? events[i].title : events[i].event,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (events[i].description.isNotEmpty)
                          Text(events[i].description, style: theme.textTheme.bodySmall),
                        if (events[i].at != null)
                          Text(
                            AppDates.dateTime(events[i].at, locale),
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The list half of every document screen: skeleton, offline, error, empty,
/// rows, infinite scroll and pull-to-refresh, in one place.
class PagedListView<T> extends StatefulWidget {
  final PagedState<T> state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(T item) itemBuilder;
  final String emptyTitle;
  final String? emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget? header;

  /// Item cards sit inside the page gutter by default.
  final EdgeInsetsGeometry padding;

  /// The empty state's icon — the content's own, not a generic inbox.
  final IconData emptyIcon;

  const PagedListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptyBody,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.header,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppTokens.gutter,
      AppTokens.space3,
      AppTokens.gutter,
      0,
    ),
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
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
    if (remaining < 400) widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (state.loading) return const ListSkeleton(rows: 6);
    // The non-list states stay pull-to-refreshable: the state views scroll.
    if (state.offline && state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: AppOfflineState(onRetry: widget.onRefresh),
      );
    }
    if (state.failedOutright) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: AppErrorState(message: state.errorMessage!, onRetry: widget.onRefresh),
      );
    }
    if (state.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: AppEmptyState(
          icon: widget.emptyIcon,
          title: widget.emptyTitle,
          body: widget.emptyBody,
          actionLabel: widget.emptyActionLabel,
          onAction: widget.onEmptyAction,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _controller,
        padding: widget.padding,
        itemCount: state.items.length + (widget.header != null ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          var cursor = index;
          if (widget.header != null) {
            if (cursor == 0) return widget.header!;
            cursor -= 1;
          }
          if (cursor >= state.items.length) {
            // Room under the last card for a FAB or the nav bar.
            if (!state.loadingMore) return const SizedBox(height: 96);
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
          return widget.itemBuilder(state.items[cursor]);
        },
      ),
    );
  }
}
