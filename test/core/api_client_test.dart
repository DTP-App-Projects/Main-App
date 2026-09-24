import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/core/network/coerce.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// The five proofs the brief asks for before a single screen is written, plus
/// the response shapes that are easy to mistake for success.
void main() {
  Future<ApiResult<Map<String, dynamic>>> call(FakeAdapter adapter) {
    final (client, _) = clientWith(adapter);
    return client.get<Map<String, dynamic>>(
      '/v2/bootstrap',
      parse: (body) => asMap(body),
    );
  }

  group('decision order', () {
    test('a keyed 200 object parses into Ok', () async {
      final result = await call(FakeAdapter.json({
        'user': {'id': 1},
      }));
      expect(result, isA<Ok<Map<String, dynamic>>>());
      expect((result as Ok).data['user'], isA<Map>());
    });

    test('an expired token is a 400 naming user_id, not a 401', () async {
      final result = await call(FakeAdapter.json(
        {
          'msg': 'validation_error',
          'bag': {
            'user_id': ['The user id field is invalid.'],
          },
        },
        status: 400,
      ));
      // The trap: this is the same status and the same `msg` as an ordinary
      // form error. Getting it wrong shows users "The user id field is
      // invalid" instead of a login screen.
      expect(result, isA<SessionExpired<Map<String, dynamic>>>());
    });

    test('an ordinary 400 validation_error becomes Invalid with its bag', () async {
      final result = await call(FakeAdapter.json(
        {
          'msg': 'validation_error',
          'bag': {
            'email': ['The email field is required.'],
            'password': ['The password field is required.'],
          },
        },
        status: 400,
      ));
      expect(result, isA<Invalid<Map<String, dynamic>>>());
      final invalid = result as Invalid<Map<String, dynamic>>;
      expect(invalid.bag.keys, containsAll(['email', 'password']));
      expect(invalid.first('email'), 'The email field is required.');
    });

    test('a wrong-workspace 403 is its own result, not a generic failure', () async {
      final result = await call(FakeAdapter.json(
        {'msg': 'organization_workspace_not_allowed'},
        status: 403,
      ));
      expect(result, isA<WrongWorkspace<Map<String, dynamic>>>());
    });

    test('permission_denied carries the permission the server named', () async {
      final result = await call(FakeAdapter.json(
        {'msg': 'permission_denied', 'permission': 'purchase_orders.manage'},
        status: 403,
      ));
      expect(result, isA<Failed<Map<String, dynamic>>>());
      final failed = result as Failed<Map<String, dynamic>>;
      expect(failed.code, 'permission_denied');
      expect(failed.permission, 'purchase_orders.manage');
    });

    test('a suspended login is a 200 that must not be treated as success', () async {
      final result = await call(
        FakeAdapter.json({'status': 'failed', 'msg': 'suspended user'}),
      );
      expect(result, isA<Failed<Map<String, dynamic>>>());
      final failed = result as Failed<Map<String, dynamic>>;
      expect(failed.code, 'suspended user');
      expect(failed.status, 200);
    });

    test('nafath_disabled arrives as a 200 too', () async {
      final result = await call(FakeAdapter.json({
        'msg': 'nafath_disabled',
        'nafath_enabled': false,
      }));
      expect(result, isA<Failed<Map<String, dynamic>>>());
      expect((result as Failed).code, 'nafath_disabled');
    });

    test('an empty 204 body is NoContent, never a parse attempt', () async {
      final result = await call(FakeAdapter.empty());
      expect(result, isA<NoContent<Map<String, dynamic>>>());
    });

    test('429 surfaces the Retry-After delay', () async {
      final result = await call(FakeAdapter.json(
        {'msg': 'Too Many Attempts.'},
        status: 429,
        headers: {
          'retry-after': ['45'],
        },
      ));
      expect(result, isA<RateLimited<Map<String, dynamic>>>());
      expect((result as RateLimited).retryAfter, const Duration(seconds: 45));
    });

    test('a 429 without Retry-After still backs off', () async {
      final result = await call(FakeAdapter.json({'msg': 'x'}, status: 429));
      expect((result as RateLimited).retryAfter, const Duration(seconds: 60));
    });

    test('no connectivity is Offline, distinct from an error', () async {
      final result = await call(FakeAdapter.offline());
      expect(result, isA<Offline<Map<String, dynamic>>>());
    });

    test('a 500 does not escape as an exception', () async {
      final result = await call(FakeAdapter.json({'msg': 'purchase_order_submit_failed'}, status: 500));
      expect(result, isA<Failed<Map<String, dynamic>>>());
      final failed = result as Failed<Map<String, dynamic>>;
      expect(failed.code, 'purchase_order_submit_failed');
      expect(failed.status, 500);
    });

    test('a body that cannot be parsed fails instead of throwing', () async {
      final (client, _) = clientWith(FakeAdapter.json({'user': 1}));
      final result = await client.get<int>(
        '/v2/bootstrap',
        parse: (body) => (body as Map)['missing'] as int,
      );
      expect(result, isA<Failed<int>>());
      expect((result as Failed).code, 'parse_error');
    });
  });

  group('session expiry hook', () {
    test('fires once so the app can drop the token and route to login', () async {
      final (client, _) = clientWith(FakeAdapter.json(
        {
          'msg': 'validation_error',
          'bag': {
            'user_id': ['invalid'],
          },
        },
        status: 400,
      ));
      var calls = 0;
      client.onSessionExpired = () => calls++;

      await client.get<void>('/v2/bootstrap', dedupe: false);
      expect(calls, 1);
    });
  });

  group('headers', () {
    test('X-Organization-Id goes on v2 paths only', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'ok': true}));

      await client.get<void>('/v2/bootstrap', dedupe: false);
      await client.get<void>('/countries', dedupe: false);

      expect(adapter.requests.first.headers['X-Organization-Id'], 3);
      expect(adapter.requests.last.headers.containsKey('X-Organization-Id'), isFalse);
    });

    test('one auth convention app-wide: Bearer, never a raw jwt header', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'ok': true}));
      await client.get<void>('/v2/bootstrap', dedupe: false);

      expect(adapter.requests.single.headers['Authorization'], 'Bearer test-jwt');
      expect(adapter.requests.single.headers.containsKey('jwt'), isFalse);
    });

    test('Accept-Language is sent on every request', () async {
      final (client, adapter) = clientWith(
        FakeAdapter.json({'ok': true}),
        context: FakeAuthContext(locale: 'en'),
      );
      await client.get<void>('/countries', dedupe: false);

      expect(adapter.requests.single.headers['Accept-Language'], 'en');
    });
  });

  group('request budget', () {
    test('identical in-flight GETs collapse into one request', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'ok': true}));

      // Two widgets asking for the same URL on the same frame. The global
      // limit is 60 requests/minute per IP, so this must not double.
      await Future.wait([
        client.get<Map<String, dynamic>>('/v2/bootstrap', parse: asMap),
        client.get<Map<String, dynamic>>('/v2/bootstrap', parse: asMap),
      ]);

      expect(adapter.requests.length, 1);
    });

    test('different query strings are different requests', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'ok': true}));

      await Future.wait([
        client.get<Map<String, dynamic>>('/v2/ops/panel',
            query: {'workspace': 'trader'}, parse: asMap),
        client.get<Map<String, dynamic>>('/v2/ops/panel',
            query: {'workspace': 'supplier'}, parse: asMap),
      ]);

      expect(adapter.requests.length, 2);
    });
  });
}
