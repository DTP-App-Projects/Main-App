import '../../../core/network/coerce.dart';

/// A row from any `/v2/lookups/*` endpoint.
///
/// The lookups share a prefix and a `{items}` envelope but not a row shape:
/// some send `name`, some `display_name`, some a localized pair. Rather than
/// one model per picker, this reads whichever label the row happens to carry
/// and keeps the untouched map for callers that need more.
class LookupItem {
  final int id;
  final String nameAr;
  final String nameEn;

  /// A human-facing code — order number, SKU barcode. All-digit codes arrive
  /// as numbers, so this is always read as text.
  final String code;

  final String status;

  /// The row as sent, for the fields a specific picker needs (a SKU's
  /// resolved price, a relationship's `my_role`, …).
  final Map<String, dynamic> raw;

  const LookupItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.code,
    required this.status,
    required this.raw,
  });

  factory LookupItem.fromJson(Map<String, dynamic> j) {
    final ar = unwrap(j['name_ar']);
    final en = unwrap(j['name_en']);
    // `display_name` is the backend's own resolved label; fall back through
    // the plainer keys before giving up on a name.
    final resolved = unwrap(j['display_name'] ?? j['name'] ?? j['label'] ?? j['title']);

    return LookupItem(
      id: asInt(j['id']),
      nameAr: ar.isNotEmpty ? ar : resolved,
      nameEn: en.isNotEmpty ? en : resolved,
      code: asStr(j['code']),
      status: asStr(j['status']),
      raw: j,
    );
  }

  String label(String locale) {
    final name = pickLocalized(locale: locale, ar: nameAr, en: nameEn);
    if (name.isNotEmpty) return name;
    return code.isNotEmpty ? code : '#$id';
  }

  /// Anything a picker wants to search on client-side, between debounced
  /// server queries.
  bool matches(String query, String locale) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label(locale).toLowerCase().contains(needle) ||
        code.toLowerCase().contains(needle);
  }
}

/// The lookup names, so a typo is a compile error rather than a 404.
class Lookup {
  Lookup._();

  static const suppliers = 'suppliers';
  static const traders = 'traders';
  static const relationships = 'relationships';
  static const contracts = 'contracts';
  static const paymentTerms = 'payment_terms';
  static const branches = 'branches';
  static const bankAccounts = 'bank_accounts';
  static const products = 'products';
  static const skus = 'skus';
  static const purchaseOrders = 'purchase_orders';
  static const deliveryNotes = 'delivery_notes';
  static const invoices = 'invoices';
  static const settlements = 'settlements';
  static const businessSectors = 'business_sectors';
}
