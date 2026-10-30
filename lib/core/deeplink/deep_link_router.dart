import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../utils/roots/app_router.dart';
import '../workspace/workspace.dart';
import '../workspace/workspace_cubit.dart';
import '../../features/shared/compliance/compliance_widgets.dart';
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
  ///
  /// Compliance release: every payload follows `click_action == entity_type`
  /// with the document's id in `entity_id`. Verified on staging (2026-10-05):
  /// `invoice`, `return_note`, `quotation`, `business_relationship`
  /// (`relationship_request.*`), `complaint_ticket`, `terms_version`. The
  /// others follow the same convention but no event of theirs could be
  /// produced on staging — confirm their keys with the backend.
  static final Map<String, String Function(DeepLink link)?> targets = {
    // Each side has its own order and shipment screens.
    'purchase_order': _bySide(AppRoutes.supplierOrderDetailFor, AppRoutes.orderDetailFor),
    'delivery_note': _bySide(AppRoutes.outboundDetailFor, AppRoutes.shipmentDetailFor),
    // The supplier's invoice screen is the tax document; the trader's is
    // the one with «سداد», which «فاتورة جديدة» / «تذكير بالسداد» are for.
    // A push that names no side keeps the shared tax-invoice screen.
    'invoice': _invoice,
    // Includes «وصل ولم يُؤكَّد» — the receipt waiting for the trader.
    'goods_receipt': _withId(AppRoutes.goodsReceiptDetailFor),
    // The legacy flow is retired; its pushes land on the return notes.
    'post_invoice_return': (_) => AppRoutes.returnNotes,
    'supplier_fleet_contract': null,
    'return_note': _withId(AppRoutes.returnNoteFor),
    'quotation': _withId(AppRoutes.quotationFor),
    'business_relationship': _relationship,
    'relationship_request': _withId(AppRoutes.relationshipRequestFor),
    'framework_agreement': _withId((id) => AppRoutes.agreementFor(AgreementKind.framework, id)),
    'addendum': _withId((id) => AppRoutes.agreementFor(AgreementKind.addendum, id)),
    'credit_acknowledgment': _withId((id) => AppRoutes.agreementFor(AgreementKind.acknowledgment, id)),
    'terms_version': _withId(AppRoutes.termsDocumentFor),
    'complaint_ticket': _withId(AppRoutes.complaintFor),
    'late_payment_notice': _withId(AppRoutes.latePaymentNoticeFor),
    'dispute_pack': _withId(AppRoutes.disputePackFor),
    'marketer_assignment': _marketer,
    'marketer_commission': _marketer,
    // v1 marketplace, only if the shop ships (Phase 7).
    'order': null,
    'chat': null,
  };

  /// The supplier's screen or the trader's, by the side the push is for;
  /// [unknown] when the push names no side (the trader's otherwise).
  static String Function(DeepLink) _bySide(
    String Function(int id) supplier,
    String Function(int id) trader, {
    String Function(int id)? unknown,
  }) =>
      _withIdFn((link) => switch (link.side) {
            Workspace.supplier => supplier,
            Workspace.trader => trader,
            _ => unknown ?? trader,
          });

  static String Function(DeepLink) _withIdFn(String Function(int id) Function(DeepLink link) pick) =>
      (link) => link.entityId == null || link.entityId == 0 ? AppRoutes.notifications : pick(link)(link.entityId!);

  /// A detail route when the push names its document, the list otherwise.
  static String Function(DeepLink) _withId(String Function(int id) route) =>
      (link) => link.entityId == null || link.entityId == 0 ? AppRoutes.notifications : route(link.entityId!);

  /// `payment_notice.submitted` (to the supplier) and `.confirmed` /
  /// `.rejected` (to the trader) carry `entity_type=invoice` and the notice
  /// in `payment_notice_id`: the trader's invoice screen scrolls to it.
  static String _invoice(DeepLink link) {
    final id = link.entityId;
    if (id == null || id == 0) return AppRoutes.notifications;
    return switch (link.side) {
      Workspace.supplier => AppRoutes.invoiceComplianceFor(id),
      Workspace.trader => AppRoutes.invoiceDetailFor(id, paymentNoticeId: link.paymentNoticeId),
      // A push that names no side keeps the shared tax-invoice screen —
      // unless it is about the trader's own payment notice.
      _ => link.eventCode == 'payment_notice.confirmed' || link.eventCode == 'payment_notice.rejected'
          ? AppRoutes.invoiceDetailFor(id, paymentNoticeId: link.paymentNoticeId)
          : AppRoutes.invoiceComplianceFor(id),
    };
  }

  /// `business_relationship` carries both the request flow and the supply
  /// status (late payment). The request detail is addressed by the same id
  /// (verified: `relationship_request.submitted` → entity 4 = request 4).
  static String _relationship(DeepLink link) {
    final id = link.entityId;
    if (id == null || id == 0) return AppRoutes.notifications;
    if (link.eventCode.startsWith('relationship_request')) return AppRoutes.relationshipRequestFor(id);
    // Supply status changes: the supplier restores supply from the
    // relationship's credit screen; the trader reads the notices.
    return link.side == Workspace.supplier ? AppRoutes.creditFor(id) : AppRoutes.latePaymentNotices;
  }

  /// Offers and commissions concern either the marketer or the supplier.
  static String _marketer(DeepLink link) =>
      link.side == Workspace.supplier ? AppRoutes.supplierMarketers : AppRoutes.marketerHome;

  static bool isKnown(String clickAction) => targets.containsKey(clickAction);

  /// Resolves the path for [link], or `null` when it has nowhere to go yet.
  static String? pathFor(DeepLink link) {
    final builder = targets[link.clickAction];
    if (builder == null) return null;
    return builder(link);
  }

  /// [overridePath], when given, replaces the [targets] lookup — for pushes
  /// that resolve their own screen (driver-trip events).
  Future<void> open(DeepLink link, {String? overridePath}) async {
    if (overridePath != null) {
      await _alignWorkspace(link);
      _router.push(overridePath);
      return;
    }
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
