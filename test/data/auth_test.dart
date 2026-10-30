
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/core/ui/form_status.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/view_models/password_reset_cubit.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/view_models/register_owner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

void main() {
  setUp(() async => useFakeStorage());

  /// A restored store, the way the app builds one at cold start.
  Future<SessionStore> freshStore() async {
    final store = SessionStore();
    await store.restore();
    return store;
  }

  group('the borrowed reset token never outlives the flow', () {
    test('verifying a code authenticates the next request without signing in',
        () async {
      final store = await freshStore();
      // The store *is* the client's AuthContext here, so whatever it holds is
      // what the interceptor sends.
      final (client, adapter) = clientWith(
        FakeAdapter.json(const {
          'user': {'id': 7, 'jwt': 'borrowed-token'},
        }),
        context: store,
      );

      final repo = AuthRepository(client);
      final cubit = PasswordResetCubit(repo, store);
      await cubit.verifyCode('123456');

      expect(cubit.state.step, ResetStep.choose);
      // ...but nobody is signed in. `hasSession` only asks whether a token is
      // present, so it cannot answer this; the absence of a `userId` is what
      // distinguishes a borrowed token from an earned session, and it is what
      // `useEphemeralJwt` guards on.
      expect(store.userId, isNull);

      // Step three has to go out authenticated with the borrowed token.
      await repo.resetPassword('new-secret-123');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer borrowed-token',
      );
    });

    test('nothing is written to storage, so a cold start does not restore it',
        () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'user': {'id': 7, 'jwt': 'borrowed-token'},
        }),
      );

      await PasswordResetCubit(AuthRepository(client), store).verifyCode('123456');

      // This is the bug the refactor fixes: `saveSession` used to persist the
      // borrowed token, so abandoning the flow at "choose a new password"
      // left a live session for the next launch to pick up — with the old
      // password still working.
      final fresh = await freshStore();
      expect(fresh.jwt, isNull);
      expect(fresh.hasSession, isFalse);
    });

    test('closing the cubit hands the token back', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'user': {'id': 7, 'jwt': 'borrowed-token'},
        }),
      );

      final cubit = PasswordResetCubit(AuthRepository(client), store);
      await cubit.verifyCode('123456');
      expect(store.jwt, isNotNull);

      // Leaving the screen is the abandon path the old code had no answer for.
      await cubit.close();
      expect(store.jwt, isNull);
    });

    test('a 200 with no jwt is not a verified code', () async {
      final store = await freshStore();
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'user': {'id': 7},
        }),
      );

      final cubit = PasswordResetCubit(AuthRepository(client), store);
      await cubit.verifyCode('123456');

      // It must not advance, and it must not borrow a token it did not get.
      expect(cubit.state.step, isNot(ResetStep.choose));
      expect(cubit.state.submit.status, FormStatus.failure);
      expect(store.jwt, isNull);
    });

    test('an earned session cannot be displaced by a borrowed one', () async {
      final store = await freshStore();
      await store.saveSession(jwt: 'real-token', userId: 3);

      store.useEphemeralJwt('borrowed-token');
      expect(store.jwt, 'real-token');

      // And the ephemeral clear must not log a real user out.
      store.clearEphemeralJwt();
      expect(store.jwt, 'real-token');
    });
  });

  group('resend', () {
    test('a sent code starts a cooldown, and resend is blocked until it ends',
        () async {
      final store = await freshStore();
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final cubit = PasswordResetCubit(AuthRepository(client), store);

      await cubit.requestCode(' owner@example.com ');

      expect(cubit.state.step, ResetStep.verify);
      // Trimmed, and kept, so resending does not send the user back a step to
      // retype the address.
      expect(cubit.state.email, 'owner@example.com');
      expect(cubit.state.resendIn, greaterThan(0));
      expect(cubit.state.canResend, isFalse);

      await cubit.resendCode();
      expect(adapter.requests, hasLength(1), reason: 'the server throttles 6/min');

      await cubit.close();
    });
  });

  group('register', () {
    test('the step is cubit state, and back reports whether it moved', () async {
      final (client, _) = clientWith(FakeAdapter.json(const []));
      final store = await freshStore();
      final bootstrap = BootstrapRepository(client);
      final cubit = RegisterOwnerCubit(
        AuthRepository(client),
        SessionCubit(
          store,
          bootstrap,
          WorkspaceCubit(store, OpsRepository(client)),
          PushService(AuthRepository(client), bootstrap, store),
        ),
        PushService(AuthRepository(client), bootstrap, store),
      );

      expect(cubit.state.step, RegisterStep.mode);
      // At the first step there is nothing to go back to, so the view lets
      // the pop through rather than swallowing it.
      expect(cubit.back(), isFalse);

      // The website's four steps, in order, and back retraces them.
      cubit.next();
      expect(cubit.state.step, RegisterStep.owner);
      cubit.next();
      expect(cubit.state.step, RegisterStep.organization);
      cubit.next();
      expect(cubit.state.step, RegisterStep.terms);
      cubit.next();
      expect(cubit.state.step, RegisterStep.terms, reason: 'nothing after the last step');
      expect(cubit.back(), isTrue);
      expect(cubit.state.step, RegisterStep.organization);
      cubit
        ..back()
        ..back();
      expect(cubit.state.step, RegisterStep.mode);
    });

    test('whatsapp reaches the request', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'user': {}}));

      await AuthRepository(client).registerOwner(
        businessMode: 'hybrid',
        firstName: 'A',
        lastName: 'B',
        organizationName: 'C',
        email: 'a@b.co',
        password: 'secret123',
        fcmToken: 'tok',
        countryId: 1,
        cityId: 2,
        whatsapp: '0501234567',
        activityType: 'factory',
      );
      final body = adapter.requests.single.data as Map;

      // The parameter existed all along; the form never collected it.
      expect(body['whatsapp'], '0501234567');
      expect(body.containsKey('phone'), isFalse, reason: 'empty stays out');
    });

    test('sign-up carries activity_type and the terms acceptance', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'user': {}}));

      await AuthRepository(client).registerOwner(
        businessMode: 'trader',
        firstName: 'A',
        lastName: 'B',
        organizationName: 'C',
        email: 'a@b.co',
        password: 'secret123',
        fcmToken: 'tok',
        countryId: 1,
        cityId: 2,
        activityType: 'marketer',
        acceptedTermsVersionIds: const [1],
      );
      final body = adapter.requests.single.data as Map;

      expect(body['activity_type'], 'marketer');
      expect(body['accept_terms'], 1);
      expect(body['accepted_terms_version_ids'], [1]);
    });

    test("409 terms_version_outdated: show the server's list, re-tick, resend every id", () async {
      var calls = 0;
      final (client, adapter) = clientWith(FakeAdapter((options) async {
        if (options.path.endsWith('/terms')) {
          return jsonBody(const {'text': '<p>t</p>', 'terms_version_id': 1, 'version': 1.1});
        }
        calls++;
        // Live answer when only the platform terms were sent (2026-10-05).
        return calls == 1
            ? jsonBody(const {
                'msg': 'terms_version_outdated',
                'message': 'A newer version of this document exists.',
                'terms_versions': [
                  {'terms_version_id': 1, 'doc_key': 'platform_terms', 'version': 1.1, 'title': 'الشروط'},
                  {'terms_version_id': 5, 'doc_key': 'joining_marketer', 'version': 1.3, 'title': 'اتفاقية المسوّق'},
                ],
              }, status: 409)
            : jsonBody(const {'msg': 'validation_error', 'bag': {'email': ['taken']}}, status: 400);
      }));
      final store = await freshStore();
      final bootstrap = BootstrapRepository(client);
      final push = PushService(AuthRepository(client), bootstrap, store);
      final cubit = RegisterOwnerCubit(
        AuthRepository(client),
        SessionCubit(store, bootstrap, WorkspaceCubit(store, OpsRepository(client)), push),
        push,
      );
      await cubit.loadTerms();
      cubit
        ..chooseActivity('marketer')
        ..setTermsAccepted(true);

      Future<void> submit() => cubit.submit(
            firstName: 'a', lastName: 'b', organizationName: 'c', email: 'a@b.co',
            password: 'secret123', countryId: 1, cityId: 2, address: 'x',
          );

      await submit();
      expect(cubit.state.termsAccepted, isFalse, reason: 'the user re-ticks for the full set');
      expect(cubit.state.requiredTerms.map((v) => v.id), [1, 5]);
      Map<String, dynamic> lastBody() => adapter.requests.where((r) => r.path.contains('register_owner')).last.data as Map<String, dynamic>;
      expect(lastBody()['accepted_terms_version_ids'], [1]);

      cubit.setTermsAccepted(true);
      await submit();
      expect(lastBody()['accepted_terms_version_ids'], [1, 5]);
      expect(lastBody()['activity_type'], 'marketer');
      // The 400 names `email`, which lives on the owner step.
      expect(cubit.state.step, RegisterStep.owner);
    });

    test('a mode selects its first activity, as on the website', () async {
      final (client, _) = clientWith(FakeAdapter.json(const []));
      final store = await freshStore();
      final bootstrap = BootstrapRepository(client);
      final push = PushService(AuthRepository(client), bootstrap, store);
      final cubit = RegisterOwnerCubit(
        AuthRepository(client),
        SessionCubit(store, bootstrap, WorkspaceCubit(store, OpsRepository(client)), push),
        push,
      );
      expect(cubit.state.businessMode, 'trader');
      expect(cubit.state.activityType, 'retailer');

      // A marketer is a trader-mode activity (spec §11).
      cubit.chooseActivity('marketer');
      expect(cubit.state.activityType, 'marketer');

      cubit.chooseMode('supplier');
      expect(cubit.state.activityType, 'factory');
      expect(ActivityType.forMode('supplier'), ['factory', 'supplier_trader']);
      cubit.chooseMode('trader');
      expect(cubit.state.activityType, 'retailer');
    });
  });
}

