import '../../../core/network/coerce.dart';
import '../../../core/workspace/workspace.dart';
import 'quick_action.dart';

/// `GET /v2/ops/panel?workspace=X` — the whole home screen, server-driven.
///
/// KPIs, attention items, quick actions and document groups all arrive
/// **already filtered by workspace and by the member's permissions** (an owner
/// sees everything). They are rendered, not recomputed.
class OpsPanel {
  final Workspace workspace;
  final ThemeTokens theme;

  /// Four tiles, keyed `approvals`, `logistics`, `finance`, `overdue`.
  final List<KpiTile> kpis;

  final List<AttentionItem> attention;
  final List<QuickAction> quickActions;
  final List<DocumentGroup> documentGroups;
  final DateTime? generatedAt;

  const OpsPanel({
    required this.workspace,
    required this.theme,
    required this.kpis,
    required this.attention,
    required this.quickActions,
    required this.documentGroups,
    required this.generatedAt,
  });

  factory OpsPanel.fromJson(Map<String, dynamic> json, {required Workspace requested}) {
    final resolved = Workspace.tryParse(json['workspace']) ?? requested;
    return OpsPanel(
      workspace: resolved,
      theme: ThemeTokens.fromJson(asMap(json['theme']), workspace: resolved),
      kpis: KpiTile.listFrom(json['kpis']),
      attention: asList(json['attention'], AttentionItem.fromJson),
      quickActions: asList(json['quick_actions'], QuickAction.fromJson),
      documentGroups: asList(json['document_groups'], DocumentGroup.fromJson),
      generatedAt: asDate(json['generated_at']),
    );
  }
}

/// One KPI tile. The value is rendered as sent — the client never computes a
/// KPI it could get wrong.
class KpiTile {
  final String key;
  final String labelAr;
  final String labelEn;
  final String value;

  /// `ok` | `info` | `warn` | `danger`.
  final String severity;

  final String icon;

  const KpiTile({
    required this.key,
    required this.labelAr,
    required this.labelEn,
    required this.value,
    required this.severity,
    required this.icon,
  });

  factory KpiTile.fromJson(Map<String, dynamic> j) => KpiTile(
        key: asStr(j['key']),
        labelAr: unwrap(j['label_ar']),
        labelEn: unwrap(j['label_en']),
        // A count arrives as a number, a formatted amount as a string.
        value: asStr(j['value']),
        severity: asStr(j['severity']),
        icon: asStr(j['icon']),
      );

  /// `kpis` is documented as four named tiles, so it may be a keyed object
  /// rather than a list. Both shapes fold into the same thing.
  static List<KpiTile> listFrom(dynamic raw) {
    if (raw is List) return asList(raw, KpiTile.fromJson);
    if (raw is Map) {
      return raw.entries.where((e) => e.value is Map).map((e) {
        final map = (e.value as Map).cast<String, dynamic>();
        return KpiTile.fromJson({'key': '${e.key}', ...map});
      }).toList();
    }
    return const [];
  }

  String label(String locale) => pickLocalized(locale: locale, ar: labelAr, en: labelEn);
}

/// A row of the "what needs you now" feed.
///
/// The item shape is not published, so this reads the keys that do appear and
/// keeps the raw map. Rendering stays generic rather than guessing at fields.
class AttentionItem {
  final String key;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final String severity;
  final String entityType;
  final int? entityId;
  final String ackKey;
  final Map<String, dynamic> raw;

  const AttentionItem({
    required this.key,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.severity,
    required this.entityType,
    required this.entityId,
    required this.ackKey,
    required this.raw,
  });

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
        key: asStr(j['key'] ?? j['code']),
        titleAr: unwrap(j['title_ar'] ?? j['label_ar']),
        titleEn: unwrap(j['title_en'] ?? j['label_en']),
        bodyAr: unwrap(j['body_ar'] ?? j['text_ar']),
        bodyEn: unwrap(j['body_en'] ?? j['text_en']),
        severity: asStr(j['severity']),
        entityType: asStr(j['entity_type']),
        entityId: asIntOrNull(j['entity_id']),
        ackKey: asStr(j['ack_key']),
        raw: j,
      );

  String title(String locale) {
    final localized = pickLocalized(locale: locale, ar: titleAr, en: titleEn);
    // Some feeds send a single already-localized `title` instead of a pair.
    return localized.isNotEmpty ? localized : unwrap(raw['title'] ?? raw['label']);
  }

  String body(String locale) {
    final localized = pickLocalized(locale: locale, ar: bodyAr, en: bodyEn);
    return localized.isNotEmpty ? localized : unwrap(raw['body'] ?? raw['text']);
  }
}

/// An entry in the server-driven document menu.
class DocumentGroup {
  final String key;
  final String labelAr;
  final String labelEn;
  final String icon;
  final List<DocumentGroup> items;
  final int count;

  const DocumentGroup({
    required this.key,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.items,
    required this.count,
  });

  factory DocumentGroup.fromJson(Map<String, dynamic> j) => DocumentGroup(
        key: asStr(j['key']),
        labelAr: unwrap(j['label_ar']),
        labelEn: unwrap(j['label_en']),
        icon: asStr(j['icon']),
        items: asList(j['items'] ?? j['documents'], DocumentGroup.fromJson),
        count: asInt(j['count']),
      );

  String label(String locale) => pickLocalized(locale: locale, ar: labelAr, en: labelEn);
}
