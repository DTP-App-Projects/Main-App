import '../../../core/network/coerce.dart';

/// `{id, display_name}` — the other organization on a compliance document.
class ChainParty {
  final int id;
  final String name;

  const ChainParty({required this.id, required this.name});

  static ChainParty? maybe(dynamic raw) {
    final j = asMap(raw);
    if (j.isEmpty) return null;
    return ChainParty(id: asInt(j['id']), name: unwrap(j['display_name'] ?? j['name']));
  }
}

/// A linked document in the chain FA → quotation → PO → ACK, as embedded on
/// another document. Only the keys every embed is expected to share are read;
/// the full document comes from its own detail endpoint.
class ChainRef {
  final int id;

  /// `FA-…`, `QT-…`, `ACK-…` — whichever the embed calls its number.
  final String number;
  final String status;
  final String statusLabel;

  const ChainRef({required this.id, this.number = '', this.status = '', this.statusLabel = ''});

  static ChainRef? maybe(dynamic raw) {
    final j = asMap(raw);
    if (j.isEmpty) return null;
    return ChainRef(
      id: asInt(j['id']),
      number: asStr(j['agreement_no'] ?? j['quotation_no'] ?? j['ack_no'] ?? j['document_no'] ?? j['number'] ?? j['code']),
      status: asStr(j['status']),
      statusLabel: unwrap(j['status_label']),
    );
  }
}
