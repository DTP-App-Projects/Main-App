import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_result.dart';
import 'auth_context.dart';
import 'env.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/device_id_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'response_normalizer.dart';

/// Turns a decoded body into a model. Kept as `dynamic` because this API
/// returns keyed objects, raw paginators and bare arrays from the same client.
typedef Parser<T> = T Function(dynamic body);

/// Shows the terms screen for a `409 terms_acceptance_required` and completes
/// with `true` once the user accepted — the blocked write is then replayed.
typedef TermsGate = Future<bool> Function(Failed<Object?> rejection);

/// The single door to the network. Widgets never touch it; repositories do.
class ApiClient {
  final Dio dio;

  /// Called once when any call comes back [SessionExpired], so the session
  /// layer can drop the token and route to login.
  void Function()? onSessionExpired;

  /// Called when a **write** comes back `409 terms_acceptance_required`.
  /// Reads are never gated server-side, so they never reach this.
  TermsGate? onTermsRequired;

  /// One terms screen for any number of writes blocked at once.
  Future<bool>? _pendingTerms;

  static const termsRequiredCode = 'terms_acceptance_required';

  /// In-flight `GET` de-duplication. Two widgets asking for the same URL on
  /// the same frame make one request — the global limit is 60/min per IP.
  final Map<String, Future<ApiResult<Object?>>> _inFlight = {};

  ApiClient(this.dio);

