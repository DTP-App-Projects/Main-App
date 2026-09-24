import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/theme/tokens.dart';
import '../app_buttons.dart';
import '../app_surfaces.dart';

/// Error, empty, offline and success are different states with different
/// next actions, drawn as the Driver empty state: a 96dp tinted disc holding a
/// **contextual** icon, an 18/700 title, a muted body and an optional CTA.
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppTone tone;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone = AppTone.brand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final view = Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppTokens.space8,
            vertical: AppTokens.space6,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconCircle(icon, size: 96, iconSize: 40, tone: tone),
                const SizedBox(height: AppTokens.space5),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    body!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: AppTokens.space6),
                  AppButton.primary(label: actionLabel!, onPressed: onAction, expand: false),
                ],
              ],
            ),
          ),
        );

        // Already inside a scrollable (a ListView row): just centre it.
        if (!constraints.hasBoundedHeight) return Center(child: view);

        // Scrollable so it never overflows in a short sheet or a landscape
        // phone — and pull-to-refresh still works around it — while staying
        // centred when there is room.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: Center(child: view),
          ),
        );
      },
    );
  }
}

/// [message] is already localized — pass it through `ErrorMessages.forCode`,
/// never a raw server key.
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => AppStateView(
        icon: Icons.error_outline_rounded,
        tone: AppTone.danger,
        title: 'states.error_title'.tr(),
        body: message,
        actionLabel: onRetry == null ? null : 'common.retry'.tr(),
        onAction: onRetry,
      );
}

class AppEmptyState extends StatelessWidget {
  final String? title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The content's own icon (a truck for shipments, not a generic inbox).
  final IconData icon;

  const AppEmptyState({
    super.key,
    this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) => AppStateView(
        icon: icon,
        title: title ?? 'states.empty_title'.tr(),
        body: body,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

/// Offline is recoverable by the user, an error usually is not — so it wears
/// a neutral disc rather than a red one.
class AppOfflineState extends StatelessWidget {
  final VoidCallback? onRetry;

  const AppOfflineState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => AppStateView(
        icon: Icons.wifi_off_rounded,
        tone: AppTone.neutral,
        title: 'states.offline_title'.tr(),
        body: 'states.offline_body'.tr(),
        actionLabel: onRetry == null ? null : 'common.retry'.tr(),
        onAction: onRetry,
      );
}

/// The end of a flow that succeeded — a return filed, a receipt recorded.
class AppSuccessState extends StatelessWidget {
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Extra content under the body (a follow-up action, a warning).
  final Widget? child;

  const AppSuccessState({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return AppStateView(
        icon: Icons.check_rounded,
        title: title,
        body: body,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    }
    return ListView(
      padding: AppTokens.pagePadding,
      children: [
        const SizedBox(height: AppTokens.space8),
        AppStateView(icon: Icons.check_rounded, title: title, body: body),
        child!,
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: AppTokens.space4),
          AppButton.primary(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}

/// Shown above cached content so "old data" never masquerades as live data.
class StaleBanner extends StatelessWidget {
  final VoidCallback? onRefresh;

  const StaleBanner({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.gutter,
          AppTokens.space2,
          AppTokens.gutter,
          0,
        ),
        child: AppBanner(
          message: 'states.stale_banner'.tr(),
          tone: AppTone.warning,
          icon: Icons.cloud_off_rounded,
          margin: EdgeInsetsDirectional.zero,
          action: onRefresh == null
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton.text(label: 'common.retry'.tr(), onPressed: onRefresh, height: 36),
                ),
        ),
      );
}
