import 'package:digital_trade_portal/data/models/compliance/returns_and_evidence.dart';
import 'package:digital_trade_portal/data/models/trade/invoice.dart';
import 'package:digital_trade_portal/data/repositories/receivables_repository.dart';
import 'package:digital_trade_portal/features/trader/payables/view_models/payables_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Batch 4 of the guide audit: money and consignment (guide Parts 13–14).
void main() {
  setUp(() async => useFakeStorage());

  test('an invoice from a receipt bills its order, delivery note and accepted lines', () async {
    final (client, adapter) = clientWith(FakeAdapter.json(const {'invoice': {'id': 40, 'invoice_no': 'INV-1'}}));

    final result = await ReceivablesRepository(client).issueInvoice(
      purchaseOrderId: 300,
      deliveryNoteId: 77,
      invoiceDate: DateTime(2026, 10, 7),
      currencyCode: 'SAR',
      lines: const [InvoiceLineInput(skuId: 501, qty: 3)],
    );
    final body = adapter.requests.single.data as Map;

    expect(result.dataOrNull?.id, 40);
    expect(body['purchase_order_id'], 300);
    expect(body['delivery_note_id'], 77);
    expect(body['invoice_date'], '2026-10-07');
    expect(body['lines'], [
      {'sku_id': 501, 'qty': 3.0},
    ]);
  });

  test('the supplier records a collection with its account and date', () async {
    final (client, adapter) = clientWith(FakeAdapter.json(const {'collection_receipt': {'id': 9, 'amount': 500}}));

    await ReceivablesRepository(client).recordCollection(
      amount: 500,
      invoiceId: 40,
      paymentMethod: 'transfer',
      receivedAt: DateTime(2026, 10, 7),
      bankAccountId: 3,
      referenceNo: 'TRX-1',
    );
    final body = adapter.requests.single.data as Map;

    expect(body['invoice_id'], 40);
    expect(body['bank_account_id'], 3);
    expect(body['received_at'], '2026-10-07');
    expect(body['payment_method'], 'transfer');
  });

  test("the trader's payment notice carries the payment date", () async {
    final (client, adapter) = clientWith(FakeAdapter((options) async {
      if (options.method == 'POST') return jsonBody(const {'collection_receipt': {'id': 9}});
      return jsonBody(const {'invoice': {'id': 40, 'outstanding_amount': 500}});
    }));
    final cubit = InvoiceDetailCubit(ReceivablesRepository(client), 40);

    await cubit.claim(amount: 500, paymentMethod: 'transfer', receivedAt: DateTime(2026, 10, 5));
    final body = adapter.requests.firstWhere((r) => r.method == 'POST').data as Map;

    expect(body['received_at'], '2026-10-05');
    expect(body['invoice_id'], 40);
    await cubit.close();
  });

  test('a payment notice keeps the trader note; a custody row its return deadline', () {
    final claim = CollectionReceipt.fromJson(const {'id': 9, 'amount': 500, 'note': 'Paid by transfer'});
    final row = CustodyRow.fromJson(const {'sku_id': 1, 'received_qty': 10, 'return_deadline': '2026-12-05'});

    expect(claim.note, 'Paid by transfer');
    expect(row.returnDeadline, DateTime(2026, 12, 5));
    expect(row.balance, 10);
  });
}
