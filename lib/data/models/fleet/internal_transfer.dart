import '../../../core/network/coerce.dart';
import 'fleet_common.dart';

// The transfer itself predates these screens and lives with the other
// advanced models; re-exported so the fleet screens import one file.
export '../advanced/shelf.dart' show InternalTransfer, TransferLine;

/// `GET /internal_transfers/form_options`.
class TransferFormOptions {
  /// Active fixed branches (vans excluded).
  final List<NamedPlace> branches;
  final List<TransferSku> skus;
  final List<String> priorities;

  const TransferFormOptions({
    this.branches = const [],
    this.skus = const [],
    this.priorities = const ['normal', 'urgent', 'critical'],
  });

  factory TransferFormOptions.fromJson(Map<String, dynamic> j) {
    final priorities = asStrList(j['priorities']);
    return TransferFormOptions(
      branches: asList(j['branches'], NamedPlace.fromJson),
      skus: asList(j['skus'], TransferSku.fromJson),
      priorities: priorities.isEmpty ? const ['normal', 'urgent', 'critical'] : priorities,
    );
  }
}

class TransferSku {
  final int id;
  final String name;
  final String code;
  final String barcode;

  const TransferSku({required this.id, this.name = '', this.code = '', this.barcode = ''});

  factory TransferSku.fromJson(Map<String, dynamic> j) => TransferSku(
    id: asInt(j['id']),
    name: asStr(j['name']),
    code: asStr(j['code']),
    barcode: asStr(j['barcode']),
  );

  String get label => name.isNotEmpty ? name : (code.isNotEmpty ? code : '#$id');
}
