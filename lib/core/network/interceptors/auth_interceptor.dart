import 'package:dio/dio.dart';

import '../auth_context.dart';

/// One header convention, app-wide: `Authorization: Bearer <jwt>`.
/// The server also accepts a raw `jwt:` header — we never send both.
class AuthInterceptor extends Interceptor {
  final AuthContext context;

  AuthInterceptor(this.context);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final jwt = context.jwt;
    if (jwt != null && jwt.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $jwt';
    }

    options.headers['Accept'] = 'application/json';
    options.headers['Accept-Language'] = context.locale;

    // Only v2 knows about organizations; sending it on v1 is noise.
    final orgId = context.organizationId;
    if (orgId != null && _isV2(options.path)) {
      options.headers['X-Organization-Id'] = orgId;
    }

    handler.next(options);
  }

  static bool _isV2(String path) => path.contains('/v2/') || path.endsWith('/v2');
}
