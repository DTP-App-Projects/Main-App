import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:digital_trade_portal/core/error/api_failure_ui.dart';
import 'package:digital_trade_portal/core/i18n/app_dates.dart';
import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/core/network/coerce.dart';
import 'package:digital_trade_portal/core/network/device_identity.dart';
import 'package:digital_trade_portal/data/models/compliance/acceptance.dart';
import 'package:digital_trade_portal/data/models/compliance/terms.dart';
import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// `terms_status` exactly as staging answered it on 2026-10-05 (trimmed to
/// one document per scope).
const _termsStatusLive = {
  'acceptance_required': false,
  'update_announced': true,
  'organization_id': 6,
  'documents': [
    {
      'terms_version_id': 1,
      'doc_key': 'platform_terms',
      'title': 'الشروط والأحكام العامة لمنصة وتطبيق التكامل التجاري الرقمي',
      'label': 'الشروط والأحكام العامة',
      'version': 1.1,
      'body_hash': 'd385',
      'published_at': '2026-10-05T17:45:14+03:00',
      'effective_at': '2026-10-12T17:45:14+03:00',
      'in_force': false,
      'scope': 'user',
      'accepted': false,
      'can_accept': true,
    },
    {
      'terms_version_id': 3,
      'doc_key': 'joining_trader',
      'title': 'اتفاقية انضمام واستخدام المنصة — التاجر/المشتري',
      'label': 'اتفاقية انضمام التاجر',
      'version': 1.3,
      'published_at': '2026-10-05T17:45:14+03:00',
      'effective_at': '2026-10-01T09:00:00+03:00',
      'in_force': true,
      'scope': 'organization',
      'accepted': false,
      'can_accept': false,
    },
  ],
};

