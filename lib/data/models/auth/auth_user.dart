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
      );

  String get fullName => [firstName, lastName].where((p) => p.isNotEmpty).join(' ');

  bool get hasSession => jwt.isNotEmpty;
}

/// `POST /api/v2/onboarding/register_owner` — creates the user *and* the
/// organization in one shot and hands back the session.
class RegisterOwnerResult {
  final AuthUser user;
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
  });

  factory RegisterOwnerResult.fromJson(Map<String, dynamic> j) => RegisterOwnerResult(
        user: AuthUser.fromJson(asMap(j['user'])),
        organizationId: asInt(j['organization_id']),
        approvedWorkspaces: asStrList(j['approved_workspaces']),
        nextScreen: asStr(j['next_screen']),
        businessMode: asStr(j['b2b_workspace']),
      );
}
