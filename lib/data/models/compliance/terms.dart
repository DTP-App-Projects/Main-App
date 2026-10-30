import '../../../core/network/coerce.dart';

/// One published, frozen version of a legal text. The same row shape comes
/// back from `terms_status.documents[]`, `terms_versions.data[]` and the
/// detail endpoint; only the detail carries [bodyHtml] and the footer.
///
/// Verified against staging on 2026-10-05.
class TermsVersion {
  final int id;

  /// `platform_terms`, `joining_supplier`, `joining_trader`,
  /// `joining_marketer`, `joining_delivery`.
  final String docKey;
  final String title;

  /// Short name for lists and checkboxes.
  final String label;

  /// Numeric on the wire (`1.1`).
  final String version;
  final String bodyHash;
  final String bodyHtml;
  final String changeSummary;

  /// The server's own wording of the act, «قبول الشروط — تعبير ملزم عن الإرادة».
  final String acceptanceLabel;
  final String legalFooter;

  /// UTC.
  final DateTime? publishedAt;
  final DateTime? effectiveAt;
  final bool inForce;

  /// `user` (platform terms, each user for themselves) or `organization`
  /// (joining agreement, accepted by the authorized signatory).
  final String scope;
  final bool accepted;

  /// False for an organization-scoped version when the user is not the
  /// organization's authorized signatory.
  final bool canAccept;

  const TermsVersion({
    required this.id,
    required this.docKey,
    required this.title,
    this.label = '',
    this.version = '',
    this.bodyHash = '',
    this.bodyHtml = '',
    this.changeSummary = '',
    this.acceptanceLabel = '',
    this.legalFooter = '',
    this.publishedAt,
    this.effectiveAt,
    this.inForce = false,
    this.scope = 'user',
    this.accepted = false,
    this.canAccept = true,
  });

  bool get isOrganizationScope => scope == 'organization';

  String get shortName => label.isNotEmpty ? label : title;

  factory TermsVersion.fromJson(Map<String, dynamic> j) => TermsVersion(
        id: asInt(j['terms_version_id'] ?? j['id']),
        docKey: asStr(j['doc_key']),
        title: unwrap(j['title']),
        label: unwrap(j['label']),
        version: asStr(j['version']),
        bodyHash: asStr(j['body_hash']),
        bodyHtml: asStr(j['body_html']),
        changeSummary: unwrap(j['change_summary']),
        acceptanceLabel: unwrap(j['acceptance_label']),
        legalFooter: unwrap(j['legal_footer']),
        publishedAt: asUtcDate(j['published_at']),
        effectiveAt: asUtcDate(j['effective_at']),
        inForce: asBool(j['in_force']),
        scope: asStr(j['scope']).isEmpty ? 'user' : asStr(j['scope']),
        accepted: asBool(j['accepted']),
        canAccept: j['can_accept'] == null || asBool(j['can_accept']),
      );
}

/// `GET /terms_status` (and the list endpoint, which carries the same flags
/// next to `data`).
class TermsStatus {
  /// A version is in force and not accepted: writes are refused with `409`.
  final bool acceptanceRequired;

  /// A new version is published but not yet in force — the 7-day notice.
  final bool updateAnnounced;
  final List<TermsVersion> documents;

  const TermsStatus({
    this.acceptanceRequired = false,
    this.updateAnnounced = false,
    this.documents = const [],
  });

  static const empty = TermsStatus();

  /// What the gate screen offers: in force, not accepted.
  List<TermsVersion> get pending => documents.where((d) => d.inForce && !d.accepted).toList();

  /// What the banner announces: not in force yet, not accepted.
  List<TermsVersion> get upcoming => documents.where((d) => !d.inForce && !d.accepted).toList();

  /// Not yet accepted, in force or not — what the user may accept now.
  List<TermsVersion> get unaccepted => documents.where((d) => !d.accepted).toList();

  factory TermsStatus.fromJson(dynamic body) {
    final j = asMap(body);
    return TermsStatus(
      acceptanceRequired: asBool(j['acceptance_required']),
      updateAnnounced: asBool(j['update_announced']),
      documents: asList(j['documents'] ?? j['data'], TermsVersion.fromJson),
    );
  }
}

/// A row of `GET /terms_acceptances`. Verified 2026-10-05.
class TermsAcceptance {
  final int id;
  final int termsVersionId;
  final String docKey;
  final String version;
  final int? organizationId;

  /// `click` (level 1), `otp` (level 2), `nafath`, …
  final String method;

  /// Where it was given: `api_signup`, `api`, `web`, …
  final String source;
  final String bodyHash;

  /// UTC.
  final DateTime? acceptedAt;

  const TermsAcceptance({
    required this.id,
    this.termsVersionId = 0,
    this.docKey = '',
    this.version = '',
    this.organizationId,
    this.method = '',
    this.source = '',
    this.bodyHash = '',
    this.acceptedAt,
  });

  factory TermsAcceptance.fromJson(Map<String, dynamic> j) => TermsAcceptance(
        id: asInt(j['acceptance_id']),
        termsVersionId: asInt(j['terms_version_id']),
        docKey: asStr(j['doc_key']),
        version: asStr(j['version']),
        organizationId: asIntOrNull(j['organization_id']),
        method: asStr(j['signature_method']),
        source: asStr(j['source']),
        bodyHash: asStr(j['body_hash']),
        acceptedAt: asUtcDate(j['accepted_at']),
      );
}

/// A version the server names in `409 terms_version_outdated` at sign-up —
/// the full set the new organization must accept (platform terms **and** the
/// joining agreement for its activity), which `/api/terms` alone does not give.
class RequiredTermsVersion {
  final int id;
  final String docKey;
  final String version;
  final String title;

  const RequiredTermsVersion({required this.id, this.docKey = '', this.version = '', this.title = ''});

  factory RequiredTermsVersion.fromJson(Map<String, dynamic> j) => RequiredTermsVersion(
        id: asInt(j['terms_version_id']),
        docKey: asStr(j['doc_key']),
        version: asStr(j['version']),
        title: unwrap(j['title']),
      );
}

/// `GET /api/terms` (v1, public): the platform terms shown on the sign-up
/// form, before there is a session to call `/v2/terms_versions` with.
/// Verified 2026-10-05: `{text, terms_version_id, version, effective_at}`.
class SignupTerms {
  final String html;
  final int? termsVersionId;
  final String version;
  final DateTime? effectiveAt;

  const SignupTerms({required this.html, this.termsVersionId, this.version = '', this.effectiveAt});

  factory SignupTerms.fromJson(Map<String, dynamic> j) => SignupTerms(
        html: asStr(j['text']),
        termsVersionId: asIntOrNull(j['terms_version_id']),
        version: asStr(j['version']),
        effectiveAt: asUtcDate(j['effective_at']),
      );
}
