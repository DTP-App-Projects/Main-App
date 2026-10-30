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
import 'saved_channels.dart';

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

  /// Shown and guided through, but not needed to send for review.
  final bool optional;

  const OnboardingStep({
    required this.kind,
    required this.complete,
    this.locked = false,
    this.optional = false,
  });
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

  /// Profile ids whose channels this app has saved ([SavedChannels]). The
  /// bootstrap's own `channel_codes` include unsaved suggestions, so they
  /// cannot mark the step done.
  final Set<int> savedChannelProfiles;

  const OnboardingState({
    this.status = OnboardingStatus.loading,
    this.data,
    this.errorMessage,
    this.action = const SubmitState(),
    this.branchCount = 0,
    this.bankAccountCount = 0,
    this.documentCount = 0,
    this.savedChannelProfiles = const {},
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
      // Approval comes from the profile's own status. The organization's
      // `approved_workspaces` is not approval: live, it already lists
      // `trader` for a brand-new trader and `supplier` for a supplier still
      // in `pending_review` — it marked an empty profile "done".
      //
      // A draft is filled in once it has sectors and *saved* channels —
      // what `profile/submit` checks. Sign-up creates the draft with no
      // saved channels, and the bootstrap's `channel_codes` (and its score)
      // count guessed ones, so only a save from this app proves it.
      final filled = match != null &&
          match.sectorIds.isNotEmpty &&
          savedChannelProfiles.contains(match.id);
      return OnboardingStep(
        kind: kind,
        complete: filled || (match?.isActive ?? false) || (match?.isUnderReview ?? false),
        locked: match?.isUnderReview ?? false,
      );
    }

    // The website's order (owner console "Setup progress"). Bank accounts
    // are only among a supplier's gaps there, so a trader may skip them.
    return [
      OnboardingStep(kind: OnboardingStepKind.organization, complete: org?.hasLegalIdentity ?? false),
      OnboardingStep(kind: OnboardingStepKind.branches, complete: branchCount > 0),
      OnboardingStep(kind: OnboardingStepKind.documents, complete: documentCount > 0),
      OnboardingStep(
        kind: OnboardingStepKind.bankAccounts,
        complete: bankAccountCount > 0,
        optional: !wantedWorkspaces.contains(Workspace.supplier),
      ),
      if (wantedWorkspaces.contains(Workspace.trader))
        profileStep(Workspace.trader, OnboardingStepKind.traderProfile),
      if (wantedWorkspaces.contains(Workspace.supplier))
        profileStep(Workspace.supplier, OnboardingStepKind.supplierProfile),
    ];
  }

  bool get allStepsComplete => steps.every((step) => step.complete || step.optional);

  /// Some wanted profile is still a draft. An approved organization walking
  /// back in has nothing to send — it was offered a "Send for review" that
  /// "succeeded" without sending anything.
  bool get hasDraftProfile => wantedWorkspaces.any((workspace) {
        final profile = data?.profileFor(workspace);
        return profile == null || !(profile.isUnderReview || profile.isActive);
      });

  /// What "Continue setup" opens: the first unfinished step, in order —
  /// optional ones included, so the guided pass fills in everything.
  OnboardingStep? get nextStep {
    for (final step in steps) {
      if (!step.complete && !step.locked) return step;
    }
    return null;
  }

  /// Already sent — the wizard becomes a read-only status screen.
  bool get isUnderReview {
    if (organization?.status == 'pending_review') return true;
    // Profiles are submitted one by one, which may leave the organization
    // itself in `draft`: once every wanted profile is sent, so is the setup.
    final profiles = [for (final w in wantedWorkspaces) data?.profileFor(w)];
    return profiles.any((p) => p?.isUnderReview ?? false) &&
        profiles.every((p) => p != null && (p.isUnderReview || p.isActive));
  }

  OnboardingState copyWith({
    OnboardingStatus? status,
    OnboardingBootstrap? data,
    String? errorMessage,
    SubmitState? action,
    int? branchCount,
    int? bankAccountCount,
    int? documentCount,
    Set<int>? savedChannelProfiles,
    bool clearError = false,
  }) =>
      OnboardingState(
        savedChannelProfiles: savedChannelProfiles ?? this.savedChannelProfiles,
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

  /// Pull-to-refresh. Approval reaches the app through the session, so it is
  /// re-read too — silently, or the router would bounce through the splash.
  ///
  /// Returns true when an organization that was held here no longer needs
  /// onboarding (it is active now), so the screen can leave for the shell.
  /// One that walked in on purpose while already active is left alone.
  Future<bool> refreshAll() async {
    final wasHeld = _session.state.needsOnboarding;
    await _session.refresh(silent: true);
    if (isClosed) return false;
    if (wasHeld && !_session.state.needsOnboarding) return true;
    await load(quiet: true);
    return false;
  }

  /// [quiet] re-reads behind the screen that is already showing. A reload
  /// after pull-to-refresh or a submit used to swap the whole checklist for a
  /// skeleton and drop the scroll position.
  Future<void> load({bool quiet = false}) async {
    if (!quiet || state.data == null) {
      emit(state.copyWith(status: OnboardingStatus.loading, clearError: true));
    }

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
        savedChannelProfiles: _savedFor(data),
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
    if (kind == null) return;
    // Something changed, so a refusal from the last "Send for review" may no
    // longer hold — it stayed pinned over the button after being fixed.
    if (state.action.message != null) emit(state.copyWith(action: const SubmitState()));

    switch (kind) {
      // The organization and the profiles both live on the bootstrap, so
      // there is no cheaper read than the one call.
      case OnboardingStepKind.organization:
      case OnboardingStepKind.traderProfile:
      case OnboardingStepKind.supplierProfile:
        final result = await _repo.fetch();
        if (isClosed) return;
        if (result case Ok(:final data)) {
          emit(state.copyWith(data: data, savedChannelProfiles: _savedFor(data)));
        }

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

  Set<int> _savedFor(OnboardingBootstrap data) =>
      SavedChannels.among(data.profiles.map((p) => p.id));

  /// `POST /onboarding/profile/submit`, once per wanted profile still in
  /// draft — the web console's "Submit this profile for review". The first
  /// refusal stops the run and its `text` is shown as the server wrote it.
  Future<void> submitForReview() async {
    if (state.action.isSubmitting) return;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    var submitted = false;
    for (final workspace in state.wantedWorkspaces) {
      final profile = state.data?.profileFor(workspace);
      if (profile != null && (profile.isUnderReview || profile.isActive)) continue;

      final result = await _repo.submitProfile(workspace.api);
      if (isClosed) return;
      if (result is! Ok && result is! NoContent) {
        emit(state.copyWith(action: result.failureState));
        if (submitted) {
          await load(quiet: true);
          await _session.refresh(silent: true);
        }
        return;
      }
      submitted = true;
    }
    emit(state.copyWith(action: const SubmitState(status: FormStatus.success)));

    if (submitted) {
      // The organization's status drives routing, so the shell has to learn
      // about the change too.
      await load(quiet: true);
      await _session.refresh(silent: true);
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
      await load(quiet: true);
      await _session.refresh(silent: true);
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
