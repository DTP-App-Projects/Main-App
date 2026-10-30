import 'package:digital_trade_portal/data/models/ops/ops_panel.dart';
import 'package:flutter_test/flutter_test.dart';

/// `document_groups` as `/ops/panel` sends it live (2026-10-05): a map of
/// group key → document rows, not the documented list of groups.
void main() {
  test('the keyed shape becomes one group per key, counted', () {
    final groups = DocumentGroup.listFrom(const {
      'purchase_orders': [
        {'entity_type': 'purchase_order', 'title': 'Purchase Order', 'status': 'approved'},
        {'entity_type': 'purchase_order', 'title': 'Purchase Order', 'status': 'ready'},
      ],
      'invoices': [
        {'entity_type': 'invoice', 'title': 'Invoice', 'status': 'issued'},
      ],
      'contracts': <Object>[],
    });
    expect(groups.map((g) => g.key), ['purchase_orders', 'invoices', 'contracts']);
    expect(groups.map((g) => g.count), [2, 1, 0]);
    // No server label: the screen names the group from its key, so the
    // rows' English `title` never reaches it.
    expect(groups.first.label('ar'), isEmpty);
  });

  test('the documented list shape still parses', () {
    final groups = DocumentGroup.listFrom(const [
      {'key': 'orders', 'label_ar': 'الطلبات', 'label_en': 'Orders', 'count': 3},
    ]);
    expect(groups.single.label('ar'), 'الطلبات');
    expect(groups.single.count, 3);
  });

  test('anything else is no groups', () {
    expect(DocumentGroup.listFrom(null), isEmpty);
    expect(DocumentGroup.listFrom('x'), isEmpty);
  });
}
