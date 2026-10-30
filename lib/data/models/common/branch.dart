import '../../../core/network/coerce.dart';

class Branch {
  final int id;
  final String type;
  final String nameAr;
  final String nameEn;
  final String addressText;
  final int? countryId;
  final int? cityId;
  final String contactName;
  final String contactPhone;
  final bool isDefault;
  final String status;

  /// The map pin: what makes a supplier branch a stop on driver routes
  /// (guide Part 5.1). Only meaningful when [hasLocation] — `GET
  /// /v2/organization` sends `0, 0` for "no pin" (kept for older builds),
  /// the owner console and lookups send `null`.
  final double? latitude;
  final double? longitude;

  /// The server's `has_location`, which is the only reliable test.
  final bool hasLocation;

  const Branch({
    required this.id,
    required this.type,
    required this.nameAr,
    required this.nameEn,
    required this.addressText,
    required this.countryId,
    required this.cityId,
    required this.contactName,
    required this.contactPhone,
    required this.isDefault,
    required this.status,
    this.latitude,
    this.longitude,
    this.hasLocation = false,
  });

  factory Branch.fromJson(Map<String, dynamic> j) {
    final lat = j['latitude'] == null ? null : asNum(j['latitude']);
    final lng = j['longitude'] == null ? null : asNum(j['longitude']);
    // Payloads from before `has_location` existed: `0, 0` meant no pin.
    final located = j.containsKey('has_location')
        ? asBool(j['has_location'])
        : lat != null && lng != null && !(lat == 0 && lng == 0);
    return Branch(
      id: asInt(j['id']),
      type: asStr(j['type'] ?? j['branch_type']),
      nameAr: unwrap(j['name_ar']),
      nameEn: unwrap(j['name_en']),
      addressText: unwrap(j['address_text']),
      countryId: asIntOrNull(j['country_id']),
      cityId: asIntOrNull(j['city_id']),
      contactName: unwrap(j['contact_name']),
      contactPhone: unwrap(j['contact_phone']),
      isDefault: asBool(j['is_default']),
      status: asStr(j['status']),
      latitude: located ? lat : null,
      longitude: located ? lng : null,
      hasLocation: located,
    );
  }

  Branch withLocation(double? latitude, double? longitude) => Branch(
    id: id,
    type: type,
    nameAr: nameAr,
    nameEn: nameEn,
    addressText: addressText,
    countryId: countryId,
    cityId: cityId,
    contactName: contactName,
    contactPhone: contactPhone,
    isDefault: isDefault,
    status: status,
    latitude: latitude,
    longitude: longitude,
    hasLocation: latitude != null && longitude != null,
  );

  String displayName(String locale) => pickLocalized(locale: locale, ar: nameAr, en: nameEn);
}

/// The branch map pin's rules, shared by the picker and the request body —
/// a port of the website's branch-location script.
abstract final class BranchPin {
  /// Rejects out-of-range values and `0, 0` (the "no pin" placeholder that
  /// `GET /v2/organization` still sends, which is open ocean anyway).
  static bool isValid(double? lat, double? lng) =>
      lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);

  /// Both coordinates (rounded to the 7 decimals the server stores) or both
  /// `null`, which clears the pin. Never one alone: that is a 400.
  static Map<String, double?> body(double? lat, double? lng) => isValid(lat, lng)
      ? {'latitude': _round7(lat!), 'longitude': _round7(lng!)}
      : const {'latitude': null, 'longitude': null};

  static double _round7(double v) => double.parse(v.toStringAsFixed(7));

  /// The website's patterns, tried in this order; group 1 is the latitude.
  static final _patterns = [
    // google .../@24.7,46.6,15z
    RegExp(r'@(-?\d{1,2}\.\d+),\s*(-?\d{1,3}\.\d+)'),
    // ?q=lat,lng · waze ll=
    RegExp(
      r'[?&](?:q|query|ll|destination|daddr)=(-?\d{1,2}\.\d+)(?:,|%2C)\s*(-?\d{1,3}\.\d+)',
      caseSensitive: false,
    ),
    // google place data
    RegExp(r'!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)'),
    // osm #map=z/lat/lng
    RegExp(r'[#&]map=\d+/(-?\d{1,2}\.\d+)/(-?\d{1,3}\.\d+)'),
    // plain "lat, lng" (also the Arabic comma)
    RegExp(r'^(-?\d{1,2}(?:\.\d+)?)\s*[,،\s]\s*(-?\d{1,3}(?:\.\d+)?)$'),
  ];

  /// Coordinates typed or pasted into the search box, or inside a map link.
  /// Null when nothing matches or the values are not a valid pin. Short
  /// share links (`maps.app.goo.gl/…`) carry none until resolved.
  static ({double lat, double lng})? parse(String text) {
    final input = text.trim();
    if (input.isEmpty) return null;
    for (final pattern in _patterns) {
      final m = pattern.firstMatch(input);
      if (m == null) continue;
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      return isValid(lat, lng) ? (lat: lat!, lng: lng!) : null;
    }
    return null;
  }

  /// A short share link whose redirect may lead to coordinates.
  static bool isShortLink(String text) => RegExp(
    r'^https?://(maps\.app\.goo\.gl|goo\.gl/maps)/',
    caseSensitive: false,
  ).hasMatch(text.trim());

  static String mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}
