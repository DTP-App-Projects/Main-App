import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request/response log with the secrets taken out.
///
/// Every response is printed in full, pretty-printed, one line at a time:
/// Android's logcat cuts a single line at ~1000 characters, so one long
/// `debugPrint` of a big body arrives chopped.
class LoggingInterceptor extends Interceptor {
  static const _redacted = <String>{
    'password',
    'new_password',
    'old_password',
    'password_confirmation',
    'jwt',
    'token',
    'fcm_token',
    'signature',
    'public_key',
    'authorization',
  };

  /// Well under logcat's per-line limit.
  static const _chunk = 800;

  static const _startedAt = 'log_started_at';

  static const _pretty = JsonEncoder.withIndent('  ');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[_startedAt] = DateTime.now().millisecondsSinceEpoch;
      _print('→ ${options.method} ${options.uri}');
      _print('  headers: ${jsonEncode(_scrub(Map<String, dynamic>.from(options.headers)))}');
      if (options.data != null) _print('  body: ${_body(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final options = response.requestOptions;
      _print('← ${response.statusCode} ${options.method} ${options.uri}${_took(options)}');
      _print(_body(response.data));
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final options = err.requestOptions;
      final status = err.response?.statusCode;
      _print('✖ ${status ?? err.type.name} ${options.method} ${options.uri}${_took(options)}');
      if (err.response != null) {
        _print(_body(err.response?.data));
      } else if (err.message != null) {
        _print('  ${err.message}');
      }
    }
    handler.next(err);
  }

  String _took(RequestOptions options) {
    final started = options.extra[_startedAt];
    if (started is! int) return '';
    return ' (${DateTime.now().millisecondsSinceEpoch - started} ms)';
  }

  String _body(dynamic data) {
    if (data == null) return '<empty>';
    if (data is FormData) {
      final fields = _scrub({for (final f in data.fields) f.key: f.value});
      final files = data.files.map((f) => '${f.key}=<file ${f.value.filename}>').join(', ');
      return '${jsonEncode(fields)}${files.isEmpty ? '' : ' $files'}';
    }
    if (data is Map || data is List) return _pretty.convert(_scrubAny(data));
    if (data is String) {
      // A JSON body dio did not decode (wrong content type) — still pretty.
      try {
        return _pretty.convert(_scrubAny(jsonDecode(data)));
      } catch (_) {
        return data;
      }
    }
    if (data is List<int>) return '<${data.length} bytes>';
    return '$data';
  }

  /// Line by line, long lines in chunks, so nothing is lost.
  void _print(String text) {
    for (final line in const LineSplitter().convert(text)) {
      if (line.length <= _chunk) {
        debugPrint(line);
        continue;
      }
      for (var i = 0; i < line.length; i += _chunk) {
        debugPrint(line.substring(i, i + _chunk > line.length ? line.length : i + _chunk));
      }
    }
  }

  dynamic _scrubAny(dynamic value) {
    if (value is Map) return _scrub(value.cast<String, dynamic>());
    if (value is List) return value.map(_scrubAny).toList();
    return value;
  }

  Map<String, dynamic> _scrub(Map<String, dynamic> input) {
    return input.map((k, v) {
      if (_redacted.contains(k.toLowerCase())) return MapEntry(k, '***');
      return MapEntry(k, _scrubAny(v));
    });
  }
}
