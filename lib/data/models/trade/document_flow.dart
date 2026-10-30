import '../../../core/network/coerce.dart';

/// `GET /document_flow/{entity_type}/{entity_id}` → `{document, …}`: the
/// chain around one document. Read leniently — the documents may come as a
/// flat list (`flow`, `chain`, `documents`, `nodes`, `related`) or grouped
/// by type (`delivery_notes: [...]`, `invoices: [...]`). Anything that is
/// not a document with an id is ignored, so an unexpected shape shows
/// nothing rather than something wrong.
class DocumentFlow {
  final FlowDocument? document;
  final List<FlowDocument> related;

  const DocumentFlow({required this.document, required this.related});

  static const empty = DocumentFlow(document: null, related: []);

  static const _listKeys = ['flow', 'chain', 'documents', 'nodes', 'related', 'links'];

  /// Grouped keys and the entity type their rows are.
  static const _groups = {
    'purchase_orders': 'purchase_order',
    'purchase_order': 'purchase_order',
    'delivery_notes': 'delivery_note',
    'goods_receipts': 'goods_receipt',
    'invoices': 'invoice',
    'payment_notices': 'payment_notice',
    'collections': 'collection_receipt',
    'collection_receipts': 'collection_receipt',
    'return_notes': 'return_note',
    'credit_notes': 'credit_note',
  };

  factory DocumentFlow.fromJson(Map<String, dynamic> j) {
    final root = j['document_flow'] is Map ? asMap(j['document_flow']) : j;
    final document = root['document'] is Map
        ? FlowDocument.tryParse(asMap(root['document']))
        : null;
    final seen = <String>{if (document != null) document.key};
    final related = <FlowDocument>[];

    void add(FlowDocument? doc) {
      if (doc == null || !seen.add(doc.key)) return;
      related.add(doc);
    }

    for (final key in _listKeys) {
      final value = root[key];
      if (value is List) {
        for (final row in value.whereType<Map>()) {
          add(FlowDocument.tryParse(row.cast<String, dynamic>()));
        }
      }
    }
    _groups.forEach((key, type) {
      final value = root[key];
      final rows = value is List
          ? value.whereType<Map>()
          : (value is Map ? [value] : const <Map>[]);
      for (final row in rows) {
        add(FlowDocument.tryParse(row.cast<String, dynamic>(), fallbackType: type));
      }
    });
    return DocumentFlow(document: document, related: related);
  }
}

class FlowDocument {
  final String entityType;
  final int id;
  final String code;
  final String status;

  const FlowDocument({
    required this.entityType,
    required this.id,
    required this.code,
    required this.status,
  });

  String get key => '$entityType:$id';

  static FlowDocument? tryParse(Map<String, dynamic> j, {String? fallbackType}) {
    final type = asStr(j['entity_type'] ?? j['type'] ?? j['document_type'] ?? fallbackType);
    final id = asIntOrNull(j['entity_id'] ?? j['id']);
    if (type.isEmpty || id == null || id == 0) return null;
    return FlowDocument(
      entityType: type,
      id: id,
      code: asStr(
        j['code'] ??
            j['number'] ??
            j['document_no'] ??
            j['invoice_no'] ??
            j['receipt_no'] ??
            j['notice_no'] ??
            j['ref'],
      ),
      status: asStr(j['status']),
    );
  }
}
