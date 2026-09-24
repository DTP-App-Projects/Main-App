import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/auth/auth_user.dart';
import '../../data/models/bootstrap/organization.dart';
import '../../data/repositories/bootstrap_repository.dart';
import '../push/push_service.dart';
import '../workspace/workspace_cubit.dart';
import 'session_state.dart';
import 'session_store.dart';

/// Owns "am I logged in, as which organization" and nothing else. The router
/// redirects off this; screens read it for the user/org header.
class SessionCubit extends Cubit<SessionState> {
  final SessionStore _store;
  final BootstrapRepository _bootstrapRepo;
  final WorkspaceCubit _workspace;
  final PushService _push;

  /// Fired when an organization becomes the active one — the moment anything
  /// organization-scoped should (re)load.
  void Function()? onOrganizationResolved;

  /// Fired when the session or the organization goes away.
  void Function()? onContextCleared;

  SessionCubit(this._store, this._bootstrapRepo, this._workspace, this._push)
      : super(const SessionState());

  /// Cold start: restore the token, then bootstrap. No token → login.
  Future<void> start() async {
    await _store.restore();
    if (!_store.hasSession) {
      emit(const SessionState(status: SessionStatus.unauthenticated));
      return;
    }
    await refresh();
  }

  /// After a successful login / sign-up.
  Future<void> onAuthenticated(AuthUser user, {int? organizationId}) async {
    await _store.saveSession(jwt: user.jwt, userId: user.id);
    if (organizationId != null) await _store.setOrganizationId(organizationId);
    await refresh();
  }

  /// Re-fetch bootstrap. Called on login, org switch and app resume — never on
  /// a workspace switch.
  Future<void> refresh() async {
    emit(state.copyWith(status: SessionStatus.loading, clearError: true));

    final result = await _bootstrapRepo.fetch();

    await result.when(
      ok: (bootstrap) async {
        final org = bootstrap.resolveOrganization(_store.organizationId);
        if (org != null) await _workspace.hydrate(org);
        emit(SessionState(
          status: SessionStatus.authenticated,
          bootstrap: bootstrap,
          organization: org,
        ));
        await _push.registerWithBackend(workspaceHint: org);
        onOrganizationResolved?.call();
      },
      noContent: () async => emit(state.copyWith(
        status: SessionStatus.error,
        errorCode: 'unexpected_error',
      )),
      invalid: (bag) async => emit(state.copyWith(
        status: SessionStatus.error,
        errorCode: 'validation_error',
      )),
      failed: (code, _, _) async =>
          emit(state.copyWith(status: SessionStatus.error, errorCode: code)),
      wrongWorkspace: () async =>
          emit(state.copyWith(status: SessionStatus.error, errorCode: 'unexpected_error')),
      offline: () async => _emitFromCache(),
      rateLimited: (_) async =>
          emit(state.copyWith(status: SessionStatus.error, errorCode: 'rate_limited')),
      sessionExpired: () async => logout(),
    );
  }

  /// Org switcher. Re-hydrates the workspace; does not touch the token.
  Future<void> switchOrganization(int organizationId) async {
    final bootstrap = state.bootstrap;
    if (bootstrap == null) return;
    Organization? target;
    for (final org in bootstrap.organizations) {
      if (org.id == organizationId) target = org;
    }
    if (target == null || target.id == state.organization?.id) return;

    onContextCleared?.call();
    await _store.setOrganizationId(target.id);
    await _workspace.hydrate(target);
    emit(state.copyWith(organization: target));
    // Permissions and journey are per-organization, so the shell needs fresh
    // data rather than the slice we already hold.
    await refresh();
  }

  /// The only recovery from a dead token — there is no refresh flow.
  ///
  /// Idempotent: the client also calls this through `onSessionExpired`, so a
  /// failing refresh must not unregister the device twice.
  Future<void> logout() async {
    if (!_store.hasSession && state.status == SessionStatus.unauthenticated) return;
    await _push.unregister();
    await _store.clear();
    _workspace.clear();
    onContextCleared?.call();
    emit(const SessionState(status: SessionStatus.unauthenticated));
  }

  /// Offline cold start: render the last known shell, flagged stale.
  void _emitFromCache() {
    final cached = _bootstrapRepo.readCached();
    if (cached == null) {
      emit(state.copyWith(status: SessionStatus.error, errorCode: 'offline'));
      return;
    }
    final org = cached.resolveOrganization(_store.organizationId);
    if (org != null) _workspace.hydrate(org);
    emit(SessionState(
      status: SessionStatus.authenticated,
      bootstrap: cached,
      organization: org,
      isStale: true,
    ));
  }
}
