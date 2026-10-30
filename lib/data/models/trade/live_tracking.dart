import '../../../core/network/coerce.dart';

/// The `live` block of the tracking snapshot: everything needed to follow the
/// driver in Firebase Realtime Database instead of polling.
///
/// `null` — or `enabled: false` — means there is nothing to follow (not picked
/// up yet, delivered, or not configured); the screen then just polls.
class LiveSession {
  /// Firebase custom token, signed for [uid].
  final String token;
  final String uid;
  final String databaseUrl;

  /// When [token]'s grant runs out. Renewed about five minutes before.
  final DateTime? expiresAt;

  /// e.g. `live/drivers/12`.
  final String path;
  final int? driverId;

  const LiveSession({
    required this.token,
    required this.uid,
    required this.databaseUrl,
    required this.expiresAt,
    required this.path,
    required this.driverId,
  });

  static LiveSession? tryParse(dynamic v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    if (!asBool(j['enabled'])) return null;
    final session = LiveSession(
      token: asStr(j['token']),
      uid: asStr(j['uid']),
      databaseUrl: asStr(j['database_url']),
      expiresAt: asDate(j['expires_at']),
      path: asStr(j['path']),
      driverId: asIntOrNull(j['driver_id']),
    );
    // Missing any of these, there is nothing a listener could do.
    if (session.token.isEmpty || session.databaseUrl.isEmpty || session.path.isEmpty) {
      return null;
    }
    return session;
  }

  /// Same grant, same node: re-attaching would change nothing.
  bool sameAs(LiveSession other) =>
      token == other.token && databaseUrl == other.databaseUrl && path == other.path;
}

/// One driver position node: `{lat, lng, ts, sup, route_id, heading?,
/// speed_kmh?, acc?}`. Numbers may arrive as int or double.
class LivePosition {
  final double lat;
  final double lng;

  /// Server timestamp of the fix; `null` when the node carries none.
  final DateTime? at;
  final double? heading;
  final double? speedKmh;
  final double? accuracy;
  final int? routeId;

  const LivePosition({
    required this.lat,
    required this.lng,
    required this.at,
    this.heading,
    this.speedKmh,
    this.accuracy,
    this.routeId,
  });

  /// `null` for a missing node or one without usable coordinates.
  static LivePosition? tryParse(dynamic v) {
    if (v is! Map) return null;
    final j = v.map((key, value) => MapEntry('$key', value));
    final lat = _numOrNull(j['lat']);
    final lng = _numOrNull(j['lng']);
    if (lat == null || lng == null) return null;
    final ts = _numOrNull(j['ts']);
    return LivePosition(
      lat: lat,
      lng: lng,
      at: ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts.toInt()),
      heading: _numOrNull(j['heading']),
      speedKmh: _numOrNull(j['speed_kmh']),
      accuracy: _numOrNull(j['acc']),
      routeId: asIntOrNull(j['route_id']),
    );
  }

  static double? _numOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}
