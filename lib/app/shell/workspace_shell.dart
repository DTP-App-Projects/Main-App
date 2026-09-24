import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/locale_switch.dart';
import '../../core/session/session_cubit.dart';
import '../../core/ui/shell_scope.dart';
import '../../core/ui/ui.dart';
import '../../core/utils/roots/app_router.dart';
import '../../core/workspace/workspace.dart';
import '../../core/workspace/workspace_cubit.dart';
import '../../features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import '../../features/shared/notifications/presentation/views/notifications_view.dart';
import '../../features/shared/organization/org_switcher_sheet.dart';
import '../../features/supplier/views/supplier_home_view.dart';
import '../../features/trader/home/views/trader_home_view.dart';
import '../../features/shared/organization/workspace_switcher.dart';

/// One shell per workspace, not one shell with `if` statements.
///
/// The whole subtree is keyed on the active workspace, so flipping the
/// switcher disposes every workspace-scoped cubit underneath and rebuilds it
/// for the other side — no trader list can survive into a supplier screen.
class TraderShell extends StatelessWidget {
  const TraderShell({super.key});

  @override
  Widget build(BuildContext context) => const _Shell(
        workspace: Workspace.trader,
        home: TraderHomeView(),
        trade: TraderDocumentsTab(),
      );
}

class SupplierShell extends StatelessWidget {
  const SupplierShell({super.key});

  @override
  Widget build(BuildContext context) => const _Shell(
        workspace: Workspace.supplier,
        home: SupplierHomeView(),
        trade: SupplierDocumentsTab(),
      );
}

class _Shell extends StatefulWidget {
  final Workspace workspace;
  final Widget home;
  final Widget trade;

  const _Shell({
    required this.workspace,
    required this.home,
    required this.trade,
  });

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  ShellTab _tab = ShellTab.home;

  /// Tabs are built the first time they are opened and then kept alive, so
  /// switching back does not lose scroll position or refetch.
  final Set<ShellTab> _visited = {ShellTab.home};

  void _select(ShellTab tab) => setState(() {
        _tab = tab;
        _visited.add(tab);
      });

  Widget _tabBody(ShellTab tab) => switch (tab) {
        ShellTab.home => widget.home,
        ShellTab.trade => widget.trade,
        ShellTab.notifications => const NotificationsView(),
        ShellTab.more => const _MoreTab(),
      };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    final unread = context.select<NotificationsCubit, int>((c) => c.state.unreadCount);
    final t = context.tokens;

