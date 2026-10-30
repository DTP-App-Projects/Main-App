import 'package:dio/dio.dart';

import '../device_identity.dart';

/// `X-Device-Id` on **every** request, v1 and v2 alike — the server records it
/// with each acceptance as the device fingerprint.
class DeviceIdInterceptor extends Interceptor {
  final String? Function() _read;

  DeviceIdInterceptor({String? Function()? read}) : _read = read ?? (() => DeviceIdentity.id);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _read();
    if (id != null && id.isNotEmpty) options.headers['X-Device-Id'] = id;
    handler.next(options);
  }
}
