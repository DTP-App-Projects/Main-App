import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../utils/roots/app_router.dart';
import '../workspace/workspace.dart';
import '../workspace/workspace_cubit.dart';
import 'deep_link.dart';

/// Turns a tapped notification into a screen.
///
/// Two rules the brief is firm about:
/// 1. **A hybrid organization switches workspace first** when `data.side`
///    names the other side, so the actions on the screen match the event.
/// 2. **An unknown `click_action` opens the notifications list**, never a
///    crash and never a blank route.
class DeepLinkRouter {
  final WorkspaceCubit _workspace;
  final GoRouter _router;

  DeepLinkRouter(this._workspace, this._router);

  /// The event catalogue, with the screen each one opens.
  ///
  /// A `null` target means the detail screen is not built yet (Phases 4–6);
  /// those land on the notifications list, exactly like an unknown action.
  /// Keeping the keys here makes the gap explicit instead of invisible.
  static final Map<String, String Function(DeepLink link)?> targets = {
    'purchase_order': null,
    'delivery_note': null,
    'invoice': null,
    'goods_receipt': null,
    'post_invoice_return': null,
    'supplier_fleet_contract': null,
    // v1 marketplace, only if the shop ships (Phase 7).
    'order': null,
    'chat': null,
  };

  static bool isKnown(String clickAction) => targets.containsKey(clickAction);

  /// Resolves the path for [link], or `null` when it has nowhere to go yet.
  static String? pathFor(DeepLink link) {
    final builder = targets[link.clickAction];
    if (builder == null) return null;
    return builder(link);
  }

  Future<void> open(DeepLink link) async {
    if (link.isEmpty) {
      _router.push(AppRoutes.notifications);
      return;
    }

    await _alignWorkspace(link);

    final path = pathFor(link);
    if (path == null) {
      assert(() {
        if (!isKnown(link.clickAction)) {
          debugPrint('Unknown click_action "${link.clickAction}" — '
              'opening the notifications list.');
        }
        return true;
      }());
      _router.push(AppRoutes.notifications);
      return;
    }
    _router.push(path);
  }

  /// Switches a hybrid organization into the side the event belongs to.
  ///
  /// A single-mode organization has nothing to switch to: it still opens the
  /// screen, read-only, rather than being sent somewhere else.
  Future<void> _alignWorkspace(DeepLink link) async {
    final side = link.side;
    final current = _workspace.state;
    if (side == null || current == null) return;
    if (current.active == side) return;
    if (!current.canSwitch) return;

    await _workspace.switchTo(side);
  }

  /// True when the event belongs to a side this organization cannot act as —
  /// the screen should render read-only rather than with a broken action bar.
  static bool isReadOnlyFor(DeepLink link, {required Workspace? active, required bool canSwitch}) {
    final side = link.side;
    if (side == null || active == null) return false;
    return side != active && !canSwitch;
  }
}
