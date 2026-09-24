import 'package:digital_trade_portal/core/deeplink/deep_link.dart';
import 'package:digital_trade_portal/core/deeplink/deep_link_router.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every value in an FCM `data` map arrives as a string, including ids.
void main() {
  group('DeepLink.fromData', () {
    test('coerces the string id FCM actually sends', () {
      final link = DeepLink.fromData(const {
        'event_code': 'purchase_order.approved',
        'entity_type': 'purchase_order',
        'entity_id': '1234',
        'click_action': 'purchase_order',
        'code': 'PO-20260919-AB12CD34',
        'status': 'approved',
        'side': 'trader',
      });

      expect(link.entityId, 1234);
      expect(link.entityId, isA<int>());
      expect(link.clickAction, 'purchase_order');
      expect(link.side, Workspace.trader);
    });

    test('falls back to the v1 click_id', () {
      final link = DeepLink.fromData(const {'click_action': 'order', 'click_id': '88'});
      expect(link.entityId, 88);
    });

    test('an unrecognised side is null, not a guess', () {
      final link = DeepLink.fromData(const {'click_action': 'invoice', 'side': 'admin'});
      expect(link.side, isNull);
    });

    test('a payload with nothing to route on is empty', () {
      expect(DeepLink.fromData(const {}).isEmpty, isTrue);
      expect(DeepLink.fromData(const {'title': 'hi'}).isEmpty, isTrue);
      expect(DeepLink.fromData(const {'click_action': 'invoice'}).isEmpty, isFalse);
    });
  });

  group('routing targets', () {
    test('the whole event catalogue is accounted for', () {
      // Keys present but unbuilt land on the notifications list, exactly like
      // an unknown action — the gap is explicit rather than invisible.
      for (final action in [
        'purchase_order',
        'delivery_note',
        'invoice',
        'goods_receipt',
        'post_invoice_return',
        'supplier_fleet_contract',
        'order',
        'chat',
      ]) {
        expect(DeepLinkRouter.isKnown(action), isTrue, reason: action);
      }
    });

    test('an action nobody has heard of is not known', () {
      expect(DeepLinkRouter.isKnown('teleport'), isFalse);
      expect(
        DeepLinkRouter.pathFor(const DeepLink(clickAction: 'teleport')),
        isNull,
      );
    });

    test('a known but unbuilt screen has no path yet', () {
      expect(
        DeepLinkRouter.pathFor(const DeepLink(clickAction: 'purchase_order', entityId: 1)),
        isNull,
      );
    });
  });

  group('read-only side', () {
    const supplierEvent = DeepLink(clickAction: 'purchase_order', side: Workspace.supplier);

    test('a trader-only org opening a supplier event gets a read-only view', () {
      expect(
        DeepLinkRouter.isReadOnlyFor(
          supplierEvent,
          active: Workspace.trader,
          canSwitch: false,
        ),
        isTrue,
      );
    });

    test('a hybrid org switches instead, so nothing is read-only', () {
      expect(
        DeepLinkRouter.isReadOnlyFor(
          supplierEvent,
          active: Workspace.trader,
          canSwitch: true,
        ),
        isFalse,
      );
    });

    test('an event for the side already active is never read-only', () {
      expect(
        DeepLinkRouter.isReadOnlyFor(
          supplierEvent,
          active: Workspace.supplier,
          canSwitch: false,
        ),
        isFalse,
      );
    });

    test('a push with no side is not treated as the wrong side', () {
      expect(
        DeepLinkRouter.isReadOnlyFor(
          const DeepLink(clickAction: 'invoice'),
          active: Workspace.trader,
          canSwitch: false,
        ),
        isFalse,
      );
    });
  });
}
