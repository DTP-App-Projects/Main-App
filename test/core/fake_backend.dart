import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:digital_trade_portal/core/network/api_client.dart';
import 'package:digital_trade_portal/core/network/auth_context.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in for the real server so the plumbing can be proved against every
/// response shape this backend produces — including the ones that lie about
/// their status code.
class FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// Every request this adapter saw, so header behaviour can be asserted.
  final List<RequestOptions> requests = [];

  FakeAdapter(this.handler);

  /// Replies with [body] encoded as JSON.
  factory FakeAdapter.json(
    dynamic body, {
    int status = 200,
    Map<String, List<String>> headers = const {},
  }) =>
      FakeAdapter((_) async => ResponseBody.fromString(
            body == null ? '' : jsonEncode(body),
            status,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
              ...headers,
            },
          ));

  /// Replies with an empty body, as `204` mutations do.
  factory FakeAdapter.empty({int status = 204}) =>
      FakeAdapter((_) async => ResponseBody.fromString('', status));

  /// Fails the way a device with no connectivity does.
  factory FakeAdapter.offline() => FakeAdapter((options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class FakeAuthContext implements AuthContext {
  @override
  String? jwt;

  @override
  int? organizationId;

  @override
  String locale;

  FakeAuthContext({this.jwt = 'test-jwt', this.organizationId = 3, this.locale = 'ar'});
}

/// Builds the real client — real interceptors, real normalizer — over a fake
/// transport.
///
/// [context] takes any [AuthContext], not just the fake: passing a real
/// `SessionStore` is how a test proves which token actually reaches the
/// Authorization header.
(ApiClient, FakeAdapter) clientWith(FakeAdapter adapter, {AuthContext? context}) {
  final client = ApiClient.create(context ?? FakeAuthContext());
  client.dio.httpClientAdapter = adapter;
  return (client, adapter);
}

/// Gives a test both halves of the app's storage, so it can drive the real
/// [SessionStore] rather than a stand-in.
///
/// The JWT lives in `flutter_secure_storage` (a platform channel) and
/// everything else in `SharedPreferences`; without both mocked, anything that
/// calls `SessionStore.restore()` dies on an uninitialized binding.
Future<void> useFakeStorage({
  Map<String, String> secure = const {},
  Map<String, Object> prefs = const {},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues(Map.of(secure));
  SharedPreferences.setMockInitialValues(Map.of(prefs));
  await CacheHelper.init();
}

/// A JSON body, for a [FakeAdapter] whose handler routes on the request path.
ResponseBody jsonBody(dynamic body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