    // No app bar on tab roots (Driver): the status bar sits on the page, or
    // on the gradient header on the More tab.
    final onGradient = _tab == ShellTab.more;
    final overlay = (t.isDark || onGradient) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return KeyedSubtree(
      key: ValueKey(widget.workspace),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay.copyWith(statusBarColor: Colors.transparent),
        child: ShellScope(
          current: _tab,
          select: _select,
          child: Scaffold(
            body: Column(
              children: [
                if (session.isStale)
                  SafeArea(
                    bottom: false,
                    child: StaleBanner(onRefresh: context.read<SessionCubit>().refresh),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _tab.index,
                    children: [
                      for (final tab in ShellTab.values)
                        _visited.contains(tab) ? _tabBody(tab) : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: AppNavBar(
              currentIndex: _tab.index,
              onTap: (index) => _select(ShellTab.values[index]),
              items: [
                AppNavItem(icon: Icons.home_outlined, label: 'nav.home'.tr()),
                AppNavItem(icon: Icons.work_outline_rounded, label: 'nav.trade'.tr()),
                // The badge is fed by the session-scoped cubit, so it is right
                // even before the list has been opened.
                AppNavItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'nav.notifications'.tr(),
                  badge: unread,
                ),
                AppNavItem(icon: Icons.person_outline_rounded, label: 'nav.more'.tr()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The account tab — the Driver profile (S3): a gradient header with the
/// avatar, name and role, then grouped section cards, then the danger group.
class _MoreTab extends StatelessWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionCubit>().state;
    final workspace = context.watch<WorkspaceCubit>().state;
    final user = session.bootstrap?.user;
    final name = user?.name ?? '';
    final arabic = context.locale.languageCode == 'ar';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppGradientHeader(
          child: Row(
            children: [
              AppInitialAvatar(name: name, size: 64, onGradient: true),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    if ((user?.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space3),
                    const RoleBadge(onGradient: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.gutter,
            0,
            AppTokens.gutter,
            AppTokens.space8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionLabel('more.section_account'.tr()),
              AppMenuGroup(children: [
                AppMenuRow(
                  icon: Icons.apartment_outlined,
                  title: 'organization.switch_title'.tr(),
                  subtitle: workspace?.organizationName,
                  onTap: () => showOrgSwitcher(context),
                ),
                if (workspace?.canSwitch ?? false)
                  AppMenuRow(
                    icon: Icons.swap_horiz_rounded,
                    title: 'workspace.switch_title'.tr(),
                    value: workspaceLabel(workspace!.active),
                    onTap: () => showWorkspaceSwitcher(context),
                  ),
                AppMenuRow(
                  icon: Icons.fact_check_outlined,
                  title: 'onboarding.title'.tr(),
                  onTap: () => context.push(AppRoutes.onboarding),
                ),
                AppMenuRow(
                  icon: Icons.manage_accounts_outlined,
                  title: 'account.title'.tr(),
                  onTap: () => context.push(AppRoutes.accountSettings),
                ),
                AppMenuRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'subscription.title'.tr(),
                  onTap: () => context.push(AppRoutes.subscription),
                ),
              ]),
              AppSectionLabel('more.section_business'.tr()),
              AppMenuGroup(children: [
                AppMenuRow(
                  icon: Icons.handshake_outlined,
                  title: 'contract.title'.tr(),
                  onTap: () => context.push(AppRoutes.contracts),
                ),
                AppMenuRow(
                  icon: Icons.shelves,
                  title: 'shelf.title'.tr(),
                  onTap: () => context.push(AppRoutes.shelf),
                ),
                AppMenuRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'settlement.title'.tr(),
                  onTap: () => context.push(AppRoutes.settlements),
                ),
                AppMenuRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'wallet.title'.tr(),
                  onTap: () => context.push(AppRoutes.wallet),
                ),
              ]),
              // The marketplace sits outside both workspaces — the same account
              // buys and sells there whichever shell it is standing in.
              AppSectionLabel('more.section_marketplace'.tr()),
              AppMenuGroup(children: [
                AppMenuRow(
                  icon: Icons.storefront_outlined,
                  title: 'shop.title'.tr(),
                  onTap: () => context.push(AppRoutes.shop),
                ),
                AppMenuRow(
                  icon: Icons.shopping_bag_outlined,
                  title: 'shop.orders'.tr(),
                  onTap: () => context.push(AppRoutes.shopOrders),
                ),
                AppMenuRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'shop.chat'.tr(),
                  onTap: () => context.push(AppRoutes.shopChat),
                ),
              ]),
              AppSectionLabel('more.section_app'.tr()),
              AppMenuGroup(children: [
                AppMenuRow(
                  icon: Icons.language_rounded,
                  title: 'common.language'.tr(),
                  value: arabic ? 'common.arabic'.tr() : 'common.english'.tr(),
                  onTap: () => _toggleLanguage(context),
                ),
              ]),
              const SizedBox(height: AppTokens.sectionGap),
              AppMenuGroup(children: [
                AppMenuRow(
                  icon: Icons.logout_rounded,
                  title: 'common.logout'.tr(),
                  tone: AppTone.danger,
                  onTap: () => _confirmLogout(context),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLanguage(BuildContext context) async {
    // The UI locale and the `Accept-Language` header move together.
    await toggleAppLocale(context);
    if (!context.mounted) return;
    // The locale drives every localized field the server returns — so the
    // shell's data has to be re-read, not just re-rendered.
    await context.read<SessionCubit>().refresh();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'common.logout'.tr(),
      body: 'common.logout_confirm'.tr(),
      confirmLabel: 'common.logout'.tr(),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<SessionCubit>().logout();
  }
}
