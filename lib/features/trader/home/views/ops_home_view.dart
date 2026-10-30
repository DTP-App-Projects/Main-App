import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/session_cubit.dart';
import '../../../../core/ui/shell_scope.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../core/workspace/workspace_state.dart';
import '../../../../data/models/ops/ops_panel.dart';
import '../../../../data/models/ops/quick_action.dart';
import '../../../shared/notifications/presentation/view_models/notifications_cubit.dart';
import '../../../shared/organization/org_switcher_sheet.dart';
import '../../../shared/organization/workspace_switcher.dart';
import '../view_models/ops_panel_cubit.dart';

/// The server-driven home, shared by both workspaces — laid out as the Driver
/// home (S7): a greeting block, then what needs attention, then the figures,
/// the actions and the document groups.
///
/// Nothing here is computed: KPIs, the attention feed, the action grid and
/// the document menu all arrive filtered by workspace and permissions, and
/// are rendered as sent. The only client-side decision is **which screen a
/// `key` opens** — never the `route` field, which still carries pre-REST RPC
/// paths.
class OpsHomeView extends StatelessWidget {
  final Workspace workspace;

  /// Kept for call-site compatibility; the role now shows as a [RoleBadge].
  final String title;

  /// `key` → what to do. An unknown key is hidden, never a crash.
  final Map<String, VoidCallback Function(BuildContext context)> actionHandlers;

  /// A word in a document group's `key` → the list it opens. A group whose
  /// key matches nothing opens the Trade hub, where every list lives.
  final Map<String, String> documentRoutes;

