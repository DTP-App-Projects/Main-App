import 'package:digital_trade_portal/core/network/coerce.dart';
import 'package:digital_trade_portal/core/network/paged.dart';
import 'package:flutter_test/flutter_test.dart';

/// `JSON_NUMERIC_CHECK` and the `m_p` prefix are the two traps that silently
/// corrupt models. These are the guardrails.
void main() {
  group('asStr', () {
    test('reads a field the server turned into a number', () {
      // "0501234567" is encoded as 501234567 — declaring this String and
      // reading it directly is a runtime cast error.
      expect(asStr(501234567), '501234567');
      expect(asStr(12345), '12345');
    });

    test('null becomes empty, never "null"', () => expect(asStr(null), ''));
  });

  group('unwrap', () {
    test('strips the m_p guard the backend adds to free text', () {
      expect(unwrap('m_p0501234567'), '0501234567');
      expect(unwrap('m_p'), '');
    });

    test('leaves text that was never prefixed alone', () {
      expect(unwrap('Riyadh Branch'), 'Riyadh Branch');
      expect(unwrap(null), '');
    });
  });

  group('numbers', () {
    test('accept both the number and the string form', () {
      expect(asInt(7), 7);
      expect(asInt('7'), 7);
      expect(asInt(null), 0);
      expect(asNum(1380.0), 1380.0);
      expect(asNum('1380.5'), 1380.5);
    });

    test('asIntOrNull keeps "unset" distinguishable from zero', () {
      expect(asIntOrNull(null), isNull);
      expect(asIntOrNull(''), isNull);
      expect(asIntOrNull(0), 0);
    });
  });

  group('asBool', () {
    test('accepts every truthy encoding this API uses', () {
      for (final value in [true, 1, '1', 'true']) {
        expect(asBool(value), isTrue, reason: '$value should be true');
      }
      for (final value in [false, 0, '0', '', null]) {
        expect(asBool(value), isFalse, reason: '$value should be false');
      }
    });
  });

  group('asDate', () {
    test('parses "Y-m-d H:i:s" with no offset', () {
      expect(asDate('2026-09-19 12:00:00'), DateTime(2026, 9, 19, 12));
    });

    test('treats "" and null alike — both mean unset', () {
      expect(asDate(''), isNull);
      expect(asDate(null), isNull);
    });
  });

  group('pickLocalized', () {
    test('prefers the active locale', () {
      expect(pickLocalized(locale: 'ar', ar: 'فرع الرياض', en: 'Riyadh'), 'فرع الرياض');
      expect(pickLocalized(locale: 'en', ar: 'فرع الرياض', en: 'Riyadh'), 'Riyadh');
    });

    test('falls back to the other side when one is empty, like display_name', () {
      expect(pickLocalized(locale: 'en', ar: 'فرع الرياض', en: ''), 'فرع الرياض');
      expect(pickLocalized(locale: 'ar', ar: '', en: 'Riyadh'), 'Riyadh');
    });
  });

  group('Paged', () {
    const payload = {
      'current_page': 1,
      'data': [
        {
          'id': 91,
          'supplier_organization_id': 7,
          'created_at': '2026-09-19 12:00:00',
          'formatted': {'id': 91, 'code': 'PO-20260919-AB12CD34', 'status': 'approved'},
        },
        {
          'id': 92,
          'formatted': {'id': 92, 'code': 20260919, 'status': 'ready'},
        },
      ],
      'last_page': 3,
      'per_page': 15,
      'total': 41,
    };

    test('reads data[].formatted and ignores the raw model columns', () {
      final page = Paged.fromJson(
        payload,
        (row) => (id: asInt(row['id']), code: asStr(row['code'])),
      );

      expect(page.items.length, 2);
      expect(page.items.first.code, 'PO-20260919-AB12CD34');
      // A numeric-looking code arrives as a number; asStr is what saves it.
      expect(page.items.last.code, '20260919');
      expect(page.hasMore, isTrue);
      expect(page.total, 41);
    });

    test('append keeps the accumulated items and the newest page cursor', () {
      final first = Paged.fromJson(payload, (row) => asInt(row['id']));
      final second = Paged.fromJson(
        {...payload, 'current_page': 3},
        (row) => asInt(row['id']),
      );

      final combined = first.append(second);
      expect(combined.items.length, 4);
      expect(combined.currentPage, 3);
      expect(combined.hasMore, isFalse);
    });

    test('cursor pagination is its own type, not a paginator', () {
      final cursored = Cursored.fromJson(
        {
          'organization_id': 3,
          'items': [
            {'id': 1},
            {'id': 2},
          ],
          'has_more': true,
        },
        (row) => asInt(row['id']),
      );

      expect(cursored.items, [1, 2]);
      expect(cursored.hasMore, isTrue);
      expect(cursored.organizationId, 3);
    });

    test('notifications use per_page, most lists use limit', () {
      expect(PageParams.limit(2), {'page': 2, 'limit': 15});
      expect(PageParams.perPage(2), {'page': 2, 'per_page': 20});
      // The server caps per_page at 100.
      expect(PageParams.perPage(1, size: 500)['per_page'], 100);
    });
  });
}
