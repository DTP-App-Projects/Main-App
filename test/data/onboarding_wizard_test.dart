import 'package:digital_trade_portal/core/network/api_client.dart';
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/onboarding/onboarding_bootstrap.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/onboarding_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/onboarding_cubit.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/onboarding_form_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// The wizard is the app's heaviest reader and the request budget is 60 a
/// minute, so what it reads — and when — is behaviour worth pinning.
void main() {
  setUp(() async => useFakeStorage());

  /// Routes on path so a test can count which endpoints were hit.
  FakeAdapter routed() => FakeAdapter((options) async {
        final path = options.path;
        // The owner-console listings all answer under `items`.
        if (path.contains('branches')) {
          return jsonBody({
            'items': [
              {'id': 1, 'name_ar': 'فرع'},
            ],
          });
        }
        if (path.contains('bank_accounts') ||
            path.contains('documents') ||
            path.contains('lookups')) {
          return jsonBody({'items': <Map<String, dynamic>>[]});
        }
        // The onboarding bootstrap.
        return jsonBody({
          'organization': {
            'id': 3,
            'business_mode': 'trader',
            'legal_name_ar': 'شركة',
            'trade_name': 'Test',
            'country_id': 1,
            'city_id': 2,
          },
          'profiles': [
            {'id': 9, 'profile_type': 'trader', 'status': 'draft', 'notes': 'hi'},
          ],
        });
      });

  OnboardingCubit wizardWith(ApiClient client, SessionStore store) {
    final bootstrap = BootstrapRepository(client);
    return OnboardingCubit(
      OnboardingRepository(client),
      SessionCubit(
        store,
        bootstrap,
        WorkspaceCubit(store, OpsRepository(client)),
        PushService(AuthRepository(client), bootstrap, store),
      ),
    );
  }

  group('what a full load costs', () {
    test('four requests: the bootstrap plus one count per collection',
        () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final cubit = wizardWith(client, store);
      await cubit.load();

      expect(adapter.requests, hasLength(4));
      expect(cubit.state.status, OnboardingStatus.ready);
      expect(cubit.state.branchCount, 1);
      expect(cubit.state.bankAccountCount, 0);

      await cubit.close();
    });

    test('ready is not published until the counts are in', () async {
      // Step completeness is derived from the counts, so emitting `ready`
      // early rendered "To do" against finished work and flickered the
      // submit button enabled → disabled → enabled.
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(routed());

      final cubit = wizardWith(client, store);
      final seen = <OnboardingStatus>[];
      final sub = cubit.stream.listen((state) {
        if (state.status == OnboardingStatus.ready) {
          seen.add(state.status);
          // The first `ready` the UI ever sees already knows the counts.
          expect(state.branchCount, 1);
        }
      });

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1), reason: 'exactly one ready, not two');
      await sub.cancel();
      await cubit.close();
    });
  });

  group('what a change costs', () {
    test('backing out of a step without saving costs nothing', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final cubit = wizardWith(client, store);
      await cubit.load();
      adapter.requests.clear();

      // What the editor reports when it was dismissed. This used to reload
      // the whole wizard — four requests for looking at a screen.
      await cubit.applyChange(null);

      expect(adapter.requests, isEmpty);
      await cubit.close();
    });

    test('a saved collection re-reads only its own listing', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final cubit = wizardWith(client, store);
      await cubit.load();
      adapter.requests.clear();

      await cubit.applyChange(OnboardingStepKind.bankAccounts);

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, contains('bank_accounts'));
      await cubit.close();
    });

    test('a saved profile re-reads the bootstrap and nothing else', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final cubit = wizardWith(client, store);
      await cubit.load();
      adapter.requests.clear();

      await cubit.applyChange(OnboardingStepKind.traderProfile);

      // The organization and the profiles both live on the bootstrap, so one
      // call is already the cheapest read.
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, contains('onboarding/bootstrap'));
      await cubit.close();
    });

    test('a failed listing keeps the previous count rather than un-ticking',
        () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(routed());

      final cubit = wizardWith(client, store);
      await cubit.load();
      expect(cubit.state.branchCount, 1);

      // The network blinks on the next read.
      client.dio.httpClientAdapter = FakeAdapter.offline();
      await cubit.applyChange(OnboardingStepKind.branches);

      expect(cubit.state.branchCount, 1, reason: 'a blink is not a deletion');
      await cubit.close();
    });
  });

  group('the profile editor', () {
    test('a supplied profile saves the redundant bootstrap read', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final known = OnboardingProfile.fromJson(const {
        'id': 9,
        'profile_type': 'trader',
        'status': 'draft',
        'notes': 'hi',
      });

      final cubit = ProfileFormCubit(OnboardingRepository(client));
      await cubit.load('trader', known: known);

      // Sectors only — the wizard already had the profile in hand.
      expect(adapter.requests, hasLength(1));
      expect(cubit.state.existing?.id, 9);
      await cubit.close();
    });

    test('a deep link with no profile still finds it', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final cubit = ProfileFormCubit(OnboardingRepository(client));
      await cubit.load('trader');

      expect(adapter.requests, hasLength(2), reason: 'sectors, then bootstrap');
      expect(cubit.state.existing?.id, 9);
      await cubit.close();
    });
  });

  group('form state', () {
    test('a load error survives an unrelated copyWith', () {
      // It used to be a bare `loadError: loadError`, so starting a submit
      // silently dropped the message explaining why the form was unusable.
      const state = OrganizationFormState(loadError: 'boom');

      expect(state.copyWith(loadingCountries: false).loadError, 'boom');
      expect(state.copyWith(clearLoadError: true).loadError, isNull);
    });
  });
}
