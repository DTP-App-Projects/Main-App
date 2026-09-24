/// Coercion helpers for a backend that encodes with `JSON_NUMERIC_CHECK`
/// and prefixes free text with the literal `m_p`.
///
/// Rule enforced by review: **no `json['x'] as String` anywhere.** Every
/// scalar read out of a response goes through one of these.
library;

/// `null` -> `''`. Numbers that were really strings come back as numbers,
/// so this is the only safe way to read a "string" field.
String asStr(dynamic v) => v == null ? '' : v.toString();

/// Strips the defensive `m_p` prefix the backend adds to user-authored text.
String unwrap(dynamic v) {
  final s = asStr(v);
  return s.startsWith('m_p') ? s.substring(3) : s;
}

int asInt(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  final s = asStr(v);
  return s.isEmpty ? null : int.tryParse(s);
}

double asNum(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

bool asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// `""` and `null` both mean "unset" in this API. Dates are `Y-m-d H:i:s`
/// with no offset — see [AppDates] for the single place that decides the zone.
DateTime? asDate(dynamic v) {
  final s = asStr(v);
  return s.isEmpty ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

List<T> asList<T>(dynamic v, T Function(Map<String, dynamic>) f) => v is List
    ? v.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList()
    : const [];

/// For `permissions[]`, `approved_workspaces[]`, `missing[]` …
List<String> asStrList(dynamic v) =>
    v is List ? v.map(asStr).where((e) => e.isNotEmpty).toList() : const [];

/// The backend's own `display_name` rule: prefer the active locale, fall back
/// to the other side when it is empty.
String pickLocalized({required String locale, required dynamic ar, required dynamic en}) {
  final a = unwrap(ar);
  final e = unwrap(en);
  if (locale.startsWith('ar')) return a.isNotEmpty ? a : e;
  return e.isNotEmpty ? e : a;
}
