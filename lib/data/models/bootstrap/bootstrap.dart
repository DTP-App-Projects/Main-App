import '../../../core/network/coerce.dart';
import '../../../core/workspace/workspace.dart';
import 'flags.dart';
import 'organization.dart';

/// `GET /api/v2/bootstrap` — the response the whole app shell is built from.
/// Cache it; re-fetch on login, org switch and resume, **not** on a workspace
/// switch.
class Bootstrap {
  final BootstrapUser user;
  final List<Organization> organizations;
  final Flags featureFlags;
  final Flags platformFlags;

  const Bootstrap({
    required this.user,
    required this.organizations,
    required this.featureFlags,
    required this.platformFlags,
  });

  factory Bootstrap.fromJson(Map<String, dynamic> j) => Bootstrap(
        user: BootstrapUser.fromJson(asMap(j['user'])),
        organizations: asList(j['organizations'], Organization.fromJson),
        featureFlags: Flags.fromJson(j['feature_flags']),
        platformFlags: Flags.fromJson(j['platform_flags']),
      );

  bool get hasOrganizations => organizations.isNotEmpty;

  /// The org to open on. Prefers an explicit choice, then the user's primary,
  /// then the first one they belong to.
  Organization? resolveOrganization(int? preferredId) {
    if (organizations.isEmpty) return null;
    for (final id in [preferredId, user.primaryOrganizationId]) {
      if (id == null) continue;
      for (final org in organizations) {
        if (org.id == id) return org;
      }
    }
    return organizations.first;
  }
}

class BootstrapUser {
  final int id;
  final String name;

  /// Legacy `users.type` (`buyer` / `seller`) — kept for debugging only.
  final String legacyType;

  final String workspaceType;
  final List<String> availableWorkspaces;
  final int? primaryOrganizationId;
  final String image;
  final String email;

  /// `m_p`-prefixed on the wire.
  final String phone;

  const BootstrapUser({
    required this.id,
    required this.name,
    required this.legacyType,
    required this.workspaceType,
    required this.availableWorkspaces,
    required this.primaryOrganizationId,
    required this.image,
    required this.email,
    required this.phone,
  });

  factory BootstrapUser.fromJson(Map<String, dynamic> j) => BootstrapUser(
        id: asInt(j['id']),
        name: unwrap(j['name']),
        legacyType: asStr(j['legacy_type']),
        workspaceType: asStr(j['workspace_type']),
        availableWorkspaces: asStrList(j['available_workspaces']),
        primaryOrganizationId: asIntOrNull(j['primary_organization_id']),
        image: asStr(j['image']),
        email: unwrap(j['email']),
        phone: unwrap(j['phone']),
      );

  Workspace? get preferredWorkspace => Workspace.tryParse(workspaceType);
}
