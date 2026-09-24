/// What the network layer needs to know about "who we are right now".
///
/// Implemented by the session store; declared here so the Dio interceptors
/// never import the session or workspace layers.
abstract class AuthContext {
  /// The 200-char `users.jwt`. Never expires, never refreshes.
  String? get jwt;

  /// Sent as `X-Organization-Id` on `/v2` paths only. Omitting it makes the
  /// server fall back to the user's `primary_organization_id`, which is wrong
  /// as soon as the user can switch orgs.
  int? get organizationId;

  /// `ar` | `en`. Drives every localized field the server returns, plus the
  /// text of validation messages. Missing → the server serves `ar`.
  String get locale;
}
