import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/form_status.dart';
import '../../../../../core/workspace/workspace.dart';
import '../../../../../data/models/bootstrap/journey.dart';
import '../../../../../data/models/bootstrap/organization.dart';
import '../../../../../data/models/onboarding/onboarding_bootstrap.dart';
import '../../../../../data/repositories/onboarding_repository.dart';

enum OnboardingStatus { loading, ready, error, offline }

/// One row of the wizard. Which steps exist is fixed by the API; whether a
/// step is *done* is derived from data we can actually verify, never guessed
/// from the server's free-text `missing[]` vocabulary.
enum OnboardingStepKind { organization, traderProfile, supplierProfile, branches, bankAccounts, documents }

@immutable
class OnboardingStep {
  final OnboardingStepKind kind;
  final bool complete;

  /// Set when the step is a profile that has already gone for review.
  final bool locked;

  const OnboardingStep({required this.kind, required this.complete, this.locked = false});
}

@immutable
class OnboardingState {
  final OnboardingStatus status;
  final OnboardingBootstrap? data;
  final String? errorMessage;

  /// `submit_for_review` / `request_workspace`.
  final SubmitState action;

  /// Row counts, read back from the owner-console listings. A step is "done"
  /// because a row exists, not because the server said so in prose.
  final int branchCount;
  final int bankAccountCount;
  final int documentCount;

  const OnboardingState({
    this.status = OnboardingStatus.loading,
    this.data,
    this.errorMessage,
    this.action = const SubmitState(),
    this.branchCount = 0,
    this.bankAccountCount = 0,
    this.documentCount = 0,
  });

  Organization? get organization => data?.organization;
  Journey get journey => data?.journey ?? Journey.empty;

  /// Which profiles this organization is pursuing. A `hybrid` org owes two.
  List<Workspace> get wantedWorkspaces => organization?.workspaces ?? const [Workspace.trader];

  /// The second workspace an existing single-mode org could still request.
  Workspace? get requestableWorkspace {
    final org = organization;
    if (org == null || org.isHybrid) return null;
    return org.workspaces.contains(Workspace.trader) ? Workspace.supplier : Workspace.trader;
  }

  List<OnboardingStep> get steps {
    final org = organization;
    final profiles = data?.profiles ?? const <OnboardingProfile>[];

    OnboardingStep profileStep(Workspace workspace, OnboardingStepKind kind) {
      OnboardingProfile? match;
      for (final profile in profiles) {
        if (profile.profileType == workspace.api) match = profile;
      }
      final approved = org?.approvedWorkspaces.contains(workspace.api) ?? false;
      return OnboardingStep(
        kind: kind,
        complete: approved || (match?.isActive ?? false) || (match?.isUnderReview ?? false),
        locked: match?.isUnderReview ?? false,
      );
    }

    return [
      OnboardingStep(kind: OnboardingStepKind.organization, complete: org?.hasLegalIdentity ?? false),
      if (wantedWorkspaces.contains(Workspace.trader))
        profileStep(Workspace.trader, OnboardingStepKind.traderProfile),
      if (wantedWorkspaces.contains(Workspace.supplier))
        profileStep(Workspace.supplier, OnboardingStepKind.supplierProfile),
      OnboardingStep(kind: OnboardingStepKind.branches, complete: branchCount > 0),
      OnboardingStep(kind: OnboardingStepKind.bankAccounts, complete: bankAccountCount > 0),
      OnboardingStep(kind: OnboardingStepKind.documents, complete: documentCount > 0),
    ];
  }

  bool get allStepsComplete => steps.every((step) => step.complete);

  /// Already sent — the wizard becomes a read-only status screen.
  bool get isUnderReview => organization?.status == 'pending_review';

  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingBootstrap? data,
    String? errorMessage,
    SubmitState? action,
    int? branchCount,
    int? bankAccountCount,
    int? documentCount,
    bool clearError = false,
  }) =>
      OnboardingState(
        status: status ?? this.status,
        data: data ?? this.data,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        action: action ?? this.action,
        branchCount: branchCount ?? this.branchCount,
        bankAccountCount: bankAccountCount ?? this.bankAccountCount,
        documentCount: documentCount ?? this.documentCount,
      );
}

