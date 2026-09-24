import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/bootstrap/organization.dart';
import '../../data/repositories/ops_repository.dart';
import '../network/api_result.dart';
import '../session/session_store.dart';
import 'workspace.dart';
import 'workspace_state.dart';

/// The active workspace is client-side state — nothing is posted when the user
/// flips the switcher. What changes is the shell, the `?role=`/`?workspace=`
/// params, the theme, and which providers are alive.
///
/// `null` means "no organization resolved yet" (splash, login, onboarding).
class WorkspaceCubit extends Cubit<WorkspaceState?> {
  final SessionStore _session;
  final OpsRepository _ops;

  WorkspaceCubit(this._session, this._ops) : super(null);

  /// Called after bootstrap resolves an organization, and again on org switch.
  Future<void> hydrate(Organization org) async {
    final remembered = _session.rememberedWorkspace(org.id);
    final active = org.initialWorkspace(remembered);

    await _session.setOrganizationId(org.id);
    if (org.isHybrid) await _session.rememberWorkspace(org.id, active);

    emit(WorkspaceState(
      organizationId: org.id,
      organizationName: org.displayName,
      businessMode: org.businessMode,
      active: active,
      permissions: org.permissions.toSet(),
      isOwner: org.isOwner,
      approvedWorkspaces: org.approvedWorkspaces.toSet(),
      // Paint immediately in the palette the server last sent, so a cold
      // start does not flash the fallback colours before settling.
      theme: _session.cachedTheme(org.id, active) ?? ThemeTokens.fallbackFor(active),
    ));

    await refreshTheme();
  }

  /// Swap sides. Must not log out, must not re-fetch bootstrap.
  ///
  /// The shell is keyed on [WorkspaceState.active], so emitting a new active
  /// workspace tears down and rebuilds every workspace-scoped cubit beneath
  /// it — that is how stale trader data is kept off a supplier screen.
  Future<void> switchTo(Workspace workspace) async {
    final current = state;
    if (current == null || current.active == workspace) return;
    if (!current.availableWorkspaces.contains(workspace)) return;

    await _session.rememberWorkspace(current.organizationId, workspace);
    emit(current.copyWith(
      active: workspace,
      theme: _session.cachedTheme(current.organizationId, workspace) ??
          ThemeTokens.fallbackFor(workspace),
    ));

    await refreshTheme();
  }

  /// Reads the live palette for the active workspace and caches it.
  ///
  /// `/ops/quick_actions` is the smallest call that carries `theme`; the
  /// actions it also returns belong to the home screen, which fetches the
  /// fuller `/ops/panel` for itself.
  Future<void> refreshTheme() async {
    final current = state;
    if (current == null) return;

    final requested = current.active;
    final result = await _ops.quickActions(requested);
    if (result case Ok(:final data)) {
      await _session.cacheTheme(current.organizationId, requested, data.theme);
      // The user may have flipped the switcher while this was in flight; a
      // late answer must not repaint the workspace they moved to.
      if (state?.active == requested) applyTheme(data.theme);
    }
    // A failed theme read is never worth a visible error: the workspace
    // fallback is a correct palette, just not the freshest one.
  }

  void applyTheme(ThemeTokens theme) {
    final current = state;
    if (current == null || current.theme == theme) return;
    emit(current.copyWith(theme: theme));
  }

  void clear() => emit(null);
}
