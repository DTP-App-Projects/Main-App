import '../../../core/i18n/app_dates.dart';
import '../../../core/network/coerce.dart';

/// A branch / warehouse as the fleet endpoints send it: `{id, name_ar, name_en}`.
class NamedPlace {
  final int id;
  final String nameAr;
  final String nameEn;
  final bool isDefault;

  const NamedPlace({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.isDefault = false,
  });

  /// `is_default` is `true` on van sales and `1` on internal transfers.
  factory NamedPlace.fromJson(Map<String, dynamic> j) => NamedPlace(
    id: asInt(j['id']),
    nameAr: asStr(j['name_ar']),
    nameEn: asStr(j['name_en']),
    isDefault: asBool(j['is_default']),
  );

  static NamedPlace? maybe(dynamic v) => v is Map ? NamedPlace.fromJson(asMap(v)) : null;

  String name(String locale) => pickLocalized(locale: locale, ar: nameAr, en: nameEn);
}

/// These endpoints stamp times with an offset (`2026-10-27T08:10:00+03:00`,
/// or Laravel's `…Z`): read as an instant, shown as Riyadh wall time — the
/// zone every other date in the app is displayed in.
DateTime? fleetTime(dynamic v) => AppDates.toRiyadh(asUtcDate(v));

/// A 6-digit hand-over code. The server sends a string so a leading zero
/// survives (`"048213"`); should one ever arrive as a number, the zeros are
/// put back rather than showing a 5-digit code the driver cannot match.
String? sixDigitCode(dynamic v) {
  if (v == null) return null;
  final s = v is num ? v.toInt().toString().padLeft(6, '0') : asStr(v).trim();
  return s.isEmpty ? null : s;
}
