import '../../../core/network/coerce.dart';
import '../../../core/workspace/workspace.dart';

/// `GET /v2/ops/quick_actions?workspace=X` → `{workspace, theme, quick_actions}`.
///
/// The response is already filtered by workspace **and** by the member's
/// permissions (an owner sees everything), and sorted by `group` then
/// `priority` descending. Rendering it verbatim is how the backend hides
/// modules per workspace.
class QuickActionsResponse {
  final Workspace workspace;
  final ThemeTokens theme;
  final List<QuickAction> actions;

  const QuickActionsResponse({
    required this.workspace,
    required this.theme,
    required this.actions,
  });

  factory QuickActionsResponse.fromJson(
    Map<String, dynamic> json, {
    required Workspace requested,
  }) {
    // Trust the echoed workspace over the one we asked for, but fall back to
    // the request when the server omits it.
    final resolved = Workspace.tryParse(json['workspace']) ?? requested;
    return QuickActionsResponse(
      workspace: resolved,
      theme: ThemeTokens.fromJson(asMap(json['theme']), workspace: resolved),
      actions: asList(json['quick_actions'], QuickAction.fromJson),
    );
  }
}

/// One button in the action grid.
///
/// ⚠️ [route] still carries the **pre-REST RPC path** (`/v2/purchase_draft/store`).
/// Navigation keys off [key] and a local map; an unknown key is hidden, never
/// a crash.
class QuickAction {
  final String key;
  final String labelAr;
  final String labelEn;
  final String icon;
  final String workspace;
  final String permission;
  final List<String> permissionAlts;

  /// Kept for debugging only. Do not navigate with it.
  final String route;

  final String group;
  final int priority;

  const QuickAction({
    required this.key,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.workspace,
    required this.permission,
    required this.permissionAlts,
    required this.route,
    required this.group,
    required this.priority,
  });

  factory QuickAction.fromJson(Map<String, dynamic> j) => QuickAction(
        key: asStr(j['key']),
        labelAr: unwrap(j['label_ar']),
        labelEn: unwrap(j['label_en']),
        icon: asStr(j['icon']),
        workspace: asStr(j['workspace_resolved'] ?? j['workspace']),
        permission: asStr(j['permission']),
        permissionAlts: asStrList(j['permission_alts']),
        route: asStr(j['route']),
        group: asStr(j['group']),
        priority: asInt(j['priority']),
      );

  String label(String locale) =>
      pickLocalized(locale: locale, ar: labelAr, en: labelEn);

  /// Every permission that unlocks this action. The server has already
  /// filtered on these — the client re-checks only to grey out, never to
  /// invent an action the server withheld.
  List<String> get allPermissions =>
      [if (permission.isNotEmpty) permission, ...permissionAlts];
}
