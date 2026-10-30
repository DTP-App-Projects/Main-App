import '../../../core/network/coerce.dart';

/// The `{user}` payload shared by `POST /api/auth/login`, `/register` and
/// `/profile`. The `jwt` on it is the session — persist it immediately.
class AuthUser {
  final int id;
  final String jwt;

  /// `buyer` | `seller` — legacy. Read `business_mode` from bootstrap instead.
  final String type;

  final String firstName;
  final String lastName;
  final String companyName;
  final String email;

  /// Arrives `m_p`-prefixed so the leading zero survives `JSON_NUMERIC_CHECK`.
  final String phone;

  final String image;
  final int? countryId;
  final int? cityId;
  final bool isDriver;

  /// `email_verify_pending`: the email is not confirmed yet — the app opens
  /// the code screen instead of starting a session, even if a `jwt` came.
  final bool emailVerifyPending;

  const AuthUser({
    required this.id,
    required this.jwt,
    required this.type,
    required this.firstName,
    required this.lastName,
    required this.companyName,
    required this.email,
    required this.phone,
    required this.image,
    required this.countryId,
    required this.cityId,
    required this.isDriver,
    this.emailVerifyPending = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: asInt(j['id']),
    jwt: asStr(j['jwt']),
    type: asStr(j['type']),
    firstName: unwrap(j['first_name']),
    lastName: unwrap(j['last_name']),
    companyName: unwrap(j['company_name']),
    email: unwrap(j['email']),
    phone: unwrap(j['phone']),
    image: asStr(j['image']),
    countryId: asIntOrNull(j['country_id']),
    cityId: asIntOrNull(j['city_id']),
    isDriver: asBool(j['is_driver']),
    emailVerifyPending: asBool(j[EmailVerificationChallenge.pendingFlag]),
  );

  String get fullName => [firstName, lastName].where((p) => p.isNotEmpty).join(' ');

  bool get hasSession => jwt.isNotEmpty;
}

/// `POST /api/v2/onboarding/register_owner` — creates the user *and* the
/// organization in one shot and hands back the session.
/// `email_verification_required` — the account exists but has no session
/// until the mailed 6-digit code is entered. Sent by `register_owner`
/// (`verify_email=1`), by `/auth/email/resend`, and by `/auth/login` as a 403.
class EmailVerificationChallenge {
  static const code = 'email_verification_required';

  /// The server's flag for the same state, as a code (`msg` / `error`) or as
  /// a `true` field on the answer or on its `user`.
  static const pendingFlag = 'email_verify_pending';

  static bool isCode(String? value) => value == code || value == pendingFlag;

  final String email;

  /// False when the account was created but the mail could not go out; the
  /// screen then opens with resend already enabled.
  final bool codeSent;
  final int expiresInSeconds;

  /// Already translated by `Accept-Language`.
  final String message;

  const EmailVerificationChallenge({
    required this.email,
    this.codeSent = true,
    this.expiresInSeconds = 600,
    this.message = '',
  });

  factory EmailVerificationChallenge.fromJson(Map<String, dynamic> j) => EmailVerificationChallenge(
    email: asStr(j['email']),
    // Absent means sent: only an explicit `false` reports a failure.
    codeSent: j['code_sent'] == null ? true : asBool(j['code_sent']),
    expiresInSeconds: j['expires_in'] == null ? 600 : asInt(j['expires_in']),
    message: unwrap(j['message']),
  );

  static bool matches(Map<String, dynamic> j) =>
      isCode(asStr(j['msg'])) ||
      isCode(asStr(j['error'])) ||
      asBool(j[pendingFlag]) ||
      asBool(asMap(j['user'])[pendingFlag]);
}

class RegisterOwnerResult {
  final AuthUser user;

  /// Set instead of a session when sign-up asked for email confirmation.
  final EmailVerificationChallenge? verification;
  final int organizationId;
  final List<String> approvedWorkspaces;
  final String nextScreen;
  final String businessMode;

  const RegisterOwnerResult({
    required this.user,
    required this.organizationId,
    required this.approvedWorkspaces,
    required this.nextScreen,
    required this.businessMode,
    this.verification,
  });

  factory RegisterOwnerResult.fromJson(Map<String, dynamic> j) => RegisterOwnerResult(
    // `verify_email=1`: a 200 with no `user` and no `jwt` — never mistake
    // it for a session.
    verification: EmailVerificationChallenge.matches(j)
        ? EmailVerificationChallenge.fromJson(j)
        : null,
    user: AuthUser.fromJson(asMap(j['user'])),
    organizationId: asInt(j['organization_id']),
    approvedWorkspaces: asStrList(j['approved_workspaces']),
    nextScreen: asStr(j['next_screen']),
    businessMode: asStr(j['b2b_workspace']),
  );
}