  const OpsHomeView({
    super.key,
    required this.workspace,
    required this.title,
    required this.actionHandlers,
    this.documentRoutes = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OpsPanelCubit>();
    final state = cubit.state;

    if (state.loading && state.panel == null) {
      return const Column(
        children: [
          _Greeting(),
          Expanded(child: _HomeSkeleton()),
        ],
      );
    }
    if (state.panel == null) {
      return Column(
        children: [
          const _Greeting(),
          Expanded(
            child: state.offline
                ? AppOfflineState(onRetry: cubit.load)
                : AppErrorState(message: state.errorMessage ?? '', onRetry: cubit.load),
          ),
        ],
      );
    }

    final panel = state.panel!;
    final locale = context.locale.toString();
    final permissions = context.watch<WorkspaceCubit>().state;
    final visibleActions = panel.quickActions
        .where((action) => actionHandlers.containsKey(action.key))
        .toList();
    final attention = panel.attention.where((item) => item.title(locale).isNotEmpty).toList();
    final nothing =
        panel.kpis.isEmpty &&
        visibleActions.isEmpty &&
        attention.isEmpty &&
        panel.documentGroups.isEmpty;

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Greeting(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              AppTokens.space2,
              AppTokens.gutter,
              AppTokens.space8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Urgent first: the Driver home leads with today's work.
                if (attention.isNotEmpty) ...[
                  AppHeaderCard(
                    icon: Icons.notification_important_outlined,
                    iconColor: context.tokens.danger,
                    title: 'home.attention'.tr(),
                    trailing: AppCountBadge(attention.length),
                    bodyPadding: const EdgeInsetsDirectional.fromSTEB(
                      AppTokens.space4,
                      AppTokens.space4,
                      AppTokens.space4,
                      AppTokens.space1,
                    ),
                    child: Column(
                      children: [
                        for (final item in attention) _AttentionRow(item: item, locale: locale),
                      ],
                    ),
                  ),
                ],

                if (panel.kpis.isNotEmpty) ...[
                  AppSectionLabel('home.overview'.tr()),
                  _ResponsiveGrid(
                    minTileWidth: 150,
                    children: [for (final kpi in panel.kpis) _KpiTile(kpi: kpi, locale: locale)],
                  ),
                ],

                if (visibleActions.isNotEmpty) ...[
                  AppSectionLabel('home.quick_actions'.tr()),
                  _ResponsiveGrid(
                    minTileWidth: 150,
                    children: [
                      for (final action in visibleActions)
                        _ActionTile(
                          action: action,
                          locale: locale,
                          permissions: permissions,
                          onTap: actionHandlers[action.key]!(context),
                        ),
                    ],
                  ),
                ],

                if (panel.documentGroups.isNotEmpty) ...[
                  AppSectionLabel(
                    'nav.trade'.tr(),
                    trailing: ShellScope.maybeOf(context) == null
                        ? null
                        : AppButton.text(
                            label: 'common.see_all'.tr(),
                            height: 32,
                            onPressed: () => ShellScope.maybeOf(context)!.select(ShellTab.trade),
                          ),
                  ),
                  AppMenuGroup(
                    children: [
                      for (final group in panel.documentGroups)
                        AppMenuRow(
                          icon: _groupIcon(group.key),
                          title: _groupName(group, locale),
                          trailing: group.count == 0 ? null : AppCountBadge(group.count),
                          onTap: () => _openGroup(context, group),
                        ),
                    ],
                  ),
                ],

                if (nothing)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space8),
                    child: AppEmptyState(
                      icon: Icons.dashboard_outlined,
                      title: 'home.empty_title'.tr(),
                      body: 'home.empty_body'.tr(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// B5: every group row now goes somewhere — its own list when the key
  /// names one, otherwise the Trade hub that holds them all.
  void _openGroup(BuildContext context, DocumentGroup group) {
    final key = group.key.toLowerCase();
    for (final entry in documentRoutes.entries) {
      if (key.contains(entry.key)) {
        context.push(entry.value);
        return;
      }
    }
    final shell = ShellScope.maybeOf(context);
    if (shell != null) shell.select(ShellTab.trade);
  }

  /// The server's label when it sent one; otherwise the group key named in
  /// the app's language (`purchase_orders` → «أوامر الشراء»).
  static String _groupName(DocumentGroup group, String locale) {
    final server = group.label(locale);
    if (server.isNotEmpty) return server;
    final key = 'home.group_${group.key}';
    final translated = key.tr();
    if (translated != key) return translated;
    final words = group.key.replaceAll('_', ' ');
    return words.isEmpty ? '—' : words[0].toUpperCase() + words.substring(1);
  }

  static IconData _groupIcon(String key) {
    final k = key.toLowerCase();
    if (k.contains('order')) return Icons.receipt_long_outlined;
    if (k.contains('deliver') || k.contains('shipment') || k.contains('outbound')) {
      return Icons.local_shipping_outlined;
    }
    if (k.contains('receipt')) return Icons.inventory_2_outlined;
    if (k.contains('invoice') || k.contains('payable') || k.contains('receivable')) {
      return Icons.request_quote_outlined;
    }
    if (k.contains('collection') || k.contains('payment')) return Icons.payments_outlined;
    if (k.contains('return')) return Icons.assignment_return_outlined;
    if (k.contains('contract')) return Icons.handshake_outlined;
    // Not `receipt_long`: on this grid that is already purchase orders.
    if (k.contains('settlement')) return Icons.account_balance_outlined;
    return Icons.folder_outlined;
  }
}

/// Driver S7: "Good morning", the name large, today's date — with the
/// organization and role underneath and the circle buttons at the end.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final user = context.select<SessionCubit, String>((c) => c.state.bootstrap?.user.name ?? '');
    final unread = context.select<NotificationsCubit, int>((c) => c.state.unreadCount);
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'home.greeting_morning'.tr() : 'home.greeting_evening'.tr();
    final firstName = user.trim().split(RegExp(r'\s+')).first;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.gutter,
          AppTokens.space5,
          AppTokens.gutter,
          AppTokens.space4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: theme.textTheme.bodyLarge?.copyWith(color: t.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstName.isEmpty ? 'app.name'.tr() : firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTokens.space1),
                  Text(DateFormat.yMMMMEEEEd(locale).format(now), style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppTokens.space3),
                  Wrap(
                    spacing: AppTokens.space2,
                    runSpacing: AppTokens.space2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: const [RoleBadge(), OrgHeader()],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space3),
            Row(
              children: [
                const WorkspaceSwitcher(),
                const SizedBox(width: AppTokens.space2),
                AppCircleButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'nav.notifications'.tr(),
                  dot: unread > 0,
                  onPressed: () {
                    // The trader's bar has the shop in that slot, so the
                    // bell opens the list as its own screen there.
                    final shell = ShellScope.maybeOf(context);
                    if (shell != null && shell.has(ShellTab.notifications)) {
                      shell.select(ShellTab.notifications);
                    } else {
                      context.push(AppRoutes.notifications);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays tiles out in as many equal columns as fit, never fewer than two.
class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;

  const _ResponsiveGrid({required this.children, required this.minTileWidth});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = AppTokens.space3;
      final columns = ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor().clamp(2, 4);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

/// Severity words first; anything else is read as a document status
/// (`overdue`, `arrived`…) through the shared status tones.
AppTone _toneFor(String severity) => switch (severity) {
  'danger' || 'critical' || 'high' => AppTone.danger,
  'warn' || 'warning' || 'medium' => AppTone.warning,
  'info' || 'low' => AppTone.info,
  'ok' || 'good' || '' => AppTone.brand,
  _ => switch (toneForStatus(severity)) {
    StatusTone.danger => AppTone.danger,
    StatusTone.warn => AppTone.warning,
    StatusTone.inFlight => AppTone.info,
    _ => AppTone.brand,
  },
};

class _KpiTile extends StatelessWidget {
  final KpiTile kpi;
  final String locale;

  const _KpiTile({required this.kpi, required this.locale});

  @override
  Widget build(BuildContext context) =>
      AppStatTile(label: kpi.label(locale), value: kpi.value, tone: _toneFor(kpi.severity));
}

class _ActionTile extends StatelessWidget {
  final QuickAction action;
  final String locale;
  final WorkspaceState? permissions;
  final VoidCallback onTap;

  const _ActionTile({
    required this.action,
    required this.locale,
    required this.permissions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    // The server already filtered by permission; this second check only
    // greys out a stale response, and an owner passes both.
    final allowed =
        permissions == null ||
        action.allPermissions.isEmpty ||
        permissions!.canAny(action.allPermissions);

    return Opacity(
      opacity: allowed ? 1 : 0.5,
      child: AppCard(
        radius: AppTokens.lgRadius,
        padding: const EdgeInsets.all(AppTokens.space4),
        onTap: allowed ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconCircle(
              _iconFor(action.key),
              size: 40,
              tone: allowed ? AppTone.brand : AppTone.neutral,
            ),
            const SizedBox(height: AppTokens.space3),
            Text(
              action.label(locale),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(color: allowed ? null : t.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String key) => switch (key) {
    'create_purchase_draft' => Icons.add_shopping_cart_rounded,
    'confirm_goods_receipt' => Icons.inventory_2_outlined,
    'claim_payment' => Icons.payments_outlined,
    'create_delivery_note' => Icons.local_shipping_outlined,
    'dispatch_delivery' => Icons.send_rounded,
    'track_outbound_shipments' => Icons.map_outlined,
    'issue_invoice' => Icons.request_quote_outlined,
    'record_collection' => Icons.account_balance_wallet_outlined,
    'confirm_collection' => Icons.verified_outlined,
    'approve_purchase_order' => Icons.fact_check_outlined,
    'review_contract' || 'create_contract' => Icons.description_outlined,
    'manage_shelves' => Icons.shelves,
    _ => Icons.bolt_rounded,
  };
}

/// One attention item, as a Driver inner row: tone disc, title, body, and
/// the severity as a pill (once — the disc already carries the colour).
class _AttentionRow extends StatelessWidget {
  final AttentionItem item;
  final String locale;

  const _AttentionRow({required this.item, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _toneFor(item.severity);
    final body = item.body(locale);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconCircle(
            tone == AppTone.danger || tone == AppTone.warning
                ? Icons.priority_high_rounded
                : Icons.info_outline_rounded,
            size: 36,
            tone: tone,
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title(locale), style: theme.textTheme.titleSmall),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (item.severity.isNotEmpty) ...[
            const SizedBox(width: AppTokens.space2),
            StatusChip(status: item.severity),
          ],
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.gutter,
        AppTokens.space2,
        AppTokens.gutter,
        AppTokens.space4,
      ),
      children: const [
        Skeleton.box(height: 140),
        SizedBox(height: AppTokens.sectionGap),
        Skeleton.line(widthFactor: 0.3, height: 13),
        SizedBox(height: AppTokens.space3),
        Row(
          children: [
            Expanded(child: Skeleton.box(height: 96)),
            SizedBox(width: AppTokens.space3),
            Expanded(child: Skeleton.box(height: 96)),
          ],
        ),
        SizedBox(height: AppTokens.space3),
        Row(
          children: [
            Expanded(child: Skeleton.box(height: 96)),
            SizedBox(width: AppTokens.space3),
            Expanded(child: Skeleton.box(height: 96)),
          ],
        ),
        SizedBox(height: AppTokens.sectionGap),
        Skeleton.box(height: 180),
      ],
    ),
  );
}