void main() {
  setUp(() async => useFakeStorage());

  group('device id', () {
    test('is a v4 UUID, minted once and then stable', () async {
      final first = await DeviceIdentity.ensure();
      final second = await DeviceIdentity.ensure();
      expect(first, second);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(first),
        isTrue,
      );
    });

    test('rides on every request, v1 and v2, read and write', () async {
      final id = await DeviceIdentity.ensure();
      final (client, adapter) = clientWith(FakeAdapter.json(const {'ok': 1}));
      await client.get<Object?>('/countries', parse: (b) => b);
      await client.patch<Object?>('/v2/purchase_orders/1/status', body: const {'status': 'accepted'});
      for (final request in adapter.requests) {
        expect(request.headers['X-Device-Id'], id);
      }
    });
  });

  group('error mapping', () {
    test('a 422 business rule keeps its code, its localized message and its context', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {
        'msg': 'credit_limit_exceeded',
        'message': 'تجاوز الحد الائتماني',
        'available': 1200,
      }, status: 422));
      final result = await client.patch<Object?>('/v2/purchase_orders/1/status');

      expect(result, isA<Failed<Object?>>());
      final failed = result as Failed<Object?>;
      expect(failed.code, 'credit_limit_exceeded');
      expect(failed.status, 422);
      expect(failed.message, 'تجاوز الحد الائتماني');
      expect(failed.details?['available'], 1200);
      // Logic branches on the code; the user reads the server's sentence.
      expect(result.failureCode, 'credit_limit_exceeded');
      expect(result.failureMessage, 'تجاوز الحد الائتماني');
    });

    test('Laravel\'s own `message` without a `msg` code is never user copy', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {'message': 'Server Error'}, status: 405));
      final result = await client.get<Object?>('/v2/x', parse: (b) => b) as Failed<Object?>;
      expect(result.message, isNull);
    });

    test('wallet_disabled arrives as a Failed the wallet can branch on', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {
        'msg': 'wallet_disabled',
        'message': 'The wallet is not available.',
      }, status: 404));
      final result = await client.get<Object?>('/v2/wallet', parse: (b) => b);
      expect(result.failureCode, 'wallet_disabled');
    });
  });

  group('relationship request decision', () {
    test('a rejection sends its reason as `note`', () async {
      // Live: `decision_note` is refused with `bag.note: [reason_required]`.
      final (client, adapter) = clientWith(FakeAdapter.json(const {'msg': 'relationship_request_rejected'}));

      await ComplianceRepository(client).decideRelationshipRequest(6, status: 'rejected', note: 'No capacity');
      final body = adapter.requests.single.data as Map;

      expect(body['status'], 'rejected');
      expect(body['note'], 'No capacity');
      expect(body.containsKey('decision_note'), isFalse);
    });
  });

  group('terms gate', () {
    ResponseBody gated() => jsonBody(const {
          'msg': 'terms_acceptance_required',
          'message': 'يجب قبول الشروط',
          'terms': {'documents': []},
        }, status: 409);

    test('a write refused with 409 opens the gate once and is replayed after acceptance', () async {
      var calls = 0;
      final (client, adapter) = clientWith(FakeAdapter((_) async {
        calls++;
        return calls == 1 ? gated() : jsonBody(const {'ok': true});
      }));
      Failed<Object?>? seen;
      client.onTermsRequired = (rejection) async {
        seen = rejection;
        return true;
      };

      final result = await client.post<Object?>('/v2/quotations', body: const {'a': 1}, parse: (b) => b);

      expect(result, isA<Ok<Object?>>());
      expect(adapter.requests, hasLength(2));
      expect(seen?.message, 'يجب قبول الشروط');
      expect(seen?.details?['terms'], isA<Map>());
    });

    test('declining leaves the 409 for the caller to show', () async {
      final (client, adapter) = clientWith(FakeAdapter((_) async => gated()));
      client.onTermsRequired = (_) async => false;
      final result = await client.post<Object?>('/v2/quotations');
      expect(result.failureCode, 'terms_acceptance_required');
      expect(adapter.requests, hasLength(1));
    });

    test('reads are never gated client-side', () async {
      final (client, _) = clientWith(FakeAdapter((_) async => gated()));
      var opened = false;
      client.onTermsRequired = (_) async => opened = true;
      await client.get<Object?>('/v2/quotations', parse: (b) => b);
      expect(opened, isFalse);
    });

    test('writes blocked together share one terms screen', () async {
      final (client, _) = clientWith(FakeAdapter((_) async => gated()));
      var screens = 0;
      client.onTermsRequired = (_) async {
        screens++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return false;
      };
      await Future.wait([client.post<Object?>('/v2/a'), client.post<Object?>('/v2/b')]);
      expect(screens, 1);
    });

    test('a multipart write is replayed with a fresh FormData', () async {
      var calls = 0;
      final (client, adapter) = clientWith(FakeAdapter((_) async {
        calls++;
        return calls == 1 ? gated() : jsonBody(const {'ok': true});
      }));
      client.onTermsRequired = (_) async => true;
      final form = FormData.fromMap({'declaration_accepted': 1});
      final result = await client.multipart<Object?>('/v2/goods_receipts/1/confirmation', form: form, parse: (b) => b);
      expect(result, isA<Ok<Object?>>());
      expect(identical(adapter.requests[0].data, adapter.requests[1].data), isFalse);
    });
  });

  group('terms models (live shapes)', () {
    test('terms_status splits pending from upcoming and keeps the signatory rule', () {
      final status = TermsStatus.fromJson(_termsStatusLive);
      expect(status.updateAnnounced, isTrue);
      expect(status.documents, hasLength(2));
      expect(status.upcoming.single.docKey, 'platform_terms');
      expect(status.upcoming.single.version, '1.1');
      final joining = status.pending.single;
      expect(joining.isOrganizationScope, isTrue);
      expect(joining.canAccept, isFalse);
      expect(joining.effectiveAt, DateTime.utc(2026, 10, 1, 6));
    });

    test('accept posts the ids with confirm=1', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      await ComplianceRepository(client).acceptTerms(const [1, 3]);
      expect(adapter.requests.single.data, {'terms_version_ids': [1, 3], 'confirm': 1});
    });

    test('an acceptance challenge reads the documented fields', () {
      final c = AcceptanceChallenge.fromJson(const {
        'challenge_id': 9,
        'channel': 'sms',
        'destination': '05•••••12',
        'expires_at': '2026-10-05 14:10:00',
      });
      expect(c.id, 9);
      expect(c.destination, '05•••••12');
      expect(c.expiresAt, DateTime.utc(2026, 10, 5, 11, 10));
    });
  });

  group('evidence times', () {
    test('an offset-less time is Riyadh wall time, as the server renders it', () {
      // MK assignment accepted at 16:11:44 UTC came back as "19:11:44".
      final utc = asUtcDate('2026-10-05 19:11:44');
      expect(utc, DateTime.utc(2026, 10, 5, 16, 11, 44));
      expect(AppDates.toRiyadh(utc), DateTime(2026, 10, 5, 19, 11, 44));
    });

    test('UTC offsets from the acceptance log land on the same instant', () {
      expect(asUtcDate('2026-10-05T16:09:16+00:00'), DateTime.utc(2026, 10, 5, 16, 9, 16));
    });

    test('an explicit offset is honoured', () {
      expect(asUtcDate('2026-10-12T17:45:14+03:00'), DateTime.utc(2026, 10, 12, 14, 45, 14));
    });
  });

  group('binary download', () {
    test('a PDF comes back as bytes; a JSON error as a Failed', () async {
      final pdf = Uint8List.fromList('%PDF-1.4'.codeUnits);
      final (client, _) = clientWith(FakeAdapter((options) async {
        if (options.path.endsWith('/pdf')) {
          return ResponseBody.fromBytes(pdf, 200, headers: {
            Headers.contentTypeHeader: ['application/pdf'],
          });
        }
        return jsonBody(const {'msg': 'invoice_not_found', 'message': 'غير موجودة'}, status: 404);
      }));
      final ok = await client.bytes('/v2/invoices/1/pdf');
      expect((ok as Ok<Uint8List>).data, pdf);
      final missing = await client.bytes('/v2/invoices/2/file');
      expect(missing.failureCode, 'invoice_not_found');
    });
  });
}
