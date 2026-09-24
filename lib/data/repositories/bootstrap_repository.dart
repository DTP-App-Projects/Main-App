import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/utils/services/local_services/cache_helper.dart';
import '../../core/utils/services/local_services/cache_keys.dart';
import '../api_paths.dart';
import '../models/bootstrap/bootstrap.dart';
import '../models/bootstrap/flags.dart';

class BootstrapRepository {
  final ApiClient _client;

  BootstrapRepository(this._client);

  /// `GET /api/v2/bootstrap`. The shape of the whole shell.
  ///
  /// A successful response is cached verbatim so a cold start without
  /// connectivity still renders the right shell.
  Future<ApiResult<Bootstrap>> fetch() async {
    Map<String, dynamic>? raw;
    final result = await _client.get<Bootstrap>(
      ApiPaths.bootstrap,
      parse: (body) {
        raw = asMap(body);
        return Bootstrap.fromJson(raw!);
      },
    );
    final snapshot = raw;
    if (result.isOk && snapshot != null) await cache(snapshot);
    return result;
  }

  /// Callable before an organization context exists — useful on the login
  /// screen to decide whether to offer Nafath at all.
  Future<ApiResult<PlatformFlagsResponse>> platformFlags() =>
      _client.get<PlatformFlagsResponse>(
        ApiPaths.platformFlags,
        parse: (body) => PlatformFlagsResponse.fromJson(asMap(body)),
      );

  /// v2 `push_tokens` is a different table from v1 `tokens` — both are used,
  /// so both registrations run.
  Future<ApiResult<void>> registerPushToken({
    required String token,
    required String appVariant,
    required String locale,
  }) =>
      _client.post<void>(
        ApiPaths.pushRegister,
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app_variant': appVariant,
          'locale': locale,
        },
      );

  /// Drops this device from `push_tokens` so a logged-out phone stops
  /// receiving the organization's events.
  Future<ApiResult<void>> unregisterPushToken(String token) =>
      _client.post<void>(ApiPaths.pushUnregister, body: {'token': token});

  // ------------------------------------------------------------------ cache

  /// Bootstrap is cached so a cold start with no connectivity can still render
  /// the right shell, flagged as stale.
  Future<void> cache(Map<String, dynamic> raw) async {
    try {
      await CacheHelper.saveData(key: CacheKeys.bootstrapCache, value: jsonEncode(raw));
    } catch (e) {
      debugPrint('bootstrap cache write failed: $e');
    }
  }

  Bootstrap? readCached() {
    final raw = CacheHelper.getData(key: CacheKeys.bootstrapCache);
    if (raw is! String || raw.isEmpty) return null;
    try {
      return Bootstrap.fromJson(asMap(jsonDecode(raw)));
    } catch (e) {
      debugPrint('bootstrap cache read failed: $e');
      return null;
    }
  }
}
