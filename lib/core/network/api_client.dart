import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_result.dart';
import 'auth_context.dart';
import 'env.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'response_normalizer.dart';

/// Turns a decoded body into a model. Kept as `dynamic` because this API
/// returns keyed objects, raw paginators and bare arrays from the same client.
typedef Parser<T> = T Function(dynamic body);

/// The single door to the network. Widgets never touch it; repositories do.
class ApiClient {
  final Dio dio;

  /// Called once when any call comes back [SessionExpired], so the session
  /// layer can drop the token and route to login.
  void Function()? onSessionExpired;

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
      return _send<T>(() => dio.get(path, queryParameters: query, cancelToken: cancelToken), parse);
    }
    final key = '$T GET $path ${_stableQuery(query)}';
    final existing = _inFlight[key];
    if (existing != null) return existing.then((r) => r as ApiResult<T>);

    final future = _send<T>(
      () => dio.get(path, queryParameters: query, cancelToken: cancelToken),
      parse,
    ).whenComplete(() {
      // Statement body, not an arrow: `Map.remove` returns the very future
      // being awaited, and `whenComplete` waits on a returned future — an
      // arrow here deadlocks every de-duplicated GET.
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
    CancelToken? cancelToken,
  }) =>
      _send<T>(
        () => dio.post(path, data: body, queryParameters: query, cancelToken: cancelToken),
        parse,
      );

  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
  }) =>
      _send<T>(() => dio.patch(path, data: body, queryParameters: query), parse);

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
  }) =>
      _send<T>(() => dio.put(path, data: body, queryParameters: query), parse);

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Parser<T>? parse,
  }) =>
      _send<T>(() => dio.delete(path, data: body, queryParameters: query), parse);

  /// Multipart always goes over `POST` — PHP only parses multipart bodies there.
  Future<ApiResult<T>> multipart<T>(
    String path, {
    required FormData form,
    Parser<T>? parse,
    ProgressCallback? onSendProgress,
  }) =>
      _send<T>(
        () => dio.post(
          path,
          data: form,
          onSendProgress: onSendProgress,
          options: Options(contentType: 'multipart/form-data'),
        ),
        parse,
      );

  Future<ApiResult<T>> _send<T>(
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
        );
      } else {
        result = Failed<T>('unexpected_error', 0);
      }
    } catch (_) {
      result = Failed<T>('unexpected_error', 0);
    }

    if (result is SessionExpired<T>) onSessionExpired?.call();
    return result;
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
