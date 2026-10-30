import 'package:intl/intl.dart';

/// Dates arrive as `Y-m-d H:i:s` with **no timezone offset**.
///
/// One decision, made once, applied everywhere: we treat them as server-local
/// wall-clock time and never convert. Rendering them in the device zone would
/// silently shift every due date.
class AppDates {
  AppDates._();

  static String date(DateTime? value, String locale) =>
      value == null ? '' : DateFormat.yMMMd(locale).format(value);

  static String dateTime(DateTime? value, String locale) =>
      value == null ? '' : DateFormat.yMMMd(locale).add_jm().format(value);

  /// Saudi Arabia has no daylight saving: Riyadh is UTC+3 all year.
  static const riyadhOffset = Duration(hours: 3);

  /// An evidence time (UTC, see `asUtcDate`) as Riyadh wall-clock time, so a
  /// signature reads the same on every device whatever its own zone.
  static DateTime? toRiyadh(DateTime? utc) {
    if (utc == null) return null;
    final u = utc.toUtc().add(riyadhOffset);
    return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
  }

  /// `dateTime` in Riyadh time, suffixed so the zone is never ambiguous.
  static String riyadh(DateTime? utc, String locale) {
    final local = toRiyadh(utc);
    if (local == null) return '';
    final zone = locale.startsWith('ar') ? 'بتوقيت الرياض' : 'Riyadh time';
    return '${DateFormat.yMMMd(locale).add_jm().format(local)} ($zone)';
  }

  static String short(DateTime? value, String locale) =>
      value == null ? '' : DateFormat.Md(locale).format(value);
}
