import 'coerce.dart';

/// A raw Laravel paginator. Every `/v2` list endpoint returns one, and each
/// row is the Eloquent model with the mobile payload under `formatted` —
/// the sibling raw columns are noise.
class Paged<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  /// Only the notifications list carries this.
  final int? unreadCount;

  const Paged({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.unreadCount,
  });

  const Paged.empty()
      : items = const [],
        currentPage = 1,
        lastPage = 1,
        perPage = 15,
        total = 0,
        unreadCount = null;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => items.isEmpty;

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) f, {
    bool formattedKey = true,
  }) {
    final rows = (j['data'] as List? ?? const []);
    return Paged(
      items: rows.whereType<Map>().map((r) {
        final m = r.cast<String, dynamic>();
        final src = formattedKey && m['formatted'] is Map
            ? (m['formatted'] as Map).cast<String, dynamic>()
            : m;
        return f(src);
      }).toList(),
      currentPage: asInt(j['current_page']),
      lastPage: asInt(j['last_page']),
      perPage: asInt(j['per_page']),
      total: asInt(j['total']),
      unreadCount: asIntOrNull(j['unread_count']),
    );
  }

  Paged<T> append(Paged<T> next) => Paged(
        items: [...items, ...next.items],
        currentPage: next.currentPage,
        lastPage: next.lastPage,
        perPage: next.perPage,
        total: next.total,
        unreadCount: next.unreadCount ?? unreadCount,
      );
}

/// Organization posts do not use the paginator — they page by cursor:
/// `{organization_id, items, has_more}` with `?limit=&before_id=`.
class Cursored<T> {
  final List<T> items;
  final bool hasMore;
  final int? organizationId;

  const Cursored({required this.items, required this.hasMore, this.organizationId});

  factory Cursored.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) =>
      Cursored(
        items: asList(j['items'], f),
        hasMore: asBool(j['has_more']),
        organizationId: asIntOrNull(j['organization_id']),
      );
}

/// Page-size parameter names differ per endpoint family.
class PageParams {
  PageParams._();

  /// Most v2 lists: `?limit=` (default 15 server-side).
  static Map<String, dynamic> limit(int page, {int size = 15}) =>
      {'page': page, 'limit': size};

  /// Notifications only: `?per_page=` (default 20, max 100).
  static Map<String, dynamic> perPage(int page, {int size = 20}) =>
      {'page': page, 'per_page': size.clamp(1, 100)};
}
