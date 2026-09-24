import 'package:flutter/foundation.dart';

import '../../data/models/bootstrap/bootstrap.dart';
import '../../data/models/bootstrap/organization.dart';

enum SessionStatus {
  /// Before [SessionCubit.start] has finished — the splash is showing.
  unknown,
  loading,
  unauthenticated,
  authenticated,

  /// Bootstrap failed for a reason that is not "logged out".
  error,
}

@immutable
class SessionState {
  final SessionStatus status;
  final Bootstrap? bootstrap;
  final Organization? organization;

  /// A stable snake_case code, never shown raw — see `errorMessageFor`.
  final String? errorCode;

  /// Rendered from the cached bootstrap because the network was unreachable.
  final bool isStale;

  const SessionState({
    this.status = SessionStatus.unknown,
    this.bootstrap,
    this.organization,
    this.errorCode,
    this.isStale = false,
  });

  bool get isAuthenticated => status == SessionStatus.authenticated;

  /// The org exists but has not finished review — the onboarding wizard owns
  /// the user until it does.
  bool get needsOnboarding =>
      isAuthenticated && (organization == null || organization!.needsOnboarding);

  SessionState copyWith({
    SessionStatus? status,
    Bootstrap? bootstrap,
    Organization? organization,
    String? errorCode,
    bool? isStale,
    bool clearError = false,
  }) =>
      SessionState(
        status: status ?? this.status,
        bootstrap: bootstrap ?? this.bootstrap,
        organization: organization ?? this.organization,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        isStale: isStale ?? this.isStale,
      );
}
