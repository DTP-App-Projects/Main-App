import 'dart:io' show Platform;

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/utils/services/local_services/cache_keys.dart';
import '../api_paths.dart';
import '../models/compliance/terms.dart';
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
  }) => _client.post<AuthUser>(
    ApiPaths.login,
    body: {'email': email, 'password': password, 'fcm_token': fcmToken, ..._deviceMetadata()},
    parse: (body) {
      final map = asMap(body);
      final user = asMap(map['user']);
      // `email_verify_pending` may sit beside `user` instead of on it.
      return AuthUser.fromJson(
        EmailVerificationChallenge.matches(map)
            ? {...user, EmailVerificationChallenge.pendingFlag: true}
            : user,
      );
    },
  );

  /// `POST /api/v2/onboarding/register_owner` — the B2B sign-up. Creates the
  /// user and the organization together; with `verify_email=1` the answer is a
  /// [EmailVerificationChallenge], and the session comes from `/auth/email/verify`.
  /// An unconfirmed email signing up again gets the same challenge (no "taken").
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
    required String activityType,
    List<int> acceptedTermsVersionIds = const [],
  }) => _client.post<RegisterOwnerResult>(
    ApiPaths.registerOwner,
    body: {
      'business_mode': businessMode,
      // New accounts confirm their email before they get a session; the
      // answer is then `email_verification_required`, not a `user`.
      'verify_email': 1,
      'activity_type': activityType,
      // Required since the compliance release; a stale version list is
      // refused with `409 terms_version_outdated`.
      'accept_terms': 1,
      if (acceptedTermsVersionIds.isNotEmpty) 'accepted_terms_version_ids': acceptedTermsVersionIds,
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

  /// `POST /api/auth/email/verify` — the 6-digit sign-up code. A 200 is
  /// exactly a successful login: `{user: {…, jwt}}`. `422 invalid_code` for a
  /// wrong or expired code, `422 not_pending` when already confirmed.
  Future<ApiResult<AuthUser>> verifyEmail({
    required String email,
    required String code,
    required String fcmToken,
  }) => _client.post<AuthUser>(
    ApiPaths.verifyEmail,
    body: {
      'email': email,
      'code': code,
      // The device fields login and register send, under both names.
      'token': fcmToken,
      'fcm_token': fcmToken,
      ..._deviceMetadata(),
    },
    parse: (body) => AuthUser.fromJson(asMap(asMap(body)['user'])),
  );

  /// `POST /api/auth/email/resend` — a new code replaces the old one. At most
  /// once a minute: `429 resend_too_soon` carries `retry_after`.
  Future<ApiResult<EmailVerificationChallenge>> resendEmailCode(String email) =>
      _client.post<EmailVerificationChallenge>(
        ApiPaths.resendEmailCode,
        body: {'email': email},
        parse: (body) => EmailVerificationChallenge.fromJson(asMap(body)),
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
  }) => _client.put<void>(
    ApiPaths.deviceToken,
    body: {'fcm_token': fcmToken, 'app_variant': appVariant, ..._deviceMetadata()},
  );

  /// Public. The sign-up country/city pickers have no other source.
  /// The platform terms for the sign-up form (v1, public).
  Future<ApiResult<SignupTerms>> signupTerms() => _client.get<SignupTerms>(
    ApiPaths.terms,
    dedupe: false,
    parse: (body) => SignupTerms.fromJson(asMap(body)),
  );

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
