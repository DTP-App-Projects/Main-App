import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/session_cubit.dart';
import '../../../core/session/session_state.dart';
import '../../../core/ui/ui.dart';
import '../../../core/workspace/workspace.dart';

/// Organizations come from `bootstrap.organizations`. Switching changes the
/// `X-Organization-Id` header and re-fetches bootstrap, because permissions,
/// journey and business mode are all per-organization.
Future<void> showOrgSwitcher(BuildContext context) => showAppSheet<void>(
      context: context,
      title: 'organization.switch_title'.tr(),
      builder: (_) => BlocProvider.value(
        value: context.read<SessionCubit>(),
        child: const _OrgSheet(),
      ),
    );

/// `business_mode` as words, not the raw API value.
String businessModeLabel(String mode) => switch (mode) {
      BusinessMode.trader => 'workspace.trader'.tr(),
      BusinessMode.supplier => 'workspace.supplier'.tr(),
      BusinessMode.hybrid => 'register.mode_hybrid'.tr(),
      _ => mode,
    };

class _OrgSheet extends StatelessWidget {
  const _OrgSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final state = context.watch<SessionCubit>().state;
    final organizations = state.bootstrap?.organizations ?? const [];

    if (organizations.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
        child: Text(
          'organization.no_organizations'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
      );
    }

    // The sheet scrolls (showAppSheet), so a long list of organizations no
    // longer overflows.
    return AppMenuGroup(
      children: [
        for (final org in organizations)
          _OrgRow(
            name: org.displayName,
            subtitle: [
              if (org.isOwner) 'organization.owner'.tr(),
              businessModeLabel(org.businessMode),
            ].join(' · '),
            active: org.id == state.organization?.id,
            onTap: () {
              Navigator.of(context).pop();
              if (org.id != state.organization?.id) {
                context.read<SessionCubit>().switchOrganization(org.id);
              }
            },
          ),
      ],
    );
  }
}

class _OrgRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _OrgRow({
    required this.name,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
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
              AppInitialAvatar(name: name),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (active) Icon(Icons.check_circle_rounded, color: t.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The organization line in the home header: the name with a chevron that
/// opens the switcher.
class OrgHeader extends StatelessWidget {
  /// Kept for call-site compatibility; the role is shown by [RoleBadge].
  final String? workspaceLabel;

  const OrgHeader({super.key, this.workspaceLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final organization = context.select<SessionCubit, SessionState>((c) => c.state).organization;

    return InkWell(
      onTap: () => showOrgSwitcher(context),
      borderRadius: AppTokens.smRadius,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_outlined, size: 18, color: t.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                organization?.displayName ?? 'app.name'.tr(),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: t.textSecondary),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 20, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}
