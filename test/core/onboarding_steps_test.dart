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
  }) =>
      OnboardingState(
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
      final approved = stateFor({
        ...complete,
        'business_mode': 'trader',
        'approved_workspaces': ['trader'],
      });
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
        {...complete, 'business_mode': 'trader', 'approved_workspaces': ['trader']},
        branches: 1,
      );
      final full = stateFor(
        {...complete, 'business_mode': 'trader', 'approved_workspaces': ['trader']},
        branches: 1,
        bankAccounts: 1,
        documents: 1,
      );

      expect(partial.allStepsComplete, isFalse);
      expect(full.allStepsComplete, isTrue);
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
