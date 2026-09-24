import '../network/coerce.dart';
import '../workspace/workspace.dart';

/// A tapped notification, from FCM `data` or from a row in the bell list.
///
/// **Every value in an FCM `data` map is a string**, including ids — which is
/// exactly the case the coercion helpers exist for.
class DeepLink {
  /// The route key: `purchase_order`, `delivery_note`, `invoice`, …
  final String clickAction;

  final String entityType;
  final int? entityId;

  final String eventCode;
  final String code;
  final String status;

  /// `data.side` — which side of the flow the event belongs to. For a hybrid
  /// organization this decides whether to switch workspace before navigating;
  /// a tap on a supplier-side event from the trader shell would otherwise land
  /// on a screen whose actions do not match.
  final Workspace? side;

  const DeepLink({
    required this.clickAction,
    this.entityType = '',
    this.entityId,
    this.eventCode = '',
    this.code = '',
    this.status = '',
    this.side,
  });

  factory DeepLink.fromData(Map<String, dynamic> data) => DeepLink(
        clickAction: asStr(data['click_action']),
        entityType: asStr(data['entity_type']),
        // v1 pushes use `click_id` where v2 uses `entity_id`.
        entityId: asIntOrNull(data['entity_id'] ?? data['click_id']),
        eventCode: asStr(data['event_code']),
        code: asStr(data['code']),
        status: asStr(data['status']),
        side: Workspace.tryParse(data['side']),
      );

  bool get isEmpty => clickAction.isEmpty && entityId == null;
}
