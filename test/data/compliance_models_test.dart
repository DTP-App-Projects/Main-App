import 'package:digital_trade_portal/core/deeplink/deep_link.dart';
import 'package:digital_trade_portal/core/deeplink/deep_link_router.dart';
import 'package:digital_trade_portal/core/network/coerce.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/compliance/legal.dart';
import 'package:digital_trade_portal/data/models/compliance/marketer.dart';
import 'package:digital_trade_portal/data/models/compliance/quotation.dart';
import 'package:digital_trade_portal/data/models/compliance/relationship_request.dart';
import 'package:digital_trade_portal/data/models/compliance/returns_and_evidence.dart';
import 'package:digital_trade_portal/data/models/trade/delivery_note.dart';
import 'package:digital_trade_portal/data/models/trade/invoice.dart';
import 'package:digital_trade_portal/data/models/trade/purchase_order.dart';
import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Every fixture below is a trimmed copy of what staging answered on
/// 2026-10-05 while the test data was created — not an invented shape.
void main() {
  group('stream B', () {
    test('relationship request: requested vs granted, the OTP type, the frozen text', () {
      final r = RelationshipRequest.fromJson(const {
        'id': 4,
        'relationship_id': 4,
        'request_no': 'REL-2026-000001',
        'request_status': 'submitted',
        'request_status_label': 'مقدّم',
        'my_role': 'supplier',
        'can_decide': true,
        'submit_requires_otp': false,
        'otp_document_type': 'relationship_request',
        'requested_model': 'credit',
        'requested_model_label': 'توريد آجل',
        'requested_credit_term_days': 30,
        'requested_credit_limit': 50000,
        'credit_limit': 0,
        'credit_term_days': 0,
        'submitted_at': '2026-10-05T19:10:19+03:00',
        'counterparty': {'id': 16, 'display_name': 'Marketer test (Claude)'},
        'framework_agreement': null,
        'document_hash': '85d0',
      });
      expect(r.requestNo, 'REL-2026-000001');
      expect(r.canDecide, isTrue);
      expect(r.isCredit, isTrue);
      expect(r.requestedCreditLimit, 50000);
      expect(r.counterparty?.name, 'Marketer test (Claude)');
      expect(r.frameworkAgreement, isNull);
      expect(r.submittedAt, DateTime.utc(2026, 10, 5, 16, 10, 19));
    });

    test('quotation: expiry, lines and who may act', () {
      final q = Quotation.fromJson(const {
        'id': 1,
        'quotation_no': 'QT-2026-000001',
        'business_relationship_id': 1,
        'supplier': {'id': 5, 'display_name': 'Bergamo'},
        'trader': {'id': 6, 'display_name': 'club city'},
        'supply_model': 'direct',
        'valid_until': '2026-10-20T00:00:00+03:00',
        'is_valid_now': true,
        'status': 'sent',
        'status_label': 'مُرسل',
        'grand_total': 6900,
        'my_role': 'trader',
        'can_accept': true,
        'otp_document_type': 'quotation',
        'lines': [
          {'id': 1, 'sku_id': 6, 'name': 'تيد 2', 'qty': 2, 'unit_price': 3000, 'vat_rate': 15, 'line_total': 6900},
        ],
      });
      expect(q.counterparty?.name, 'Bergamo');
      expect(q.canAccept, isTrue);
      expect(q.validUntil, DateTime.utc(2026, 10, 19, 21));
      expect(q.lines.single.vatRate, 15);
    });

    test('the quotation body is exactly what staging accepted', () {
      final line = const QuotationLineInput(skuId: 6, qty: 2, unitPrice: 3000).toJson();
      expect(line, {'sku_id': 6, 'qty': 2.0, 'unit_price': 3000.0});
    });

    test('a PO carries the chain, the supply model and the OTP-gated transitions', () {
      final po = PurchaseOrder.fromJson(const {
        'id': 12,
        'code': 'PO-20260927-F522AFEB',
        'status': 'approved',
        'supply_model': 'direct',
        'supply_model_label': 'توريد نقدي',
        'spec_status': 'accepted',
        'otp_required_for': ['accepted'],
        'otp_document_type': 'purchase_order',
        'framework_agreement': null,
        'quotation': {'id': 1, 'quotation_no': 'QT-2026-000001'},
        'credit_acknowledgment': null,
      });
      expect(po.compliance.needsOtp('accepted'), isTrue);
      expect(po.compliance.needsOtp('rejected'), isFalse);
      expect(po.compliance.quotation?.number, 'QT-2026-000001');
      expect(po.compliance.frameworkAgreement, isNull);
      // Staging's PO had no `supply_hold_at`: absent means not held.
      expect(po.compliance.isHeld, isFalse);
    });
  });

  group('stream C', () {
    test('invoice: the ZATCA block, both VAT numbers, the chain refs', () {
      final inv = Invoice.fromJson(const {
        'id': 1,
        'invoice_no': 'INV-2026-000001',
        'status': 'issued',
        'grand_total': 65550,
        'document_title': 'فاتورة ضريبية',
        'invoice_kind': 'goods',
        'supply_model': 'direct',
        'seller': {'organization_id': 5, 'name': 'بيرغامو', 'vat_no': 7678578},
        'buyer': {'organization_id': 6, 'name': 'club city', 'vat_no': 48740873804},
        'vat_rate': 15,
        'zatca_qr': 'AQ7YqNmK2LHYutin2YXZiA==',
        'refs': {'po_no': 'PO-20260926-C73ECDC0', 'fa_no': '', 'grn_nos': ['GR-20260926-1A3C5A1F']},
        'issued_at_utc': '2026-10-05 16:14:01',
      });
      final c = inv.compliance;
      expect(c.documentTitle, 'فاتورة ضريبية');
      expect(c.seller?.vatNo, '7678578');
      expect(c.buyer?.vatNo, '48740873804');
      expect(c.hasZatca, isTrue);
      expect(c.grnNos, ['GR-20260926-1A3C5A1F']);
      // `issued_at_utc` is bare UTC, not Riyadh.
      expect(c.issuedAt, DateTime.utc(2026, 10, 5, 16, 14, 1));
    });

    test('goods receipt: confirmation state and the shortage/defect split per line', () {
      final g = GoodsReceipt.fromJson(const {
        'id': 1,
        'purchase_order_id': 11,
        'delivery_note_id': 11,
        'status': 'accepted',
        'receipt_no': 'GR-20260926-1A3C5A1F',
        'pod_method': '',
        'recorded_by_role': 'trader',
        'confirmation_status': 'confirmed',
        'confirmation_label': 'أكده التاجر',
        'requires_trader_confirmation': false,
        'lines': [
          {'id': 1, 'sku_id': 6, 'expected_qty': 20, 'received_qty': 18, 'shortage_qty': 1, 'defect_qty': 1, 'defect_note': 'كسر'},
        ],
      });
      expect(g.compliance.isConfirmed, isTrue);
      expect(g.compliance.recordedByRole, 'trader');
      final line = g.compliance.lines[1]!;
      expect(line.shortageQty, 1);
      expect(line.defectNote, 'كسر');
      expect(line.hasIssue, isTrue);
    });

    test('return note and returnable quantities', () {
      final rn = ReturnNote.fromJson(const {
        'id': 1,
        'return_no': 'RN-2026-000001',
        'purchase_order_id': 11,
        'invoice_id': 0,
        'status': 'requested',
        'reason': 'defect',
        'requested_by_side': 'trader',
        'accepting_side': 'supplier',
        'credit_note_id': 0,
        'grand_total': 3450,
        'accepted_at': '',
        'lines': [
          {'id': 1, 'sku_id': 6, 'sku_name': 'تيد 2', 'qty': 1, 'unit_price': 3000, 'line_total': 3000},
        ],
        'created_at': '2026-10-05 19:13:38',
      });
      expect(rn.hasInvoice, isFalse);
      expect(rn.acceptingSide, 'supplier');
      expect(rn.acceptedAt, isNull);
      // A bare time here is Riyadh wall time (19:13 = 16:13 UTC).
      expect(rn.createdAt, DateTime.utc(2026, 10, 5, 16, 13, 38));

      final caps = Returnable.fromJson(const {
        'data': {
          'purchase_order_id': 11,
          'supply_model': 'direct',
          'reasons': [
            {'key': 'defect', 'label': 'عيب'},
            {'key': 'agreed', 'label': 'اتفاق الطرفين'},
          ],
          'lines': [
            {'sku_id': 6, 'returnable_qty': 20, 'custody_remaining_qty': null},
          ],
        },
      });
      expect(caps.qtyBySku, {6: 20});
      expect(caps.custodyBySku, isEmpty);
      expect(caps.reasons.map((r) => r.key), ['defect', 'agreed']);
    });

    test('consignment terms default to 14 / 14 / 60, cost on the buyer', () {
      expect(ConsignmentTerms.defaults.toJson(), {
        'stocktake_cycle_days': 14,
        'remittance_days_after_sale': 14,
        'unsold_return_days': 60,
        'return_cost_bearer': 'buyer',
      });
    });
  });

  group('stream D', () {
    test('late payment shows principal only and the supplier actions', () {
      final lp = LatePaymentStatus.fromJson(const {
        'late_payment': {
          'supply_status': 'active',
          'supply_status_label': 'التوريد قائم',
          'outstanding': 65550,
          'amount_basis': 'principal_only',
          'is_past_due': false,
          'original_due_date': '2026-10-05',
          'can_issue_first': false,
          'can_restore': false,
          'notices': [],
        },
      });
      expect(lp.outstanding, 65550);
      expect(lp.canIssueFirst, isFalse);
      expect(lp.supplyStatusLabel, 'التوريد قائم');
    });

    test('Nafith: API off means the fallback link; the amount is the outstanding', () {
      final p = PromissoryNotes.fromJson(const {
        'promissory_notes': [],
        'api_enabled': false,
        'fallback_url': 'https://www.nafith.sa',
        'eligible': false,
        'defaults': {'amount': 65550, 'currency': 'SAR', 'maturity_date': '2026-10-05'},
        'amount_rule': 'invoice_outstanding_exact',
      });
      expect(p.apiEnabled, isFalse);
      expect(p.fallbackUrl, 'https://www.nafith.sa');
      expect(p.amount, 65550);
    });

    test('dispute pack: live vs frozen items, UTC generation time', () {
      final pack = DisputePack.fromJson(const {
        'id': 1,
        'pack_no': 'PACK-2026-000001',
        'scope_type': 'invoice',
        'scope_id': 1,
        'items_count': 2,
        'live_items_count': 1,
        'generated_at_utc': '2026-10-05 16:14:53',
        'principal_outstanding': 65550,
        'items': [
          {'type': 'purchase_order', 'label': 'أمر الشراء', 'number': 'PO-1', 'source': 'live'},
          {'type': 'invoice', 'label': 'الفاتورة', 'number': 'INV-1', 'source': 'frozen', 'frozen_document_id': 11, 'revision': 1},
        ],
      });
      expect(pack.items.first.isLive, isTrue);
      expect(pack.items.last.frozenDocumentId, 11);
      expect(pack.generatedAt, DateTime.utc(2026, 10, 5, 16, 14, 53));
    });

    test('marketer: assignment, commission pending until collection', () {
      final a = MarketerAssignment.fromJson(const {
        'id': 1,
        'assignment_no': 'MK-2026-000001',
        'marketer': {'id': 1, 'organization_id': 16, 'display_name': 'M', 'referral_code': 'MKTNN7STN', 'status': 'active'},
        'supplier_name': 'Bergamo',
        'rate_type': 'percent',
        'rate_value': 2.5,
        'rate_label': '2.5%',
        'status': 'offered',
        'earned_on': 'invoice_collected',
      });
      expect(a.isOffered, isTrue);
      expect(a.marketer?.referralCode, 'MKTNN7STN');

      final c = MarketerCommission.fromJson(const {
        'id': 1,
        'assignment_no': 'MK-2026-000001',
        'purchase_order_code': 'PO-20260927-F522AFEB',
        'invoice_id': null,
        'commission_amount': 0,
        'status': 'pending',
        'status_label': 'بانتظار تحصيل الفاتورة',
      });
      expect(c.status, 'pending');
      expect(c.invoiceId, isNull);

      final none = MarketerOverview.fromJson(const {'marketer': null, 'totals': null});
      expect(none.isRegistered, isFalse);
    });
  });

  group('stream A', () {
    test('complaint list carries the response window and the categories', () {
      final list = ComplaintList.fromJson(const {
        'data': [
          {
            'ticket_id': 1,
            'ticket_no': 'TKT-2026-000001',
            'status': 'open',
            'sla': 'on_track',
            'due_at': '2026-10-20T19:12:47+03:00',
          },
        ],
        'current_page': 1,
        'last_page': 1,
        'total': 1,
        'response_days': 15,
        'categories': [
          {'key': 'technical', 'label': 'مشكلة تقنية'},
        ],
      });
      expect(list.responseDays, 15);
      expect(list.categories.single.key, 'technical');
      expect(list.tickets.single.dueAt, DateTime.utc(2026, 10, 20, 16, 12, 47));
    });

    test('a thread attachment keeps its authenticated url', () {
      final m = TicketMessage.fromJson(const {
        'message_id': 2,
        'author': 'user',
        'attachments': [
          {'name': 'test.png', 'size': 73, 'mime': 'image/png', 'url': 'https://tacaml.com/api/v2/complaint_tickets/1/attachment?message=2&i=0'},
        ],
      });
      expect(m.isMine, isTrue);
      expect(m.attachments.single.isImage, isTrue);
    });

    test('signatories expose the registration lock and the activity type', () {
      final info = SignatoriesInfo.fromJson(const {
        'organization': {
          'organization_id': 6,
          'legal_name_ar': 'club city',
          'commercial_reg_no': 4087340730,
          'vat_no': 48740873804,
          'activity_type': 'retailer',
          'registration_locked': true,
          'cr_verified': false,
        },
        'can_manage': true,
        'data': [
          {'membership_id': 6, 'name': 'r', 'is_owner': true, 'is_authorized_signatory': true},
        ],
      });
      expect(info.organization.registrationLocked, isTrue);
      expect(info.organization.commercialRegNo, '4087340730');
      expect(info.signatoryCount, 1);
    });
  });

  group('envelopes', () {
    test('the `{<plural>: [], pagination}` lists page like the paginator', () {
      final page = pagedFrom(
        const {
          'quotations': [
            {'id': 1, 'quotation_no': 'QT-1'},
          ],
          'pagination': {'current_page': 1, 'last_page': 2, 'per_page': 15, 'total': 16},
        },
        Quotation.fromJson,
        keys: const ['quotations'],
      );
      expect(page.items.single.quotationNo, 'QT-1');
      expect(page.hasMore, isTrue);
    });

    test('return notes POST body matches what staging accepted', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': {'id': 1}}, status: 201));
      await ComplianceRepository(client).createReturnNote(
        purchaseOrderId: 11,
        reason: 'defect',
        qtyBySku: const {6: 1, 7: 0},
        notes: 'x',
      );
      expect(adapter.requests.single.data, {
        'purchase_order_id': 11,
        'reason_type': 'defect',
        'lines': [
          {'sku_id': 6, 'qty': 1.0},
        ],
        'notes': 'x',
      });
    });
  });

  group('push routing', () {
    String? path(Map<String, dynamic> data) => DeepLinkRouter.pathFor(DeepLink.fromData(data));

    test('verified payloads open their document', () {
      expect(path({'click_action': 'quotation', 'entity_id': '1'}), '/compliance/quotations/1');
      expect(path({'click_action': 'return_note', 'entity_id': '1'}), '/compliance/returns/1');
      expect(path({'click_action': 'invoice', 'entity_id': '1'}), '/compliance/invoices/1');
      expect(path({'click_action': 'complaint_ticket', 'entity_id': '1'}), '/compliance/complaints/1');
      expect(path({'click_action': 'terms_version', 'entity_id': '3'}), '/terms/doc/3');
      expect(
        path({'click_action': 'business_relationship', 'entity_id': '4', 'event_code': 'relationship_request.submitted'}),
        '/compliance/relationship-requests/4',
      );
    });

    test('supply-status pushes go to the side that can act', () {
      expect(
        path({'click_action': 'business_relationship', 'entity_id': '4', 'event_code': 'supply.suspended', 'side': 'supplier'}),
        '/supplier/relationships/4/credit',
      );
      expect(
        path({'click_action': 'business_relationship', 'entity_id': '4', 'event_code': 'supply.suspended', 'side': 'trader'}),
        '/compliance/late-notices',
      );
    });

    test('marketer events split by side', () {
      expect(path({'click_action': 'marketer_assignment', 'entity_id': '1', 'side': 'supplier'}), '/compliance/marketers');
      expect(path({'click_action': 'marketer_commission', 'entity_id': '1'}), '/compliance/marketer');
    });

    test('a push without an id falls back to the notifications list', () {
      expect(path({'click_action': 'quotation'}), '/notifications');
    });
  });

  test('Workspace parse is what side-based routing relies on', () {
    expect(Workspace.tryParse('supplier'), Workspace.supplier);
    expect(asUtcDate(''), isNull);
  });
}
