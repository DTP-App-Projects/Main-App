import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_result.dart';

/// Turns a raw response into an [ApiResult], following the decision order the
/// integration brief fixes. The order matters: several of these are `200`s or
/// `400`s that mean something other than what the status says.
class ResponseNormalizer {
  ResponseNormalizer._();

  static const String validationError = 'validation_error';

  /// The typed endpoints (van sales) validate as `422 {msg: validation_failed,
  /// errors: {field: [...]}}` — Laravel's own shape, under another key.
  static const String validationFailed = 'validation_failed';
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

    /// The request's `Accept-Language`: picks `message_ar` / `message_en`
    /// on the endpoints that send both instead of one `message`.
    String? locale,
  }) {
    // 2. Rate limited. `resend_too_soon` says how long in the body; the
    //    limiter's own 429 may say it in a header, or not at all (and its
    //    body may be HTML).
    if (status == 429) {
      final seconds = body is Map ? int.tryParse('${body['retry_after'] ?? ''}') : null;
      return RateLimited<T>(
        seconds != null && seconds > 0
            ? Duration(seconds: seconds.clamp(1, 3600))
            : _retryAfter(headers),
      );
    }

    // 3. Dead / missing token, in either of its two shapes.
    if (isAuthFailure(status, body)) {
      return SessionExpired<T>();
    }

    final map = body is Map ? body.cast<String, dynamic>() : null;
    final code = _codeOf(map);

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
      final text = map?['text'] ?? map?['message'];
      return Invalid<T>(
        _bag(map?['bag']),
        text: text is String && text.trim().isNotEmpty ? text.trim() : null,
      );
    }

    if (status == 422 && code == validationFailed) {
      return Invalid<T>(_bag(map?['errors']), text: _message(map, locale));
    }

    final ok = status != null && status >= 200 && status < 300;

    // 7. Any other coded failure — compliance rules (422), the terms gate
    //    (409), `404 wallet_disabled`, the blocked consumer checkout (403).
    if (!ok) {
      return Failed<T>(
        code.isEmpty ? 'unexpected_error' : code,
        status ?? 0,
        message: _message(map, locale),
        details: map,
      );
    }

    // 8. Business failures that arrive as 200. Do not skip these.
    if (map != null) {
      if (map['status'] == 'failed') {
        final reason = map['msg'];
        return Failed<T>(
          reason is String && reason.isNotEmpty ? reason : 'request_failed',
          200,
          message: _message(map, locale),
          details: map,
        );
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

  static final _codeShape = RegExp(r'^[a-z][a-z0-9_]*$');

  /// The stable code. Usually `msg`; but the email-verification endpoints put
  /// a *translated sentence* in `msg` and the code in `error`
  /// (`{"msg": "الرمز غير صحيح…", "error": "invalid_code"}`).
  static String _codeOf(Map<String, dynamic>? map) {
    final msg = map?['msg'];
    if (msg is String && _codeShape.hasMatch(msg)) return msg;
    final error = map?['error'];
    if (error is String && _codeShape.hasMatch(error)) return error;
    if (msg is String) return msg;
    // The edit-window endpoints answer `{status, message: <code>}` with no
    // `msg` at all (`{"status":404,"message":"delivery_note_not_found"}`).
    final message = map?['message'];
    return message is String && _codeShape.hasMatch(message) ? message : '';
  }

  /// Laravel's own exceptions also use `message` (e.g. "The GET method is not
  /// supported…") but never alongside a `msg` code, so only a coded body's
  /// `message` is taken as user-facing text. A `msg` that is itself a
  /// sentence (see [_codeOf]) is the message.
  ///
  /// Newer refusals (`van_*_refused`, `fleet_contract_refused`) carry both
  /// languages as `message_ar` / `message_en`; the request's own language
  /// wins, then the other one.
  static String? _message(Map<String, dynamic>? map, [String? locale]) {
    if (map == null || map['msg'] is! String) return null;
    final lang = (locale ?? 'ar').toLowerCase().startsWith('en') ? 'en' : 'ar';
    for (final key in ['message_$lang', 'message_${lang == 'en' ? 'ar' : 'en'}']) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final raw = map['message'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    // Only in the `{msg: sentence, error: code}` shape — an older non-code
    // `msg` (`suspended user`) keeps falling back to the app's own copy.
    final msg = (map['msg'] as String).trim();
    final error = map['error'];
    final sentenceWithCode = error is String && _codeShape.hasMatch(error) && !_codeShape.hasMatch(msg);
    return sentenceWithCode && msg.isNotEmpty ? msg : null;
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
