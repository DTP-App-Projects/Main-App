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
///
/// Every value below is documented (docs/tajerid-customer-api.md, the Postman
/// collection or the event catalogue) except `en_route`, `arrived` and
/// `partially_paid`, which pre-date the redesign and are listed as open
/// questions in UI_REDESIGN_PLAN.md §7. Do not add guesses here.
///
/// The compliance release (docs/compliance-implementation.md, verified on
/// staging 2026-10-05) adds: `accepted`, `signed`, `earned`, `credit_issued`,
/// `goods_returned`, `requested`, `offered`, `open`, `answered`,
/// `supply_suspended`, `received_unconfirmed`, `accelerated`, `void`,
/// `cancelled`.
///
/// The supplier fleet brief (2026-10-27) adds `on_road`, `returning` and
/// `reconciled` (van trips) and `in_transit` (internal transfers).
StatusTone toneForStatus(String status) => switch (status) {
      'approved' || 'ready' || 'delivered' || 'confirmed' || 'paid' || 'active' ||
      'completed' || 'verified' || 'received' || 'ok' || 'accepted' || 'signed' ||
      'earned' || 'credit_issued' || 'goods_returned' ||
      // `credit_check_status`, seen on every staging order (2026-10-05).
      'passed' || 'reconciled' =>
        StatusTone.good,
      'submitted' || 'under_review' || 'pending' || 'pending_review' || 'dispatched' ||
      'en_route' || 'arrived' || 'issued' || 'processing' || 'partially_paid' ||
      'calculated' || 'reviewed' || 'sent' || 'info' || 'requested' || 'offered' ||
      'open' || 'answered' ||
      // An instalment that is due and not yet late (`due_schedules[].status`).
      'due' || 'on_road' || 'returning' || 'in_transit' =>
        StatusTone.inFlight,
      'overdue' || 'disputed' || 'cancel_requested' || 'warn' || 'supply_suspended' ||
      'received_unconfirmed' =>
        StatusTone.warn,
      'rejected' || 'canceled' || 'blacklisted' || 'suspended' || 'failed' ||
      'expired' || 'terminated' || 'blocked' || 'declined' || 'danger' ||
      'accelerated' || 'void' || 'cancelled' =>
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
    if (translated != key) return translated;
    // An undocumented value: shown as-is (there is no honest translation for
    // it), and reported in debug builds so runtime testing surfaces it.
    assert(() {
      debugPrint('StatusChip: no translation for backend status "$status"');
      return true;
    }());
    return _humanize(status);
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

  /// The server's title in the app language; failing that the event code
  /// translated (`timeline.<event>`), never a raw `order_created`.
  static String _title(TimelineEvent e, String locale) {
    final server = e.localizedTitle(locale);
    if (server.isNotEmpty) return server;
    final key = 'timeline.${e.event}';
    final translated = key.tr();
    if (translated != key) return translated;
    return e.event.isEmpty ? '—' : StatusChip.localize(e.event);
  }

  /// The approval step an entry belongs to (`credit_check`,
  /// `supplier_review`), translated. Document numbers are not repeated.
  static String? _step(TimelineEvent e) {
    if (e.ref.isEmpty) return null;
    final key = 'timeline.step_${e.ref}';
    final translated = key.tr();
    return translated == key ? null : translated;
  }

  /// The server note is English-only free text. The ones it is known to send
  /// are translated; anything else is shown as sent.
  static String? _note(TimelineEvent e) {
    final note = e.description.trim();
    if (note.isEmpty) return null;
    final changed = RegExp(r'^Status changed to ([a-z_]+)\.?$').firstMatch(note);
    if (changed != null) {
      return 'timeline.status_changed'.tr(namedArgs: {'status': StatusChip.localize(changed.group(1)!)});
    }
    if (note == 'Credit module is disabled by platform admin.') return 'timeline.credit_module_disabled'.tr();
    final cancel = RegExp(r'^Cancel request (accepted|rejected)\.?$').firstMatch(note);
    if (cancel != null) return 'timeline.cancel_request_${cancel.group(1)}'.tr();
    return note;
  }

  /// Newest first by date, whatever order the server sent (the API does not
  /// document one). Undated events and ties keep their server order, after
  /// the dated ones — so the highlighted entry is always the latest.
  static List<TimelineEvent> newestFirst(List<TimelineEvent> events) {
    final indexed = [for (var i = 0; i < events.length; i++) (i, events[i])];
    indexed.sort((a, b) {
      final at = a.$2.at;
      final bt = b.$2.at;
      if (at != null && bt != null && at != bt) return bt.compareTo(at);
      if (at == null && bt != null) return 1;
      if (at != null && bt == null) return -1;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final ordered = newestFirst(events);

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final locale = context.locale.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ordered.length; i++)
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
                    if (i != ordered.length - 1)
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
                        Text(_title(ordered[i], locale), style: theme.textTheme.titleSmall),
                        if (_step(ordered[i]) case final step?)
                          Text(step, style: theme.textTheme.bodySmall),
                        if (_note(ordered[i]) case final note?)
                          Text(note, style: theme.textTheme.bodySmall),
                        if (ordered[i].at != null)
                          Text(
                            AppDates.dateTime(ordered[i].at, locale),
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
