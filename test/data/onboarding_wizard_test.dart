import 'package:digital_trade_portal/core/network/api_client.dart';
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_state.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/onboarding/onboarding_bootstrap.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/onboarding_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/onboarding_cubit.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/onboarding_form_cubits.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/saved_channels.dart';
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
            {
              'id': 9,
              'profile_type': 'trader',
              'status': 'draft',
              'notes': 'hi',
              'sector_ids': [5],
              'channel_codes': ['retail'],
            },
          ],
          'sector_options': [
            {'id': 5, 'code': 'retail', 'display_name': 'Retail Stores'},
          ],
          'channel_options': [
            {'code': 'retail', 'label': 'General Retail'},
            {'code': 'grocery', 'label': 'Grocery & Hypermarket'},
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
    test('one bootstrap read gives sectors, channels and the profile', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(routed());

      final cubit = ProfileFormCubit(OnboardingRepository(client));
      await cubit.load('trader');

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, contains('onboarding/bootstrap'));
      expect(cubit.state.sectors.map((s) => s.id), [5]);
      expect(cubit.state.channels.map((c) => c.code), ['retail', 'grocery']);
      expect(cubit.state.existing?.id, 9);
      expect(cubit.state.existing?.channelCodes, ['retail'], reason: 'pre-ticked');
      await cubit.close();
    });

    test('save sends both arrays and remembers the channels as saved', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(FakeAdapter.json(const {
        'msg': 'success',
        'profile': {'id': 9, 'profile_type': 'trader', 'status': 'draft'},
      }));

      final cubit = ProfileFormCubit(OnboardingRepository(client));
      expect(SavedChannels.contains(9), isFalse);

      final ok = await cubit.save(
        profileType: 'trader',
        profileId: 9,
        sectorIds: const [3, 7],
        channelCodes: const ['retail', 'grocery'],
      );
      final body = adapter.requests.single.data as Map;

      expect(ok, isTrue);
      expect(body['sector_ids'], [3, 7]);
      expect(body['channel_codes'], ['retail', 'grocery'], reason: 'a real array');
      expect(SavedChannels.contains(9), isTrue);
      await cubit.close();
    });

    test('an empty channel list is never sent', () async {
      final store = SessionStore();
      await store.restore();
      final (client, adapter) = clientWith(FakeAdapter.json(const {'profile': {'id': 9}}));

      await OnboardingRepository(client).saveProfile(profileType: 'trader', sectorIds: const [3]);
      final body = adapter.requests.single.data as Map;

      expect(body.containsKey('channel_codes'), isFalse,
          reason: 'it would overwrite the saved channels with nothing');
    });
  });

  group('audit regressions', () {
    test('a refresh re-reads behind the checklist, never back to the skeleton', () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(routed());
      final cubit = wizardWith(client, store);
      await cubit.load();

      final seen = <OnboardingStatus>[];
      final sub = cubit.stream.listen((s) => seen.add(s.status));
      await cubit.load(quiet: true);
      await Future<void>.delayed(Duration.zero);

      expect(seen, isNot(contains(OnboardingStatus.loading)));
      await sub.cancel();
      await cubit.close();
    });

    test('a saved row is still reported after the editor is reopened', () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(FakeAdapter((options) async {
        if (options.method == 'POST') return jsonBody(const {'branch': {'id': 1}});
        return jsonBody({
          'items': [
            {'id': 1, 'name_ar': 'فرع'},
          ],
        });
      }));
      final cubit = BranchesCubit(OnboardingRepository(client), AuthRepository(client));
      await cubit.load();

      await cubit.save(branchType: 'hq', nameAr: 'فرع', countryId: 1, cityId: 2, addressText: 'x');
      // Opening "Add" again resets the form…
      cubit.resetForm();

      // …but the wizard must still hear that a branch was saved.
      expect(cubit.state.savedAny, isTrue);
      expect(cubit.state.items, isNotEmpty, reason: 'the list stayed on screen');
      await cubit.close();
    });

    test('countries arriving late still reach an open branch form', () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(FakeAdapter.json(const [
        {'id': 1, 'name': 'KSA', 'cities': []},
      ]));
      final cubit = BranchesCubit(OnboardingRepository(client), AuthRepository(client));

      final emitted = <Object>[];
      final sub = cubit.stream.listen(emitted.add);
      await cubit.loadCountries();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.countries, isNotEmpty);
      expect(emitted, isNotEmpty, reason: 'the form rebuilds with the pickers filled');
      await sub.cancel();
      await cubit.close();
    });

    test('an approved organization is not offered "Send for review"', () {
      OnboardingState stateWith(String status) => OnboardingState(
            status: OnboardingStatus.ready,
            data: OnboardingBootstrap.fromJson({
              'organization': {'id': 3, 'business_mode': 'trader', 'status': 'active'},
              'profiles': [
                {'id': 9, 'profile_type': 'trader', 'status': status},
              ],
            }),
          );

      expect(stateWith('active').hasDraftProfile, isFalse);
      expect(stateWith('draft').hasDraftProfile, isTrue);
    });

    test('fixing a step clears the last refusal', () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(FakeAdapter((options) async {
        if (options.path.contains('profile/submit')) {
          return jsonBody(const {'msg': 'validation_error', 'text': 'Add at least one branch.'}, status: 400);
        }
        if (options.path.contains('onboarding/bootstrap')) {
          return jsonBody(const {
            'organization': {'id': 3, 'business_mode': 'trader', 'status': 'draft'},
            'profiles': [
              {'id': 9, 'profile_type': 'trader', 'status': 'draft'},
            ],
          });
        }
        return jsonBody({'items': <Map<String, dynamic>>[]});
      }));
      final cubit = wizardWith(client, store);
      await cubit.load();
      await cubit.submitForReview();
      expect(cubit.state.action.message, 'Add at least one branch.');

      await cubit.applyChange(OnboardingStepKind.branches);

      expect(cubit.state.action.message, isNull);
      await cubit.close();
    });
  });

  group('pull to refresh', () {
    /// `/v2/bootstrap` answers with the organization in [status].
    FakeAdapter sessionAt(String status) => FakeAdapter((options) async {
          if (options.path.endsWith('/v2/bootstrap')) {
            return jsonBody({
              'user': {'id': 1},
              'organizations': [
                {'id': 3, 'business_mode': 'trader', 'status': status},
              ],
            });
          }
          return jsonBody({'items': <Map<String, dynamic>>[]});
        });

    (OnboardingCubit, SessionCubit) build(ApiClient client, SessionStore store) {
      final bootstrap = BootstrapRepository(client);
      final session = SessionCubit(
        store,
        bootstrap,
        WorkspaceCubit(store, OpsRepository(client)),
        PushService(AuthRepository(client), bootstrap, store),
      );
      return (OnboardingCubit(OnboardingRepository(client), session), session);
    }

    test('an organization approved while held here leaves for the shell', () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(sessionAt('draft'));
      final (cubit, session) = build(client, store);
      await session.refresh();
      expect(session.state.needsOnboarding, isTrue);

      // The reviewer approves; the next pull sees it.
      client.dio.httpClientAdapter = sessionAt('active');
      final statuses = <Object?>[];
      final sub = session.stream.listen((s) => statuses.add(s.status));

      expect(await cubit.refreshAll(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(statuses, isNot(contains(SessionStatus.loading)),
          reason: 'a silent refresh never bounces through the splash');
      await sub.cancel();
      await cubit.close();
    });

    test('still in setup: the wizard reloads and stays', () async {
      final store = SessionStore();
      await store.restore();
      final (client, _) = clientWith(sessionAt('draft'));
      final (cubit, session) = build(client, store);
      await session.refresh();

      expect(await cubit.refreshAll(), isFalse);
      await cubit.close();
    });
  });

  group('send for review', () {
    test("submits each draft profile and shows the server's text on refusal", () async {
      final store = SessionStore();
      await store.restore();
      var submits = 0;
      final (client, adapter) = clientWith(FakeAdapter((options) async {
        if (options.path.contains('profile/submit')) {
          submits++;
          return jsonBody(const {
            'msg': 'validation_error',
            'text': 'Select at least one business channel for this profile.',
          }, status: 400);
        }
        if (options.path.contains('onboarding/bootstrap')) {
          return jsonBody(const {
            'organization': {'id': 3, 'business_mode': 'trader', 'status': 'draft'},
            'profiles': [
              {'id': 9, 'profile_type': 'trader', 'status': 'draft'},
            ],
          });
        }
        return jsonBody({'items': <Map<String, dynamic>>[]});
      }));

      final cubit = wizardWith(client, store);
      await cubit.load();
      await cubit.submitForReview();

      expect(submits, 1);
      final body = adapter.requests.firstWhere((r) => r.path.contains('profile/submit')).data as Map;
      expect(body, {'profile_type': 'trader'});
      expect(cubit.state.action.message, 'Select at least one business channel for this profile.');
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
