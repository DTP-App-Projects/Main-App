import 'package:intl/intl.dart';

/// Money handling, with one rule above the others: **never re-derive a total
/// the server already sent.** `subtotal`, `tax_total` and `grand_total` are
/// displayed as given.
///
/// When the client genuinely has to do arithmetic — a draft line's quantity
/// times its resolved price — it happens in [Money], in integer minor units,
/// never in `double`.
class AppMoney {
  AppMoney._();

  static const defaultCurrency = 'SAR';

  /// Formats for display. [amount] is the major-unit value the API sends.
  static String format(
    num amount, {
    String currency = defaultCurrency,
    required String locale,
    bool showSymbol = true,
  }) {
    final format = NumberFormat.currency(
      locale: locale,
      name: currency,
      symbol: showSymbol ? _symbolFor(currency, locale) : '',
      decimalDigits: 2,
    );
    return format.format(amount).trim();
  }

  /// A bare number, for table columns where the currency is in the header.
  static String plain(num amount, {required String locale}) =>
      NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2).format(amount);

  static String _symbolFor(String currency, String locale) {
    if (currency != defaultCurrency) return '$currency ';
    return locale.startsWith('ar') ? 'ر.س ' : 'SAR ';
  }
}

/// An exact amount in integer minor units (halalas for SAR).
///
/// `0.1 + 0.2` in `double` is not `0.3`, and an invoice that is one halala
/// out is an invoice a supplier will argue about.
class Money implements Comparable<Money> {
  final int minorUnits;
  final String currency;

  const Money(this.minorUnits, {this.currency = AppMoney.defaultCurrency});

  /// From the major-unit number the API sends (`1380.0`).
  factory Money.fromMajor(num amount, {String currency = AppMoney.defaultCurrency}) =>
      Money((amount * 100).round(), currency: currency);

  /// From the 2-decimal string the newer endpoints send (`"38250.00"`),
  /// parsed digit by digit so no amount passes through a `double`. A number
  /// on the wire (older endpoints) goes through [Money.fromMajor].
  factory Money.parse(dynamic raw, {String currency = AppMoney.defaultCurrency}) {
    if (raw is num) return Money.fromMajor(raw, currency: currency);
    final s = (raw ?? '').toString().trim().replaceAll(',', '');
    final match = RegExp(r'^(-?)(\d*)(?:\.(\d*))?$').firstMatch(s);
    if (match == null || (match[2]!.isEmpty && (match[3] ?? '').isEmpty)) {
      return Money(0, currency: currency);
    }
    final whole = int.parse(match[2]!.isEmpty ? '0' : match[2]!);
    final fraction = (match[3] ?? '').padRight(3, '0');
    // Half-up on the third decimal; the server already rounds to two.
    var minor = whole * 100 + int.parse(fraction.substring(0, 2));
    if (int.parse(fraction[2]) >= 5) minor += 1;
    return Money(match[1] == '-' ? -minor : minor, currency: currency);
  }

  static const zero = Money(0);

  double get major => minorUnits / 100;

  Money operator +(Money other) {
    _assertSame(other);
    return Money(minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _assertSame(other);
    return Money(minorUnits - other.minorUnits, currency: currency);
  }

  /// Quantities are whole units, so this stays exact.
  Money operator *(int quantity) => Money(minorUnits * quantity, currency: currency);

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  String format({required String locale}) =>
      AppMoney.format(major, currency: currency, locale: locale);

  @override
  int compareTo(Money other) {
    _assertSame(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _assertSame(Money other) {
    assert(other.currency == currency, 'Refusing to mix $currency with ${other.currency}.');
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits && other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '$currency ${major.toStringAsFixed(2)}';
}
