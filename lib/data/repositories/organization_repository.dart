import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../api_paths.dart';

/// One member of the organization (owner-console `employees`).
class Employee {
  final int membershipId;
  final String name;
  final String email;
  final String phone;
  final String whatsapp;
  final String jobTitle;
  final List<int> roleIds;
  final List<String> roleNames;
  final int? defaultBranchId;
  final String status;
  final bool isOwner;

  const Employee({
    required this.membershipId,
    required this.name,
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.jobTitle = '',
    this.roleIds = const [],
    this.roleNames = const [],
    this.defaultBranchId,
    this.status = '',
    this.isOwner = false,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        membershipId: asInt(j['membership_id'] ?? j['id']),
        name: unwrap(j['name']),
        email: asStr(j['email']),
        // All-digit phones arrive as numbers without the leading zero.
        phone: asStr(j['phone']),
        whatsapp: asStr(j['whatsapp']),
        jobTitle: unwrap(j['job_title']),
        roleIds: [
          for (final id in (j['role_ids'] is List ? j['role_ids'] as List : const [])) ?asIntOrNull(id),
        ],
        roleNames: asStrList(j['role_names']),
        defaultBranchId: (asIntOrNull(j['default_branch_id']) ?? 0) > 0 ? asIntOrNull(j['default_branch_id']) : null,
        status: asStr(j['status']),
        isOwner: asBool(j['is_owner']),
      );

  bool get isActive => status == 'active';
}

/// A role an employee can hold (`available_roles` on the onboarding bootstrap).
class OrgRoleOption {
  final int id;
  final String code;
  final String name;
  final List<String> permissions;

  const OrgRoleOption({required this.id, required this.code, required this.name, this.permissions = const []});

  factory OrgRoleOption.fromJson(Map<String, dynamic> j) => OrgRoleOption(
        id: asInt(j['id']),
        code: asStr(j['code']),
        name: unwrap(j['name']),
        permissions: [
          for (final p in (j['permissions'] is List ? j['permissions'] as List : const []))
            if (p is Map) unwrap(p['name']),
        ],
      );
}

/// A post on the organization's public profile.
class OrgPost {
  final int id;
  final String body;
  final String imageUrl;
  final DateTime? createdAt;

  const OrgPost({required this.id, this.body = '', this.imageUrl = '', this.createdAt});

  factory OrgPost.fromJson(Map<String, dynamic> j) => OrgPost(
        id: asInt(j['id']),
        body: unwrap(j['body']),
        imageUrl: asStr(j['image_url']),
        createdAt: asDate(j['created_at']),
      );
}

/// The organization's team (guide Part 2.6 «الفريق والصلاحيات») and public
/// profile (Part 4.3 «بروفايل»).
class OrganizationRepository {
  final ApiClient _client;

  OrganizationRepository(this._client);

  // ------------------------------------------------------------------ team

  Future<ApiResult<List<Employee>>> employees() => _client.get<List<Employee>>(
        ApiPaths.consoleEmployees,
        dedupe: false,
        parse: (body) => asList(asMap(body)['items'], Employee.fromJson),
      );

  /// The roles come with the onboarding bootstrap.
  Future<ApiResult<List<OrgRoleOption>>> roles() => _client.get<List<OrgRoleOption>>(
        ApiPaths.onboardingBootstrap,
        parse: (body) => asList(asMap(body)['available_roles'], OrgRoleOption.fromJson),
      );

  /// Create (no [membershipId]) or update. **An update clears every field it
  /// does not send** (live, 2026-10-06: an omitted `default_branch_id` was
  /// reset), so the form always sends the whole row. A create answers with a
  /// `temporary_password` for the new account.
  Future<ApiResult<({Employee employee, String temporaryPassword})>> saveEmployee({
    int? membershipId,
    required String name,
    String? email,
    String? phone,
    String? whatsapp,
    String? jobTitle,
    List<int> roleIds = const [],
    int? defaultBranchId,
    String status = 'active',
  }) =>
      _client.post<({Employee employee, String temporaryPassword})>(
        ApiPaths.consoleEmployees,
        body: {
          'membership_id': ?membershipId,
          'name': name,
          'email': ?email,
          'phone': ?phone,
          'whatsapp': ?whatsapp,
          'job_title': ?jobTitle,
          'role_ids': roleIds,
          'default_branch_id': ?defaultBranchId,
          'status': status,
        },
        parse: (body) {
          final map = asMap(body);
          return (
            employee: Employee.fromJson(asMap(map['employee'])),
            temporaryPassword: asStr(map['temporary_password']),
          );
        },
      );

  // --------------------------------------------------------- public profile

  /// `logo` or `cover`: multipart `file`, jpg/png/webp ≤ 5 MB → `file_url`.
  Future<ApiResult<String>> uploadImage({required bool cover, required String filePath}) async {
    final form = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    return _client.multipart<String>(
      cover ? ApiPaths.organizationCover : ApiPaths.organizationLogo,
      form: form,
      parse: (body) => asStr(asMap(body)['file_url']),
    );
  }

  /// `bio` ≤ 1000. There is no read for it (nor for the logo and cover).
  Future<ApiResult<String>> saveBio(String bio) => _client.patch<String>(
        ApiPaths.organizationBio,
        body: {'bio': bio},
        parse: (body) => unwrap(asMap(body)['bio']),
      );

  /// Cursor pagination: `{items, has_more}`, then `before_id`.
  Future<ApiResult<({List<OrgPost> items, bool hasMore})>> posts({int? beforeId}) =>
      _client.get<({List<OrgPost> items, bool hasMore})>(
        ApiPaths.organizationPosts,
        dedupe: false,
        query: {'limit': 20, 'before_id': ?beforeId},
        parse: (body) {
          final map = asMap(body);
          return (items: asList(map['items'], OrgPost.fromJson), hasMore: asBool(map['has_more']));
        },
      );

  Future<ApiResult<OrgPost>> createPost(String body) => _client.post<OrgPost>(
        ApiPaths.organizationPosts,
        body: {'body': body},
        parse: (body) => OrgPost.fromJson(asMap(asMap(body)['post'])),
      );

  Future<ApiResult<void>> deletePost(int id) => _client.delete<void>(ApiPaths.organizationPost(id));
}
