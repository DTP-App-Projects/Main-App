import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/trade/catalog.dart';
import 'package:digital_trade_portal/data/models/trade/delivery_note.dart';
import 'package:digital_trade_portal/data/models/trade/invoice.dart';
import 'package:digital_trade_portal/data/models/trade/purchase_order.dart';
import 'package:digital_trade_portal/data/models/trade/supplier_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('order_entry_ready', () {
    SupplierSummary supplier({
      bool ready = false,
      String relationship = 'none',
      bool contract = false,
    }) =>
        SupplierSummary.fromJson({
          'id': 7,
          'display_name': 'Acme',
          'relationship_status': relationship,
          'has_active_contract': contract,
          'order_entry_ready': ready,
        });

    test('ready means no blocking reason at all', () {
      expect(supplier(ready: true).orderBlockedReason, isNull);
    });

    test('no relationship is the first thing to fix', () {
      expect(supplier().orderBlockedReason, 'no_relationship');
    });

    test('a pending request is distinguishable from a refused one', () {
      expect(
        supplier(relationship: 'pending_review').orderBlockedReason,
        'relationship_pending',
      );
      expect(
        supplier(relationship: 'suspended').orderBlockedReason,
        'relationship_not_approved',
      );
    });

    test('blacklisted outranks everything else', () {
      expect(
        supplier(relationship: 'blacklisted', contract: true).orderBlockedReason,
        'blacklisted',
      );
    });

    test('an approved relationship without a contract still cannot order', () {
      // This is the case that surprises people: the relationship is fine and
      // ordering is still refused.
      expect(
        supplier(relationship: 'approved').orderBlockedReason,
        'no_contract',
      );
    });

    test('"none" is a status, not an absence', () {
      expect(supplier().hasRelationship, isFalse);
      expect(supplier(relationship: 'approved').hasRelationship, isTrue);
    });
  });

  group('SKU ordering rules', () {
    Sku sku({double min = 0, double step = 0, double available = 0, bool track = false}) =>
        Sku.fromJson({
          'id': 1,
          'sku_code': 'SKU-1',
          'min_order_qty': min,
          'order_step_qty': step,
          'available_qty': available,
          'track_inventory': track,
        });

    test('below the minimum is rejected with the server code', () {
      expect(sku(min: 10).validateQty(9), 'qty_less_than_min_order_qty');
      expect(sku(min: 10).validateQty(10), isNull);
    });

    test('a quantity off the step is rejected', () {
      expect(sku(step: 6).validateQty(7), 'qty_not_matching_order_step');
      expect(sku(step: 6).validateQty(12), isNull);
    });

    test('floating point does not produce a false rejection', () {
      // 0.1 * 3 is not exactly 0.3 in binary; the tolerance is what keeps a
      // legitimate quantity from being refused.
      expect(sku(step: 0.1).validateQty(0.3), isNull);
    });

    test('more than the supplier has is rejected when inventory is tracked', () {
      expect(
        sku(available: 5, track: true).validateQty(6),
        'insufficient_supplier_inventory',
      );
      // Untracked inventory is not a limit.
      expect(sku(available: 5).validateQty(600), isNull);
    });

    test('zero and negative are refused before anything else', () {
      expect(sku().validateQty(0), 'qty_less_than_min_order_qty');
      expect(sku().validateQty(-3), 'qty_less_than_min_order_qty');
    });

    test('snapQty rounds up to the next valid quantity', () {
      expect(sku(min: 10, step: 5).snapQty(3), 10);
      expect(sku(min: 10, step: 5).snapQty(11), 15);
      expect(sku(step: 6).snapQty(7), 12);
      expect(sku().snapQty(4), 4);
    });
  });

  group('price resolution', () {
    test('an unmatched price blocks the add', () {
      final resolved = PriceResolution.fromJson(const {
        'sku_id': 55,
        'pricing': {'matched': false, 'source': 'legacy_fallback'},
      });
      expect(resolved.canOrder, isFalse);
    });

    test('a matched price carries the tier that applied', () {
      final resolved = PriceResolution.fromJson(const {
        'sku_id': 55,
        'relationship_id': 12,
        'available_qty': 340.0,
        'pricing': {
          'matched': true,
          'scope_type': 'relationship',
          'unit_price': 12.5,
          'final_price': 11.25,
          'unit_discount': 1.25,
          'discount_type': 'percent',
          'line_subtotal': 112.5,
          'currency_code': 'SAR',
        },
      });

      expect(resolved.canOrder, isTrue);
      expect(resolved.finalPrice, 11.25);
      expect(resolved.hasDiscount, isTrue);
      expect(resolved.scopeType, 'relationship');
    });
  });

  group('purchase order state machine', () {
    PurchaseOrder order(Map<String, dynamic> extra) => PurchaseOrder.fromJson({
          'id': 91,
          'code': 'PO-20260919-AB12CD34',
          'status': 'approved',
          ...extra,
        });

    test('an all-digit order code survives as text', () {
      expect(order(const {'code': 20260919}).code, '20260919');
    });

    test('viewer_role is read, never inferred', () {
      expect(order(const {'viewer_role': 'trader'}).viewerWorkspace, Workspace.trader);
      expect(order(const {'viewer_role': 'supplier'}).isTraderView, isFalse);
    });

    test('a note is required only for the transitions the server names', () {
      final po = order(const {
        'allowed_transitions': ['approved', 'rejected'],
        'reason_required_for': ['rejected', 'canceled'],
      });
      expect(po.requiresNote('rejected'), isTrue);
      expect(po.requiresNote('approved'), isFalse);
    });

    test('after approval the trader may only request cancellation', () {
      final afterApproval = order(const {
        'allowed_transitions': <String>[],
        'can_request_cancel': true,
      });
      expect(afterApproval.mustRequestCancel, isTrue);

      final beforeApproval = order(const {
        'allowed_transitions': ['canceled'],
        'can_request_cancel': true,
      });
      // Still able to cancel outright, so it is not a request-only state.
      expect(beforeApproval.mustRequestCancel, isFalse);
    });

    test('an open cancel request is visible to the trader', () {
      final po = order(const {
        'cancel_request': {'id': 3, 'status': 'pending', 'reason': 'Ordered twice'},
      });
      expect(po.hasOpenCancelRequest, isTrue);
    });

    test('a decided cancel request is no longer open', () {
      final po = order(const {
        'cancel_request': {'id': 3, 'status': 'rejected'},
      });
      expect(po.hasOpenCancelRequest, isFalse);
    });
  });

  group('delivery note', () {
    DeliveryNote note(Map<String, dynamic> extra) => DeliveryNote.fromJson({
          'id': 5,
          'purchase_order_id': 91,
          'code': 'DN-1',
          ...extra,
        });

    test('no seals_match key means nothing to compare, not a tamper', () {
      expect(note(const {}).sealsMatch, isTrue);
      expect(note(const {}).sealsTampered, isFalse);
    });

    test('seals that do not match are flagged', () {
      final tampered = note(const {
        'pickup_seal_numbers': ['A1', 'A2'],
        'seals_match': false,
      });
      expect(tampered.sealsTampered, isTrue);
    });

    test('an all-digit seal number survives as text', () {
      expect(note(const {'pickup_seal_numbers': [10023, 10024]}).pickupSealNumbers,
          ['10023', '10024']);
    });

    test('only a shipment on the road is worth polling', () {
      expect(note(const {'status': 'dispatched'}).isInTransit, isTrue);
      expect(note(const {'status': 'delivered'}).isInTransit, isFalse);
      expect(note(const {'status': 'canceled'}).isInTransit, isFalse);
    });

    test('receiving is only offered once it has arrived', () {
      expect(note(const {'status': 'delivered'}).canReceive, isTrue);
      expect(note(const {'status': 'arrived'}).canReceive, isTrue);
      expect(note(const {'status': 'dispatched'}).canReceive, isFalse);
    });

    test('the proof trail parses into a handoff timeline', () {
      final tracked = note(const {
        'route_stop': {
          'id': 3,
          'proofs': [
            {'id': 1, 'proof_type': 'pickup_photo', 'file_type': 'image/jpeg'},
            {'id': 2, 'proof_type': 'delivery_signature', 'signer_name': 'Ali'},
          ],
        },
      });
      expect(tracked.routeStop!.proofs.first.isPhoto, isTrue);
      expect(tracked.routeStop!.proofs.last.isSignature, isTrue);
    });
  });

  group('invoice', () {
    test('the next due instalment is the earliest unpaid one', () {
      final invoice = Invoice.fromJson({
        'id': 1,
        'grand_total': 300,
        'outstanding_amount': 200,
        'due_schedules': [
          {'id': 11, 'installment_no': 1, 'due_date': '2026-01-01 00:00:00',
           'due_amount': 100, 'paid_amount': 100, 'status': 'paid'},
          {'id': 13, 'installment_no': 3, 'due_date': '2026-03-01 00:00:00',
           'due_amount': 100},
          {'id': 12, 'installment_no': 2, 'due_date': '2026-02-01 00:00:00',
           'due_amount': 100},
        ],
      });

      expect(invoice.nextDue?.id, 12);
      expect(invoice.dueSchedules.first.isSettled, isTrue);
    });

    test('outstanding never goes negative on an overpaid instalment', () {
      final schedule = DueSchedule.fromJson(const {
        'id': 1,
        'due_amount': 100,
        'paid_amount': 150,
      });
      expect(schedule.outstanding, 0);
      expect(schedule.isSettled, isTrue);
    });

    test('a settled invoice is never overdue', () {
      final paid = Invoice.fromJson(const {
        'id': 1,
        'status': 'paid',
        'due_date': '2020-01-01 00:00:00',
        'outstanding_amount': 0,
      });
      expect(paid.isOverdue, isFalse);
    });

    test('an unpaid invoice past its date is overdue', () {
      final late = Invoice.fromJson(const {
        'id': 1,
        'status': 'issued',
        'due_date': '2020-01-01 00:00:00',
        'outstanding_amount': 500,
      });
      expect(late.isOverdue, isTrue);
    });

    test('an all-digit invoice number survives as text', () {
      expect(Invoice.fromJson(const {'id': 1, 'invoice_no': 20260919}).invoiceNo,
          '20260919');
    });

    test('a claim is pending until it is confirmed or rejected', () {
      expect(CollectionReceipt.fromJson(const {'id': 1}).isPending, isTrue);
      expect(
        CollectionReceipt.fromJson(const {'id': 1, 'status': 'confirmed'}).isConfirmed,
        isTrue,
      );
    });
  });
}
