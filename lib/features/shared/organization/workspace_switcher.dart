import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ui/ui.dart';
import '../../../core/workspace/workspace.dart';
import '../../../core/workspace/workspace_cubit.dart';
import '../../../core/workspace/workspace_state.dart';

String workspaceLabel(Workspace workspace) =>
    workspace == Workspace.trader ? 'workspace.trader'.tr() : 'workspace.supplier'.tr();

/// Opens the side picker. Only meaningful for `business_mode == 'hybrid'`.
Future<void> showWorkspaceSwitcher(BuildContext context) {
  final state = context.read<WorkspaceCubit>().state;
  if (state == null || !state.canSwitch) return Future.value();
  return showAppSheet<void>(
    context: context,
    title: 'workspace.switch_title'.tr(),
    subtitle: 'workspace.switch_hint'.tr(namedArgs: {'workspace': workspaceLabel(state.active)}),
    builder: (_) => BlocProvider.value(
      value: context.read<WorkspaceCubit>(),
      child: _WorkspaceSheet(state: state),
    ),
  );
}

/// A Driver circle button in the home header. Visible **only** for hybrid
/// organizations — a single-side org has nothing to switch to, and a dead
/// control invites the 403 the switcher exists to prevent.
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceCubit>().state;
    if (state == null || !state.canSwitch) return const SizedBox.shrink();

    return AppCircleButton(
      icon: Icons.swap_horiz_rounded,
      tooltip: 'workspace.switch_title'.tr(),
      onPressed: () => showWorkspaceSwitcher(context),
    );
  }
}

class _WorkspaceSheet extends StatelessWidget {
  final WorkspaceState state;

  const _WorkspaceSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final workspace in state.availableWorkspaces)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
            child: AppCard.item(
              margin: EdgeInsetsDirectional.zero,
              borderColor: workspace == state.active ? t.primary : null,
              onTap: () {
                Navigator.of(context).pop();
                // Switching does not log out and does not re-fetch bootstrap —
                // the router moves to the other workspace's home and the shell
                // key rebuilds everything scoped to it.
                if (workspace != state.active) {
                  context.read<WorkspaceCubit>().switchTo(workspace);
                }
              },
              child: Row(
                children: [
                  AppIconCircle(
                    RoleBadge.iconFor(workspace),
                    tone: workspace == state.active ? AppTone.brand : AppTone.neutral,
                  ),
                  const SizedBox(width: AppTokens.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workspaceLabel(workspace), style: theme.textTheme.titleSmall),
                        if (!state.approvedWorkspaces.contains(workspace.api)) ...[
                          const SizedBox(height: 2),
                          Text('workspace.pending_review'.tr(), style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (workspace == state.active)
                    Icon(Icons.check_circle_rounded, color: t.primary)
                  else
                    RoleBadge(workspace: workspace),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
