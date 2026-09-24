import '../../../core/network/coerce.dart';

/// A row from `GET /v2/notifications`.
///
/// These are the same rows as the web bell — reading one in the app marks it
/// read everywhere.
class AppNotification {
  final int id;
  final String type;

  /// `purchase_order.approved`, `invoice.overdue`, … — the event catalogue.
  final String eventCode;

  final String entityType;
  final int? entityId;

  final String title;
  final String body;
  final String textAr;
  final String textEn;

  /// The deep-link key: `purchase_order`, `delivery_note`, `invoice`, …
  final String clickAction;

  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.eventCode,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.textAr,
    required this.textEn,
    required this.clickAction,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: asInt(j['id']),
        type: asStr(j['type']),
        eventCode: asStr(j['event_code']),
        entityType: asStr(j['entity_type']),
        entityId: asIntOrNull(j['entity_id']),
        title: unwrap(j['title']),
        body: unwrap(j['body']),
        textAr: unwrap(j['text_ar']),
        textEn: unwrap(j['text_en']),
        clickAction: asStr(j['click_action']),
        isRead: asBool(j['is_read']),
        readAt: asDate(j['read_at']),
        createdAt: asDate(j['created_at']),
      );

  /// `title` and `body` are already rendered in the `Accept-Language` we sent;
  /// the per-locale pair is the fallback when they are empty.
  String headline(String locale) =>
      title.isNotEmpty ? title : pickLocalized(locale: locale, ar: textAr, en: textEn);

  String detail(String locale) {
    if (body.isNotEmpty) return body;
    final text = pickLocalized(locale: locale, ar: textAr, en: textEn);
    return text == headline(locale) ? '' : text;
  }

  /// Which side of the flow this event belongs to, where the event code says
  /// so. Used to decide whether a hybrid org should switch workspace first.
  bool get hasEntity => entityId != null && entityType.isNotEmpty;

  AppNotification markedRead() => AppNotification(
        id: id,
        type: type,
        eventCode: eventCode,
        entityType: entityType,
        entityId: entityId,
        title: title,
        body: body,
        textAr: textAr,
        textEn: textEn,
        clickAction: clickAction,
        isRead: true,
        readAt: readAt ?? DateTime.now(),
        createdAt: createdAt,
      );
}
