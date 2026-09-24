import '../../../core/network/coerce.dart';
import '../../../core/workspace/workspace.dart';
import '../bootstrap/journey.dart';
import '../bootstrap/organization.dart';

/// `GET /api/v2/onboarding/bootstrap` → `{organization, journey, profiles}`.
///
/// The wizard is driven from [journey]; [profiles] is the convenience copy of
/// what has been filled in so far.
class OnboardingBootstrap {
  final Organization? organization;
  final Journey journey;
  final List<OnboardingProfile> profiles;

  const OnboardingBootstrap({
    required this.organization,
    required this.journey,
    required this.profiles,
  });

  factory OnboardingBootstrap.fromJson(Map<String, dynamic> j) {
    // `journey` is sent at the top level here, but the same payload also ships
    // nested under `organization` in `/v2/bootstrap` — accept either.
    final organization =
        j['organization'] is Map ? Organization.fromJson(asMap(j['organization'])) : null;
    final journey = j['journey'] is Map
        ? Journey.fromJson(asMap(j['journey']))
        : organization?.journey ?? Journey.empty;

    return OnboardingBootstrap(
      organization: organization,
      journey: journey,
      profiles: OnboardingProfile.listFrom(j['profiles']),
    );
  }

  OnboardingProfile? profileFor(Workspace workspace) {
    for (final profile in profiles) {
      if (profile.profileType == workspace.api) return profile;
    }
    return null;
  }
}

/// One reviewed profile per workspace the organization wants. Holding **both**
/// is what makes an organization `hybrid`, and each is reviewed independently.
class OnboardingProfile {
  final int? id;

  /// `trader` | `supplier`.
  final String profileType;

  final String status;

  /// Supplier profiles only: `manufacturer` | `supplier` | `both`.
  final String supplierNature;

  final List<int> sectorIds;
  final List<String> channelCodes;
  final String notes;

  const OnboardingProfile({
    required this.id,
    required this.profileType,
    required this.status,
    required this.supplierNature,
    required this.sectorIds,
    required this.channelCodes,
    required this.notes,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> j) => OnboardingProfile(
        id: asIntOrNull(j['id'] ?? j['profile_id']),
        profileType: asStr(j['profile_type'] ?? j['type']),
        status: asStr(j['status']),
        supplierNature: asStr(j['supplier_nature']),
        sectorIds: _ids(j['sector_ids'] ?? j['sectors']),
        channelCodes: asStrList(j['channel_codes']),
        notes: unwrap(j['notes']),
      );

  /// The server may key the profiles by type rather than sending a list; both
  /// shapes fold into the same thing.
  static List<OnboardingProfile> listFrom(dynamic raw) {
    if (raw is List) return asList(raw, OnboardingProfile.fromJson);
    if (raw is Map) {
      return raw.entries.where((e) => e.value is Map).map((e) {
        final map = (e.value as Map).cast<String, dynamic>();
        return OnboardingProfile.fromJson({'profile_type': '${e.key}', ...map});
      }).toList();
    }
    return const [];
  }

  bool get isSupplier => profileType == 'supplier';
  bool get isDraft => status.isEmpty || status == 'draft';
  bool get isActive => status == 'active';

  /// Already sent for review — the forms go read-only rather than letting the
  /// user edit something a reviewer is looking at.
  bool get isUnderReview => status == 'pending_review' || status == 'under_review';

  /// Sectors can arrive as bare ids or as `{id, name}` rows.
  static List<int> _ids(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map ? asIntOrNull(e['id']) : asIntOrNull(e))
        .whereType<int>()
        .toList();
  }
}

/// `GET /api/v2/lookups/business_sectors` → `{items}`.
class BusinessSector {
  final int id;
  final String nameAr;
  final String nameEn;

  const BusinessSector({required this.id, required this.nameAr, required this.nameEn});

  factory BusinessSector.fromJson(Map<String, dynamic> j) => BusinessSector(
        id: asInt(j['id']),
        // Lookups usually resolve `name` by Accept-Language already; the
        // per-locale pair is kept when the server sends it.
        nameAr: unwrap(j['name_ar'] ?? j['name']),
        nameEn: unwrap(j['name_en'] ?? j['name']),
      );

  String displayName(String locale) =>
      pickLocalized(locale: locale, ar: nameAr, en: nameEn);
}
