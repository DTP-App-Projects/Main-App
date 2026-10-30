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

/// An amount that may be absent: `null` / `""` stay null rather than reading
/// as zero (`rate_per_km: null` is "not offered", not "free").
double? asNumOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = asStr(v).trim();
  return s.isEmpty ? null : double.tryParse(s);
}

bool asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// `""` and `null` both mean "unset" in this API. Dates are `Y-m-d H:i:s`
/// with no offset — see [AppDates] for the single place that decides the zone.
DateTime? asDate(dynamic v) {
  final s = asStr(v);
  return s.isEmpty ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

/// Evidence times (`signed_at`, `accepted_at`, `expires_at`, …). The server
/// stores them in UTC but renders them two ways: ISO with an offset
/// (`2026-10-12T17:45:14+03:00`, `…+00:00`), or a bare `Y-m-d H:i:s` that is
/// **already Riyadh wall time** (seen on marketer assignments: `19:11:44`
/// for an event at 16:11 UTC). Both come back as a UTC instant; show it with
/// [AppDates.riyadh].
DateTime? asUtcDate(dynamic v) {
  final s = asStr(v).trim();
  if (s.isEmpty) return null;
  var iso = s.replaceFirst(' ', 'T');
  if (!iso.contains('T')) iso = '${iso}T00:00:00';
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(iso);
  return DateTime.tryParse(hasZone ? iso : '$iso+03:00')?.toUtc();
}

/// A bare `Y-m-d H:i:s` the server labels as UTC (`issued_at_utc`,
/// `occurred_at_utc`). Values with an offset are honoured as usual.
DateTime? asUtcNaive(dynamic v) {
  final s = asStr(v).trim();
  if (s.isEmpty) return null;
  final iso = s.replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(iso);
  return DateTime.tryParse(hasZone ? iso : '${iso}Z')?.toUtc();
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