/// Drives the wizard from `GET /v2/onboarding/bootstrap`.
///
/// **This screen is the app's heaviest reader, so it counts its requests.**
/// A full [load] is four calls — the bootstrap plus three listings whose only
/// purpose is to count rows — and the wizard used to run all four after every
/// step the user merely *opened*. Six steps browsed and nothing changed cost
/// twenty-eight requests against a sixty-a-minute budget. Editors now report
/// what they touched and [applyChange] re-reads only that.
class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepository _repo;
  final SessionCubit _session;

  OnboardingCubit(this._repo, this._session) : super(const OnboardingState());

  Future<void> load() async {
    emit(state.copyWith(status: OnboardingStatus.loading, clearError: true));

    final result = await _repo.fetch();
    if (isClosed) return;

    if (result case Ok(:final data)) {
      // Counts first, `ready` second. Step completeness is derived from these
      // rows, so publishing the screen before they land renders "To do"
      // against work that is already done and flickers the submit button
      // enabled → disabled → enabled.
      final counts = await _countsFor(const [
        OnboardingStepKind.branches,
        OnboardingStepKind.bankAccounts,
        OnboardingStepKind.documents,
      ]);
      if (isClosed) return;

      emit(state.copyWith(
        status: OnboardingStatus.ready,
        data: data,
        branchCount: counts[OnboardingStepKind.branches],
        bankAccountCount: counts[OnboardingStepKind.bankAccounts],
        documentCount: counts[OnboardingStepKind.documents],
      ));
      return;
    }
    emit(state.copyWith(
      status: result.isOffline ? OnboardingStatus.offline : OnboardingStatus.error,
      errorMessage: result.failureMessage,
    ));
  }

  /// Re-reads only what [kind] could have changed.
  ///
  /// `null` means the editor was dismissed without saving, which costs
  /// nothing — the common case, and the one that used to cost four requests.
  Future<void> applyChange(OnboardingStepKind? kind) async {
    switch (kind) {
      case null:
        return;

      // The organization and the profiles both live on the bootstrap, so
      // there is no cheaper read than the one call.
      case OnboardingStepKind.organization:
      case OnboardingStepKind.traderProfile:
      case OnboardingStepKind.supplierProfile:
        final result = await _repo.fetch();
        if (isClosed) return;
        if (result case Ok(:final data)) emit(state.copyWith(data: data));

      case OnboardingStepKind.branches:
      case OnboardingStepKind.bankAccounts:
      case OnboardingStepKind.documents:
        final counts = await _countsFor([kind]);
        if (isClosed) return;
        emit(state.copyWith(
          branchCount: counts[OnboardingStepKind.branches],
          bankAccountCount: counts[OnboardingStepKind.bankAccounts],
          documentCount: counts[OnboardingStepKind.documents],
        ));
    }
  }

  Future<void> submitForReview() async {
    if (state.action.isSubmitting) return;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.submitForReview();
    if (isClosed) return;
    emit(state.copyWith(action: result.failureState));

    if (result is Ok || result is NoContent) {
      // The organization's status drives routing, so the shell has to learn
      // about the change too.
      await load();
      await _session.refresh();
    }
  }

  /// How a trader-only organization becomes hybrid (or the other way round).
  Future<void> requestWorkspace(Workspace workspace) async {
    if (state.action.isSubmitting) return;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.requestWorkspace(workspace.api);
    if (isClosed) return;
    emit(state.copyWith(action: result.failureState));

    if (result is Ok || result is NoContent) {
      await load();
      await _session.refresh();
    }
  }

  /// Counts the rows behind the given steps, in sequence rather than fanned
  /// out — the budget is per minute, not per screen.
  ///
  /// A listing that fails leaves its entry absent rather than zero, so
  /// `copyWith` keeps the previous count instead of un-ticking a step because
  /// the network blinked.
  Future<Map<OnboardingStepKind, int>> _countsFor(
    List<OnboardingStepKind> kinds,
  ) async {
    final counts = <OnboardingStepKind, int>{};

    for (final kind in kinds) {
      final result = switch (kind) {
        OnboardingStepKind.branches => await _repo.branches(),
        OnboardingStepKind.bankAccounts => await _repo.bankAccounts(),
        OnboardingStepKind.documents => await _repo.documents(),
        // The other steps are not row collections.
        _ => null,
      };
      final rows = result?.dataOrNull;
      if (rows != null) counts[kind] = rows.length;
    }
    return counts;
  }
}
