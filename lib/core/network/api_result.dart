/// The only thing a repository is allowed to hand back. Repositories never
/// throw across the boundary and never leak a `DioException`.
sealed class ApiResult<T> {
  const ApiResult();

  bool get isOk => this is Ok<T>;

  T? get dataOrNull => this is Ok<T> ? (this as Ok<T>).data : null;

  R when<R>({
    required R Function(T data) ok,
    required R Function() noContent,
    required R Function(Map<String, List<String>> bag) invalid,
    required R Function(String code, int status, String? permission) failed,
    required R Function() wrongWorkspace,
    required R Function() offline,
    required R Function(Duration retryAfter) rateLimited,
    required R Function() sessionExpired,
  }) {
    final self = this;
    return switch (self) {
      Ok<T>() => ok(self.data),
      NoContent<T>() => noContent(),
      Invalid<T>() => invalid(self.bag),
      Failed<T>() => failed(self.code, self.status, self.permission),
      WrongWorkspace<T>() => wrongWorkspace(),
      Offline<T>() => offline(),
      RateLimited<T>() => rateLimited(self.retryAfter),
      SessionExpired<T>() => sessionExpired(),
    };
  }

  /// Re-labels a non-`Ok` result for a different payload type, so a repository
  /// can map one call's failure onto its own return type without re-checking
  /// every case.
  ApiResult<R> castFailure<R>() {
    final self = this;
    return switch (self) {
      Ok<T>() => throw StateError('castFailure() called on Ok'),
      NoContent<T>() => NoContent<R>(),
      Invalid<T>() => Invalid<R>(self.bag),
      Failed<T>() => Failed<R>(
          self.code,
          self.status,
          permission: self.permission,
          message: self.message,
          details: self.details,
        ),
      WrongWorkspace<T>() => WrongWorkspace<R>(),
      Offline<T>() => Offline<R>(),
      RateLimited<T>() => RateLimited<R>(self.retryAfter),
      SessionExpired<T>() => SessionExpired<R>(),
    };
  }
}

class Ok<T> extends ApiResult<T> {
  final T data;
  const Ok(this.data);
}

/// `204`, or a `200` with an empty body — both are used for successful
/// mutations. Do not try to decode either.
class NoContent<T> extends ApiResult<T> {
  const NoContent();
}

/// `400 {"msg":"validation_error","bag":{...}}`. A `422` is a business rule,
/// not validation — it arrives as [Failed].
/// Key off the field names, never the message text.
class Invalid<T> extends ApiResult<T> {
  final Map<String, List<String>> bag;

  /// The server's own sentence for the whole request, when it sends one —
  /// `profile/submit` explains itself in `text` with an empty bag.
  final String? text;

  const Invalid(this.bag, {this.text});

  /// What to show above the form: the server's `text`, else the first
  /// message in the bag, else null (the caller falls back to a generic one).
  String? get summary {
    if (text != null && text!.isNotEmpty) return text;
    for (final messages in bag.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }

  String? first(String field) {
    final messages = bag[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }
}

/// A business-rule rejection: a stable snake_case `msg`. Branch on [code],
/// never on [message] — and never show [code] to a user.
class Failed<T> extends ApiResult<T> {
  final String code;
  final int status;

  /// Set when `msg == 'permission_denied'`.
  final String? permission;

  /// The server's own localized sentence (`message`), sent with compliance
  /// rejections (`422 <code>`, `409 terms_acceptance_required`, …). Shown to
  /// the user when we ship no copy of our own for [code].
  final String? message;

  /// The whole error body, for codes that carry context next to `msg` —
  /// `terms: {...}` on the terms gate, limits on a credit rejection.
  final Map<String, dynamic>? details;

  const Failed(this.code, this.status, {this.permission, this.message, this.details});
}

/// `403 organization_workspace_not_allowed` — a navigation bug on our side,
/// not something the user did. Loud in debug, generic in release.
class WrongWorkspace<T> extends ApiResult<T> {
  const WrongWorkspace();
}

class Offline<T> extends ApiResult<T> {
  const Offline();
}

class RateLimited<T> extends ApiResult<T> {
  final Duration retryAfter;
  const RateLimited(this.retryAfter);
}

/// The token is gone or was rotated. Clear it and route to login.
class SessionExpired<T> extends ApiResult<T> {
  const SessionExpired();
}
