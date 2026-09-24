import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_result.dart';

/// Turns a raw response into an [ApiResult], following the decision order the
/// integration brief fixes. The order matters: several of these are `200`s or
/// `400`s that mean something other than what the status says.
class ResponseNormalizer {
  ResponseNormalizer._();

  static const String validationError = 'validation_error';
  static const String permissionDenied = 'permission_denied';
  static const String wrongWorkspaceCode = 'organization_workspace_not_allowed';
  static const String nafathDisabled = 'nafath_disabled';

  /// There is no auth middleware on this backend — each controller validates
  /// `user_id` against `users.jwt`, so a dead token surfaces as a *validation*
  /// failure naming `user_id`, not a `401`.
  static bool isAuthFailure(int? status, dynamic body) =>
      status == 401 ||
      (status == 400 &&
          body is Map &&
          body['msg'] == validationError &&
          (body['bag'] as Map?)?.containsKey('user_id') == true);

  static ApiResult<T> normalize<T>({
    required int? status,
    required dynamic body,
    required Headers? headers,
    required T Function(dynamic body)? parse,
  }) {
    // 2. Rate limited.
    if (status == 429) {
      return RateLimited<T>(_retryAfter(headers));
    }

    // 3. Dead / missing token, in either of its two shapes.
    if (isAuthFailure(status, body)) {
      return SessionExpired<T>();
    }

    final map = body is Map ? body.cast<String, dynamic>() : null;
    final msg = map?['msg'];
    final code = msg is String ? msg : '';

    if (status == 403) {
      // 4. Our navigation sent a trader-only call from a supplier org (or vice
      //    versa). Never a user-facing condition.
      if (code == wrongWorkspaceCode) {
        assert(() {
          debugPrint(
            'WRONG WORKSPACE: the server refused this call for the active '
            'workspace. This is a navigation bug — fix the route, do not '
            'surface it to the user.',
          );
          return true;
        }());
        return WrongWorkspace<T>();
      }
      // 5. Membership lacks the permission.
      if (code == permissionDenied) {
        final permission = map?['permission'];
        return Failed<T>(code, 403,
            permission: permission == null ? null : '$permission');
      }
    }

    // 6. Laravel validation. This is the 422 you were expecting.
    if (status == 400 && code == validationError) {
      return Invalid<T>(_bag(map?['bag']));
    }

    final ok = status != null && status >= 200 && status < 300;

    // 7. Any other coded failure.
    if (!ok) {
      return Failed<T>(code.isEmpty ? 'unexpected_error' : code, status ?? 0);
    }

    // 8. Business failures that arrive as 200. Do not skip these.
    if (map != null) {
      if (map['status'] == 'failed') {
        final reason = map['msg'];
        return Failed<T>(reason is String && reason.isNotEmpty ? reason : 'request_failed', 200);
      }
      if (code == nafathDisabled) {
        return Failed<T>(nafathDisabled, 200);
      }
    }

    // 9. Successful mutation with nothing to decode.
    if (status == 204 || body == null || (body is String && body.trim().isEmpty)) {
      return NoContent<T>();
    }

    // 10. A real payload.
    if (parse == null) return NoContent<T>();
    try {
      return Ok<T>(parse(body));
    } catch (e, s) {
      assert(() {
        debugPrint('Failed to parse a 2xx body: $e\n$s');
        return true;
      }());
      // `status` is promoted non-null here: a null status never reaches
      // step 10, it is caught by the non-2xx branch above.
      return Failed<T>('parse_error', status);
    }
  }

  static Map<String, List<String>> _bag(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    raw.forEach((key, value) {
      final field = '$key';
      if (value is List) {
        out[field] = value.map((e) => '$e').toList();
      } else if (value != null) {
        out[field] = ['$value'];
      }
    });
    return out;
  }

  /// `Retry-After` is either a number of seconds or an HTTP date.
  static Duration _retryAfter(Headers? headers) {
    const fallback = Duration(seconds: 60);
    final raw = headers?.value('retry-after');
    if (raw == null || raw.isEmpty) return fallback;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null) return Duration(seconds: seconds.clamp(1, 3600));
    final until = DateTime.tryParse(raw);
    if (until == null) return fallback;
    final delta = until.difference(DateTime.now());
    return delta.isNegative ? const Duration(seconds: 1) : delta;
  }
}