  factory ApiClient.create(AuthContext context) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBase,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
        // We branch on the body, not on exceptions.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.interceptors.add(AuthInterceptor(context));
    dio.interceptors.add(DeviceIdInterceptor());
    if (kDebugMode) dio.interceptors.add(LoggingInterceptor());
    return ApiClient(dio);
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Parser<T>? parse,
    CancelToken? cancelToken,
    bool dedupe = true,
  }) {
    if (!dedupe) {
      return _send<T>((_) => dio.get(path, queryParameters: query, cancelToken: cancelToken), parse,
          write: false);
    }
    final key = '$T GET $path ${_stableQuery(query)}';
    final existing = _inFlight[key];
    if (existing != null) return existing.then((r) => r as ApiResult<T>);

    final future = _send<T>(
      (_) => dio.get(path, queryParameters: query, cancelToken: cancelToken),
      parse,
      write: false,
    ).whenComplete(() {
      // Statement body, not an arrow: `Map.remove` returns the very future
      // being awaited, and `whenComplete` waits on a returned future — an
      // arrow here deadlocks every de-duplicated GET.
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  /// A binary download (PDF, ZIP) through the same interceptors as every
  /// other call, so it carries the session, the organization and the device
  /// id. An error body is JSON even here, and is normalized like any other.
  Future<ApiResult<Uint8List>> bytes(String path, {Map<String, dynamic>? query}) => _send<Uint8List>(
        (_) async {
          final response = await dio.get<List<int>>(
            path,
            queryParameters: query,
            options: Options(responseType: ResponseType.bytes, headers: {'Accept': '*/*'}),
          );
          final raw = Uint8List.fromList(response.data ?? const []);
          final type = response.headers.value(Headers.contentTypeHeader) ?? '';
          final ok = (response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300;
          if (ok && !type.contains('json')) {
            // Hand the bytes through untouched; `parse` below is identity.
            return Response<dynamic>(
              requestOptions: response.requestOptions,
              statusCode: response.statusCode,
              headers: response.headers,
              data: _Binary(raw),
            );
          }
          dynamic decoded;
          try {
            decoded = jsonDecode(utf8.decode(raw));
          } catch (_) {
            decoded = null;
          }
          return Response<dynamic>(
            requestOptions: response.requestOptions,
            statusCode: response.statusCode,
            headers: response.headers,
            data: decoded,
          );
        },
        (body) => body is _Binary ? body.bytes : throw const FormatException('expected a file'),
        write: false,
      );

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
    CancelToken? cancelToken,
  }) =>
      _send<T>(
        (_) => dio.post(path, data: body, queryParameters: query, cancelToken: cancelToken),
        parse,
      );

  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
  }) =>
      _send<T>((_) => dio.patch(path, data: body, queryParameters: query), parse);

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
  }) =>
      _send<T>((_) => dio.put(path, data: body, queryParameters: query), parse);

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
  }) =>
      _send<T>((_) => dio.delete(path, data: body, queryParameters: query), parse);

  /// Multipart always goes over `POST` — PHP only parses multipart bodies there.
  Future<ApiResult<T>> multipart<T>(
    String path, {
    required FormData form,
    Parser<T>? parse,
    ProgressCallback? onSendProgress,
  }) =>
      _send<T>(
        // A FormData is consumed by the first send; a replay after the terms
        // gate needs a fresh copy.
        (attempt) => dio.post(
          path,
          data: attempt == 0 ? form : form.clone(),
          onSendProgress: onSendProgress,
          options: Options(contentType: 'multipart/form-data'),
        ),
        parse,
      );

  Future<ApiResult<T>> _send<T>(
    Future<Response<dynamic>> Function(int attempt) run,
    Parser<T>? parse, {
    bool write = true,
  }) async {
    var result = await _attempt<T>(() => run(0), parse);

    // The terms gate: accept, then replay the write once. A second 409 (the
    // user dismissed the screen, or a newer version went live meanwhile) is
    // returned as-is so the caller shows its message.
    final gate = onTermsRequired;
    if (write &&
        gate != null &&
        result is Failed<T> &&
        result.status == 409 &&
        result.code == termsRequiredCode) {
      final accepted = await _awaitTerms(gate, result.castFailure<Object?>() as Failed<Object?>);
      if (accepted) result = await _attempt<T>(() => run(1), parse);
    }

    if (result is SessionExpired<T>) onSessionExpired?.call();
    return result;
  }

  Future<bool> _awaitTerms(TermsGate gate, Failed<Object?> rejection) {
    final pending = _pendingTerms;
    if (pending != null) return pending;
    final future = gate(rejection).catchError((_) => false).whenComplete(() {
      _pendingTerms = null;
    });
    _pendingTerms = future;
    return future;
  }

  Future<ApiResult<T>> _attempt<T>(
    Future<Response<dynamic>> Function() run,
    Parser<T>? parse,
  ) async {
    ApiResult<T> result;
    try {
      final response = await run();
      result = ResponseNormalizer.normalize<T>(
        status: response.statusCode,
        body: response.data,
        headers: response.headers,
        parse: parse,
        locale: _localeOf(response.requestOptions),
      );
    } on DioException catch (e) {
      if (_isOffline(e)) {
        result = Offline<T>();
      } else if (e.type == DioExceptionType.cancel) {
        result = Failed<T>('request_canceled', 0);
      } else if (e.response != null) {
        // 5xx lands here because validateStatus stops at 500.
        result = ResponseNormalizer.normalize<T>(
          status: e.response?.statusCode,
          body: e.response?.data,
          headers: e.response?.headers,
          parse: parse,
          locale: _localeOf(e.requestOptions),
        );
      } else {
        result = Failed<T>('unexpected_error', 0);
      }
    } catch (_) {
      result = Failed<T>('unexpected_error', 0);
    }
    return result;
  }

  /// The language the request asked for (set by the auth interceptor).
  static String? _localeOf(RequestOptions options) {
    final value = options.headers['Accept-Language'];
    return value == null ? null : '$value';
  }

  static bool _isOffline(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        return e.error is SocketException || '${e.error}'.contains('SocketException');
      default:
        return false;
    }
  }

  static String _stableQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys.map((k) => '$k=${query[k]}').join('&');
  }
}

/// Marks a binary body so the normalizer's `Map` checks pass it through.
class _Binary {
  final Uint8List bytes;
  const _Binary(this.bytes);
}
