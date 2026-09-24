import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request/response log with the secrets taken out.
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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('→ ${options.method} ${options.uri}');
      final headers = _scrub(Map<String, dynamic>.from(options.headers));
      debugPrint('  headers: $headers');
      if (options.data != null) debugPrint('  body: ${_body(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
      debugPrint('  ${_body(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('✖ ${err.type} ${err.requestOptions.uri}');
      if (err.response != null) {
        debugPrint('  ${err.response?.statusCode} ${_body(err.response?.data)}');
      }
    }
    handler.next(err);
  }

  String _body(dynamic data) {
    if (data is FormData) {
      final fields = _scrub({for (final f in data.fields) f.key: f.value});
      final files = data.files.map((f) => '${f.key}=<file ${f.value.filename}>').join(', ');
      return '$fields${files.isEmpty ? '' : ' $files'}';
    }
    if (data is Map) return jsonEncode(_scrub(data.cast<String, dynamic>()));
    final raw = '$data';
    return raw.length > 2000 ? '${raw.substring(0, 2000)}…' : raw;
  }

  Map<String, dynamic> _scrub(Map<String, dynamic> input) {
    return input.map((k, v) {
      if (_redacted.contains(k.toLowerCase())) return MapEntry(k, '***');
      if (v is Map) return MapEntry(k, _scrub(v.cast<String, dynamic>()));
      return MapEntry(k, v);
    });
  }
}
