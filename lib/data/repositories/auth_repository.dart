import 'dart:io' show Platform;

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/utils/services/local_services/cache_keys.dart';
import '../api_paths.dart';
import '../models/auth/auth_user.dart';
import '../models/common/country.dart';

/// v1 auth. Repositories never throw and never leak Dio types.
class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  /// `POST /api/auth/login`.
  ///
  /// Three failure shapes to keep straight: `400 validation_error` with a bag,
  /// `401 invalid_email` / `invalid_password`, and a **`200`** carrying
  /// `{"status":"failed","msg":"suspended user"}` — the normalizer turns the
  /// last one into [Failed] so it cannot be mistaken for success here.
  Future<ApiResult<AuthUser>> login({
    required String email,
    required String password,
    required String fcmToken,
  }) =>
      _client.post<AuthUser>(
        ApiPaths.login,
        body: {
          'email': email,
          'password': password,
          'fcm_token': fcmToken,
          ..._deviceMetadata(),
        },
        parse: (body) => AuthUser.fromJson(asMap(asMap(body)['user'])),
      );

  /// `POST /api/v2/onboarding/register_owner` — the B2B sign-up. Creates the
  /// user and the organization together and returns the session.
  Future<ApiResult<RegisterOwnerResult>> registerOwner({
    required String businessMode,
    required String firstName,
    required String lastName,
    required String organizationName,
    required String email,
    required String password,
    required String fcmToken,
    required int countryId,
    required int cityId,
    String? phone,
    String? whatsapp,
    String? address,
    List<int> sectorIds = const [],
  }) =>
      _client.post<RegisterOwnerResult>(
        ApiPaths.registerOwner,
        body: {
          'business_mode': businessMode,
          'first_name': firstName,
          'last_name': lastName,
          'organization_name': organizationName,
          'email': email,
          'password': password,
          'token': fcmToken,
          'country_id': countryId,
          'city_id': cityId,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (whatsapp != null && whatsapp.isNotEmpty) 'whatsapp': whatsapp,
          if (address != null && address.isNotEmpty) 'address': address,
          if (sectorIds.isNotEmpty) 'sector_ids': sectorIds,
          ..._deviceMetadata(),
        },
        parse: (body) => RegisterOwnerResult.fromJson(asMap(body)),
      );

  /// Step 1 of 3. E-mails a 6-digit code valid for an hour. `throttle:6,1`.
  Future<ApiResult<void>> forgotPassword(String email) =>
      _client.post<void>(ApiPaths.forgotPassword, body: {'email': email});

  /// Step 2 of 3. Returns a session `jwt` that **must** be used for step 3.
  Future<ApiResult<AuthUser>> verifyResetCode(String code) => _client.post<AuthUser>(
        ApiPaths.verifyResetCode,
        body: {'code': code},
        parse: (body) => AuthUser.fromJson(asMap(asMap(body)['user'])),
      );

  /// Step 3 of 3. Requires the `jwt` from step 2 to be the active session.
  Future<ApiResult<void>> resetPassword(String password) =>
      _client.post<void>(ApiPaths.resetPassword, body: {'password': password});

  /// Idempotent upsert into the v1 `tokens` table. Cold start + FCM refresh.
  Future<ApiResult<void>> updateDeviceToken({
    required String fcmToken,
    required String appVariant,
  }) =>
      _client.put<void>(
        ApiPaths.deviceToken,
        body: {
          'fcm_token': fcmToken,
          'app_variant': appVariant,
          ..._deviceMetadata(),
        },
      );

  /// Public. The sign-up country/city pickers have no other source.
  Future<ApiResult<List<Country>>> countries() => _client.get<List<Country>>(
        ApiPaths.countries,
        parse: (body) => asList(body, Country.fromJson),
      );

  Map<String, dynamic> _deviceMetadata() => {
        'platform': _platform,
        'locale': CacheKeysManger.getUserLanguage(),
      };

  static String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }
}
