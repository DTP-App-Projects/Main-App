import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/workspace/workspace.dart';
import '../api_paths.dart';
import '../models/ops/ops_panel.dart';
import '../models/ops/quick_action.dart';

/// The server-driven shell: theme, quick actions, document menu.
///
/// **`?workspace=` is always sent explicitly.** Omitting it puts a hybrid
/// organization on the supplier home every time, because that is the server's
/// default for both `supplier` and `hybrid`.
class OpsRepository {
  final ApiClient _client;

  OpsRepository(this._client);

  /// The whole home screen in one call: theme, KPIs, attention feed, quick
  /// actions and the document menu.
  Future<ApiResult<OpsPanel>> panel(Workspace workspace, {int attentionLimit = 5}) =>
      _client.get<OpsPanel>(
        ApiPaths.opsPanel,
        query: {
          'workspace': workspace.api,
          'attention_limit': attentionLimit.clamp(1, 50),
        },
        parse: (body) => OpsPanel.fromJson(asMap(body), requested: workspace),
      );

  /// The smallest call that carries the palette, for a theme-only refresh.
  Future<ApiResult<QuickActionsResponse>> quickActions(Workspace workspace) =>
      _client.get<QuickActionsResponse>(
        ApiPaths.opsQuickActions,
        query: {'workspace': workspace.api},
        parse: (body) =>
            QuickActionsResponse.fromJson(asMap(body), requested: workspace),
      );
}
