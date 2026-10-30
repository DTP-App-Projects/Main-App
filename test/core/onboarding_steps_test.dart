import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/onboarding/onboarding_bootstrap.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/view_models/onboarding_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wizard's checklist is derived, not guessed. These pin the derivation.
void main() {
  OnboardingState stateFor(
    Map<String, dynamic> organization, {
    List<Map<String, dynamic>> profiles = const [],
    int branches = 0,
    int bankAccounts = 0,
    int documents = 0,
    Set<int> savedChannels = const {},
  }) =>
      OnboardingState(
        savedChannelProfiles: savedChannels,
        status: OnboardingStatus.ready,
        data: OnboardingBootstrap.fromJson({
          'organization': organization,
          'profiles': profiles,
        }),
        branchCount: branches,
        bankAccountCount: bankAccounts,
        documentCount: documents,
      );

  const complete = {
    'id': 3,
    'legal_name_ar': 'شركة',
    'trade_name': 'Test',
    'country_id': 1,
    'city_id': 2,
    'commercial_reg_no': '1010101010',
  };

  group('steps', () {
    test('a hybrid organization owes two profiles', () {
      final state = stateFor({...complete, 'business_mode': 'hybrid'});
      final kinds = state.steps.map((s) => s.kind);

      expect(kinds, contains(OnboardingStepKind.traderProfile));
      expect(kinds, contains(OnboardingStepKind.supplierProfile));
      expect(state.steps.length, 6);
    });

    test('a trader-only organization is never asked for a supplier profile', () {
      final state = stateFor({...complete, 'business_mode': 'trader'});
      final kinds = state.steps.map((s) => s.kind);

      expect(kinds, contains(OnboardingStepKind.traderProfile));
      expect(kinds, isNot(contains(OnboardingStepKind.supplierProfile)));
      expect(state.steps.length, 5);
    });

    test('the organization step tracks the four required fields', () {
      final filled = stateFor({...complete, 'business_mode': 'trader'});
      final blank = stateFor(const {'id': 3, 'business_mode': 'trader'});

      expect(filled.steps.first.complete, isTrue);
      expect(blank.steps.first.complete, isFalse);
    });

    test('a profile counts as done once it is approved or in review', () {
      final approved = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [
          {'id': 9, 'profile_type': 'trader', 'status': 'active'},
        ],
      );
      final inReview = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [
          {'profile_type': 'trader', 'status': 'pending_review'},
        ],
      );
      final draft = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [
          {'profile_type': 'trader', 'status': 'draft'},
        ],
      );

      OnboardingStep traderStep(OnboardingState state) =>
          state.steps.firstWhere((s) => s.kind == OnboardingStepKind.traderProfile);

      expect(traderStep(approved).complete, isTrue);
      expect(traderStep(approved).locked, isFalse);

      // In review is "done" for the checklist, but the form goes read-only.
      expect(traderStep(inReview).complete, isTrue);
      expect(traderStep(inReview).locked, isTrue);

      expect(traderStep(draft).complete, isFalse);
    });

    test('approved_workspaces is not approval: an empty draft stays to do', () {
      // Live: a brand-new trader already has `approved_workspaces: [trader]`
      // (and a pending supplier `[supplier]`) with nothing filled in.
      final fresh = stateFor(
        {...complete, 'business_mode': 'trader', 'approved_workspaces': ['trader']},
        profiles: const [
          {'id': 9, 'profile_type': 'trader', 'status': 'draft', 'sector_ids': <int>[], 'channel_codes': <String>[]},
        ],
      );
      final step = fresh.steps.firstWhere((s) => s.kind == OnboardingStepKind.traderProfile);

      expect(step.complete, isFalse);
      expect(fresh.allStepsComplete, isFalse);
    });

    test('rows saved are what mark branches, banks and documents done', () {
      final none = stateFor({...complete, 'business_mode': 'trader'});
      final some = stateFor(
        {...complete, 'business_mode': 'trader'},
        branches: 1,
        bankAccounts: 2,
        documents: 1,
      );

      bool doneFor(OnboardingState state, OnboardingStepKind kind) =>
          state.steps.firstWhere((s) => s.kind == kind).complete;

      expect(doneFor(none, OnboardingStepKind.branches), isFalse);
      expect(doneFor(some, OnboardingStepKind.branches), isTrue);
      expect(doneFor(some, OnboardingStepKind.bankAccounts), isTrue);
      expect(doneFor(some, OnboardingStepKind.documents), isTrue);
    });

    test('submit unlocks only when every step is done', () {
      final partial = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [
          {'id': 9, 'profile_type': 'trader', 'status': 'active'},
        ],
        branches: 1,
      );
      final full = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [
          {'id': 9, 'profile_type': 'trader', 'status': 'active'},
        ],
        branches: 1,
        bankAccounts: 1,
        documents: 1,
      );

      expect(partial.allStepsComplete, isFalse);
      expect(full.allStepsComplete, isTrue);
    });

    // The live shape right after website sign-up (org 21, 2026-10-06).
    const signupDraft = {
      'id': 23,
      'profile_type': 'trader',
      'status': 'draft',
      'sector_ids': [5],
      'channel_codes': ['retail'],
    };

    test("bootstrap channels are suggestions: only the app's own save completes a draft", () {
      // The bootstrap shows `channel_codes: [retail]`, but that list mixes
      // in channels guessed from the sectors; `profile/submit` refuses with
      // "Select at least one business channel" until they are saved.
      final suggested = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [signupDraft],
      );
      final saved = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [signupDraft],
        savedChannels: const {23},
      );
      final savedNoSectors = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: [
          {...signupDraft, 'sector_ids': <int>[]},
        ],
        savedChannels: const {23},
      );

      OnboardingStep traderStep(OnboardingState state) =>
          state.steps.firstWhere((s) => s.kind == OnboardingStepKind.traderProfile);

      expect(traderStep(suggested).complete, isFalse);
      expect(traderStep(saved).complete, isTrue);
      expect(traderStep(saved).locked, isFalse);
      expect(traderStep(savedNoSectors).complete, isFalse);
    });

    test("website order; a trader may skip bank accounts, a supplier may not", () {
      final trader = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [signupDraft],
        branches: 1,
        documents: 1,
        savedChannels: const {23},
      );
      expect(trader.steps.map((s) => s.kind), [
        OnboardingStepKind.organization,
        OnboardingStepKind.branches,
        OnboardingStepKind.documents,
        OnboardingStepKind.bankAccounts,
        OnboardingStepKind.traderProfile,
      ]);
      expect(trader.allStepsComplete, isTrue, reason: 'no bank account needed');
      // The guided pass still offers it.
      expect(trader.nextStep?.kind, OnboardingStepKind.bankAccounts);

      final supplier = stateFor({...complete, 'business_mode': 'supplier'}, branches: 1, documents: 1);
      expect(
        supplier.steps.firstWhere((s) => s.kind == OnboardingStepKind.bankAccounts).optional,
        isFalse,
      );
      expect(supplier.allStepsComplete, isFalse);
    });

    test('the next step is the first unfinished one', () {
      final fresh = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [signupDraft],
      );
      expect(fresh.nextStep?.kind, OnboardingStepKind.branches);

      final done = stateFor(
        {...complete, 'business_mode': 'trader'},
        profiles: const [signupDraft],
        branches: 1,
        documents: 1,
        bankAccounts: 1,
        savedChannels: const {23},
      );
      expect(done.nextStep, isNull);
    });
  });

  group('send for review', () {
    test('every wanted profile sent means the setup is under review', () {
      final sent = stateFor(
        {...complete, 'business_mode': 'trader', 'status': 'draft'},
        profiles: const [
          {'id': 23, 'profile_type': 'trader', 'status': 'pending_review'},
        ],
      );
      final hybridHalfSent = stateFor(
        {...complete, 'business_mode': 'hybrid', 'status': 'draft'},
        profiles: const [
          {'id': 23, 'profile_type': 'trader', 'status': 'pending_review'},
          {'id': 24, 'profile_type': 'supplier', 'status': 'draft'},
        ],
      );
      expect(sent.isUnderReview, isTrue);
      expect(hybridHalfSent.isUnderReview, isFalse);
    });
  });

  group('second workspace', () {
    test('a trader-only organization can request the supplier side', () {
      final state = stateFor({...complete, 'business_mode': 'trader'});
      expect(state.requestableWorkspace, Workspace.supplier);
    });

    test('a supplier-only organization can request the trader side', () {
      final state = stateFor({...complete, 'business_mode': 'supplier'});
      expect(state.requestableWorkspace, Workspace.trader);
    });

    test('a hybrid organization has nothing left to request', () {
      final state = stateFor({...complete, 'business_mode': 'hybrid'});
      expect(state.requestableWorkspace, isNull);
    });
  });

  group('review', () {
    test('a pending organization turns the wizard read-only', () {
      final state = stateFor({...complete, 'business_mode': 'trader', 'status': 'pending_review'});
      expect(state.isUnderReview, isTrue);
    });

    test('an active organization can still be edited', () {
      final state = stateFor({...complete, 'business_mode': 'trader', 'status': 'active'});
      expect(state.isUnderReview, isFalse);
    });
  });
}
