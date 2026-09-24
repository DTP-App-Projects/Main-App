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

  static String short(DateTime? value, String locale) =>
      value == null ? '' : DateFormat.Md(locale).format(value);
}
