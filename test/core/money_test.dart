import 'package:digital_trade_portal/core/i18n/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  group('Money arithmetic', () {
    test('stays exact where double does not', () {
      // 0.1 + 0.2 != 0.3 in binary floating point; an invoice one halala out
      // is an invoice someone argues about.
      final sum = Money.fromMajor(0.1) + Money.fromMajor(0.2);
      expect(sum.minorUnits, 30);
      expect(sum, Money.fromMajor(0.3));
    });

    test('a line total is quantity times unit price, exactly', () {
      final line = Money.fromMajor(19.99) * 3;
      expect(line.minorUnits, 5997);
      expect(line.major, 59.97);
    });

    test('rounds the major-unit value the API sends to the nearest minor unit', () {
      expect(Money.fromMajor(1380.0).minorUnits, 138000);
      expect(Money.fromMajor(0.005).minorUnits, 1);
    });

    test('subtraction can go negative for a credit note', () {
      final credit = Money.fromMajor(100) - Money.fromMajor(250);
      expect(credit.isNegative, isTrue);
      expect(credit.major, -150);
    });

    test('equality and ordering are by minor units', () {
      expect(Money.fromMajor(5) == const Money(500), isTrue);
      expect(Money.fromMajor(5).compareTo(Money.fromMajor(7)), lessThan(0));
      expect(Money.zero.isZero, isTrue);
    });

    test('mixing currencies trips an assert rather than summing nonsense', () {
      expect(
        () => const Money(100) + const Money(100, currency: 'USD'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('formatting', () {
    test('shows two decimals and the currency', () {
      final en = AppMoney.format(1380, locale: 'en');
      expect(en, contains('1,380.00'));
      expect(en, contains('SAR'));
    });

    test('uses the Arabic currency mark in Arabic', () {
      expect(AppMoney.format(1380, locale: 'ar'), contains('ر.س'));
    });

    test('a non-default currency keeps its own code', () {
      expect(AppMoney.format(50, currency: 'USD', locale: 'en'), contains('USD'));
    });

    test('plain drops the symbol for table columns', () {
      final plain = AppMoney.plain(1380, locale: 'en');
      expect(plain, '1,380.00');
      expect(plain, isNot(contains('SAR')));
    });
  });
}
