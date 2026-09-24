import 'package:digital_trade_portal/core/network/api_client.dart';
import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/core/network/auth_context.dart';
import 'package:digital_trade_portal/core/network/coerce.dart';
import 'package:digital_trade_portal/data/api_paths.dart';
import 'package:digital_trade_portal/data/models/bootstrap/flags.dart';
import 'package:digital_trade_portal/data/models/common/country.dart';
import 'package:digital_trade_portal/data/models/shop/shop_product.dart';
import 'package:digital_trade_portal/data/repositories/shop_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hits the real backend. Skipped unless you ask for it:
///
///     flutter test test/live_smoke_test.dart --dart-define=LIVE=true
///
/// Everything else in `test/` runs against a fake transport, so the suite
/// stays offline-safe and fast.
const _live = bool.fromEnvironment('LIVE');

class _Anonymous implements AuthContext {
  @override
  final String? jwt;
  @override
  final int? organizationId = null;
  @override
  final String locale = 'en';

  const _Anonymous({this.jwt});
}

void main() {
  group('live backend', skip: _live ? null : 'pass --dart-define=LIVE=true to run', () {
    test('public v1: countries parse, including the numeric tax percentage', () async {
      final client = ApiClient.create(const _Anonymous());
      final result = await client.get<List<Country>>(
        ApiPaths.countries,
        parse: (body) => asList(body, Country.fromJson),
      );

      expect(result, isA<Ok<List<Country>>>());
      final countries = (result as Ok<List<Country>>).data;
      expect(countries, isNotEmpty);
      expect(countries.first.cities, isNotEmpty);
      expect(countries.first.currency, isNotEmpty);
    });

    test('public v2: platform flags come back as {flags, defaults}', () async {
      final client = ApiClient.create(const _Anonymous());
      final result = await client.get<PlatformFlagsResponse>(
        ApiPaths.platformFlags,
        parse: (body) => PlatformFlagsResponse.fromJson(asMap(body)),
      );

      expect(result, isA<Ok<PlatformFlagsResponse>>());
    });

    test('no token: bootstrap answers 400/bag.user_id and we read it as expiry',
        () async {
      final client = ApiClient.create(const _Anonymous());
      var expired = false;
      client.onSessionExpired = () => expired = true;

      final result = await client.get<void>(ApiPaths.bootstrap);

      // The live server really does return a validation error here, not a 401.
      expect(result, isA<SessionExpired<void>>());
      expect(expired, isTrue);
    });

    test('a garbage token is the same shape, not a 401', () async {
      final client = ApiClient.create(const _Anonymous(jwt: 'not-a-real-token'));
      final result = await client.get<void>(ApiPaths.bootstrap);
      expect(result, isA<SessionExpired<void>>());
    });

    test('v1 marketplace: the top of the category tree is public and parses',
        () async {
      final client = ApiClient.create(const _Anonymous());
      final result = await ShopRepository(client).categories();

      expect(result, isA<Ok<List<NamedCategory>>>());
      final categories = (result as Ok<List<NamedCategory>>).data;
      expect(categories, isNotEmpty);
      // Live rows carry `subs` but no `type`, so the drill-down decision has
      // to rest on `subs` alone — which is what `listsProducts` does.
      expect(categories.first.name, isNotEmpty);
      expect(categories.any((category) => !category.listsProducts), isTrue);
    });

    test('v1 marketplace: the rest of the shop needs a session, as an expiry',
        () async {
      // `/api/home` answers the same `400 bag.user_id` as v2 does, so an
      // anonymous shop screen routes through re-login, not a form error.
      final client = ApiClient.create(const _Anonymous());
      final result = await ShopRepository(client).home();

      expect(result, isA<SessionExpired<ShopHome>>());
    });

    test('empty login body returns a bag keyed by field name', () async {
      final client = ApiClient.create(const _Anonymous());
      final result = await client.post<void>(ApiPaths.login, body: const {});

      expect(result, isA<Invalid<void>>());
      final invalid = result as Invalid<void>;
      expect(invalid.bag.keys, containsAll(['email', 'password']));
    });
  });
}
