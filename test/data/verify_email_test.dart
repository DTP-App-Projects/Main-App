import 'package:dio/dio.dart';
import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/core/network/response_normalizer.dart';
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_state.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/ui/form_status.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/auth/auth_user.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/view_models/login_cubit.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/view_models/register_owner_cubit.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/view_models/verify_email_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Sign-up email confirmation (server change of 2026-10-06).
void main() {
  setUp(() async => useFakeStorage());

  Future<SessionStore> freshStore() async {
    final store = SessionStore();
    await store.restore();
    return store;
  }

  (SessionCubit, PushService) sessionFor(dynamic client, SessionStore store) {
    final bootstrap = BootstrapRepository(client);
    final push = PushService(AuthRepository(client), bootstrap, store);
    final session = SessionCubit(
      store,
      bootstrap,
      WorkspaceCubit(store, OpsRepository(client)),
      push,
    );
    return (session, push);
  }

  const challengeBody = {
    'msg': 'email_verification_required',
    'error': 'email_verification_required',
    'message': 'أرسلنا رمز التحقق إلى بريدك الإلكتروني.',
    'email': 'owner@example.com',
    'code_sent': true,
    'expires_in': 600,
  };

  group('the error shape', () {
    ApiResult<void> normalize(int status, dynamic body) => ResponseNormalizer.normalize<void>(
      status: status,
      body: body,
      headers: Headers(),
      parse: null,
    );

    test('a translated `msg` takes its code from `error`', () {
      final result = normalize(422, const {'msg': 'الرمز غير صحيح', 'error': 'invalid_code'});

      expect(result, isA<Failed<void>>());
      final failed = result as Failed<void>;
      expect(failed.code, 'invalid_code');
      expect(failed.message, 'الرمز غير صحيح');
    });

    test('a coded `msg` is unchanged', () {
      final failed =
          normalize(422, const {'msg': 'not_pending', 'error': 'not_pending'}) as Failed<void>;
      expect(failed.code, 'not_pending');
      expect(failed.message, isNull, reason: 'a code is never shown as text');
    });

    test('resend_too_soon restarts the countdown from retry_after', () {
      final result = normalize(429, const {'error': 'resend_too_soon', 'retry_after': 42});
      expect((result as RateLimited<void>).retryAfter, const Duration(seconds: 42));
    });

    test("the limiter's own 429 with an HTML body does not crash", () {
      final result = normalize(429, '<html>Too Many Requests</html>');
      expect((result as RateLimited<void>).retryAfter, const Duration(seconds: 60));
    });
  });

  group('sign-up', () {
    test('sends verify_email=1 and reads the challenge, not a session', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(challengeBody));

      final result = await AuthRepository(client).registerOwner(
        businessMode: 'trader',
        firstName: 'A',
        lastName: 'B',
        organizationName: 'C',
        email: 'owner@example.com',
        password: 'secret123',
        fcmToken: 'tok',
        countryId: 1,
        cityId: 2,
        activityType: 'retailer',
      );
      final body = adapter.requests.single.data as Map;

      expect(body['verify_email'], 1);
      final data = result.dataOrNull!;
      expect(data.user.hasSession, isFalse);
      expect(data.verification?.email, 'owner@example.com');
      expect(data.verification?.codeSent, isTrue);
    });

    test('the cubit hands over the challenge and saves no session', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter((options) async {
          if (options.path.endsWith('/terms')) {
            return jsonBody(const {'text': '<p>t</p>', 'terms_version_id': 1, 'version': 1.1});
          }
          return jsonBody(challengeBody);
        }),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = RegisterOwnerCubit(AuthRepository(client), session, push);
      await cubit.loadTerms();
      cubit.setTermsAccepted(true);

      await cubit.submit(
        firstName: 'a',
        lastName: 'b',
        organizationName: 'c',
        email: 'owner@example.com',
        password: 'secret123',
        countryId: 1,
        cityId: 2,
        address: 'x',
      );

      expect(cubit.state.verification?.email, 'owner@example.com');
      expect(store.hasSession, isFalse);
      expect(session.state.status, isNot(SessionStatus.authenticated));
      await cubit.close();
    });
  });

  group('login of an unconfirmed account', () {
    test('403 email_verification_required opens the Confirm screen, no logout', () async {
      final store = await freshStore();
      final (client, _) = clientWith(FakeAdapter.json(challengeBody, status: 403));
      final (session, push) = sessionFor(client, store);
      final cubit = LoginCubit(AuthRepository(client), session, push);

      await cubit.submit(email: 'owner@example.com', password: 'secret123');

      expect(cubit.state.message, isNull, reason: 'not shown as an error');
      final challenge = cubit.takeVerification();
      expect(challenge?.email, 'owner@example.com');
      expect(cubit.takeVerification(), isNull, reason: 'handed over once');
      expect(
        session.state.status,
        isNot(SessionStatus.unauthenticated),
        reason: 'not treated as an expired session',
      );
      await cubit.close();
    });

    test('the email_verify_pending code opens the Confirm screen too', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'msg': 'email_verify_pending',
          'email': 'owner@example.com',
        }, status: 403),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = LoginCubit(AuthRepository(client), session, push);

      await cubit.submit(email: 'owner@example.com', password: 'secret123');

      expect(cubit.state.message, isNull);
      expect(cubit.takeVerification()?.email, 'owner@example.com');
      await cubit.close();
    });

    test('email_verify_pending: true on a 200 opens the Confirm screen, no session', () async {
      for (final body in const [
        {
          'user': {
            'id': 9,
            'jwt': 'a.b.c',
            'email': 'owner@example.com',
            'email_verify_pending': true,
          },
        },
        {
          'email_verify_pending': true,
          'user': {'id': 9, 'jwt': 'a.b.c', 'email': 'owner@example.com'},
        },
      ]) {
        final store = await freshStore();
        final (client, _) = clientWith(FakeAdapter.json(body));
        final (session, push) = sessionFor(client, store);
        final cubit = LoginCubit(AuthRepository(client), session, push);

        await cubit.submit(email: 'owner@example.com', password: 'secret123');

        expect(cubit.takeVerification()?.email, 'owner@example.com');
        expect(store.jwt, anyOf(isNull, isEmpty), reason: 'the jwt is not kept');
        await cubit.close();
      }
    });

    test('email_verify_pending: false is a normal login', () {
      expect(EmailVerificationChallenge.matches(const {'email_verify_pending': false}), isFalse);
      expect(EmailVerificationChallenge.matches(const {'email_verify_pending': 1}), isTrue);
    });
  });

  group('the Confirm email screen', () {
    const challenge = EmailVerificationChallenge(email: 'owner@example.com');

    test('Arabic-Indic digits and spaces become a plain 6-digit code', () {
      expect(VerifyEmailCubit.normalizeCode(' ١٢٣ ٤٥٦ '), '123456');
      expect(VerifyEmailCubit.normalizeCode('۱۲۳456'), '123456');
    });

    test('sends email, code and the device token fields', () async {
      final store = await freshStore();
      final (client, adapter) = clientWith(
        FakeAdapter.json(const {'msg': 'الرمز غير صحيح', 'error': 'invalid_code'}, status: 422),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(AuthRepository(client), session, push, challenge);

      await cubit.verify('١٢٣٤٥٦');
      final body = adapter.requests.single.data as Map;

      expect(body['email'], 'owner@example.com');
      expect(body['code'], '123456');
      expect(body.containsKey('token'), isTrue);
      expect(body.containsKey('fcm_token'), isTrue);
      await cubit.close();
    });

    test('a wrong code shows the error, clears the field, allows a retry', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {'msg': 'الرمز غير صحيح', 'error': 'invalid_code'}, status: 422),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(AuthRepository(client), session, push, challenge);

      await cubit.verify('000000');

      expect(cubit.state.submit.status, FormStatus.failure);
      expect(cubit.state.submit.message, isNotNull);
      expect(cubit.state.clearTick, 1);
      expect(cubit.state.submit.isSubmitting, isFalse);
      await cubit.close();
    });

    test('not_pending sends the user to login', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {'msg': 'not_pending', 'error': 'not_pending'}, status: 422),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(AuthRepository(client), session, push, challenge);

      await cubit.verify('123456');

      expect(cubit.state.alreadyConfirmed, isTrue);
      await cubit.close();
    });

    test('the right code saves the session exactly like a login', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter((options) async {
          if (options.path.contains('email/verify')) {
            return jsonBody(const {
              'user': {'id': 7, 'jwt': 'fresh-jwt'},
            });
          }
          // The bootstrap a login triggers.
          return jsonBody(const {
            'user': {'id': 7},
            'organizations': [
              {'id': 3, 'business_mode': 'trader', 'status': 'draft'},
            ],
          });
        }),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(AuthRepository(client), session, push, challenge);

      await cubit.verify('123456');

      expect(store.jwt, 'fresh-jwt');
      expect(session.state.status, SessionStatus.authenticated);
      await cubit.close();
    });

    test('Resend waits 60 s, and resend_too_soon restarts from retry_after', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {'error': 'resend_too_soon', 'retry_after': 42}, status: 429),
      );
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(AuthRepository(client), session, push, challenge);

      expect(cubit.state.resendIn, 60, reason: 'a code was just sent');
      expect(cubit.state.canResend, isFalse);

      // Pretend the minute passed on our side but not on the server's.
      cubit.emit(cubit.state.copyWith(resendIn: 0));
      await cubit.resend();

      expect(cubit.state.resendIn, 42);
      await cubit.close();
    });

    test('a code that could not be sent leaves Resend enabled at once', () async {
      final store = await freshStore();
      final (client, _) = clientWith(FakeAdapter.json(const {}));
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(
        AuthRepository(client),
        session,
        push,
        const EmailVerificationChallenge(
          email: 'owner@example.com',
          codeSent: false,
          message: 'تعذر إرسال رمز التحقق. حاول مرة أخرى.',
        ),
      );

      expect(cubit.state.canResend, isTrue);
      expect(cubit.state.submit.message, 'تعذر إرسال رمز التحقق. حاول مرة أخرى.');
      await cubit.close();
    });

    test('a resent code shows its message and restarts the countdown', () async {
      final store = await freshStore();
      final (client, _) = clientWith(FakeAdapter.json(challengeBody));
      final (session, push) = sessionFor(client, store);
      final cubit = VerifyEmailCubit(AuthRepository(client), session, push, challenge);
      cubit.emit(cubit.state.copyWith(resendIn: 0));

      await cubit.resend();

      expect(cubit.state.notice, 'أرسلنا رمز التحقق إلى بريدك الإلكتروني.');
      expect(cubit.state.resendIn, 60);
      await cubit.close();
    });
  });
}
