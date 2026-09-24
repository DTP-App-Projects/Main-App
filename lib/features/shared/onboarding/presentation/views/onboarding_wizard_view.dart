import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../organization/workspace_switcher.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/roots/app_router.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../core/workspace/workspace.dart';
import '../../../../../data/models/onboarding/onboarding_bootstrap.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import '../../../organization/org_switcher_sheet.dart';
import '../view_models/onboarding_cubit.dart';
import 'widgets/journey_widgets.dart';

/// The onboarding wizard.
///
/// **One actionable list, one set of reviewer's notes.** The step spine is
/// derived from data the client can verify — fields filled, rows saved,
/// profile status — and every row of it opens an editor. The server's
/// `journey.missing[]` is authored in a vocabulary the API does not publish,
/// so it cannot be mapped onto those steps without guessing; it is shown
/// verbatim as notes instead. Two parallel checklists in two vocabularies
/// left the user to reconcile them.
class OnboardingWizardView extends StatelessWidget {
  const OnboardingWizardView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OnboardingCubit(
          getIt<OnboardingRepository>(),
          getIt<SessionCubit>(),
        )..load(),
        child: const _WizardBody(),
      );
}

class _WizardBody extends StatelessWidget {
  const _WizardBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OnboardingCubit>();
    final state = cubit.state;
    // An already-active organization can reach this screen deliberately, to
    // edit branches or request the second workspace. Only an unfinished one
    // is held here by the router.
    final session = context.watch<SessionCubit>().state;
    final held = session.needsOnboarding;

    return Scaffold(
      appBar: AppBar(
        title: Text('onboarding.title'.tr()),
        leading: held ? null : const BackButton(),
        automaticallyImplyLeading: !held,
        actions: [
          IconButton(
            tooltip: 'organization.switch_title'.tr(),
            icon: const Icon(Icons.apartment_outlined),
            onPressed: () => showOrgSwitcher(context),
          ),
          if (held)
            IconButton(
              tooltip: 'common.logout'.tr(),
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _confirmLogout(context),
            ),
          const SizedBox(width: AppTokens.space2),
        ],
      ),
      body: switch (state.status) {
        OnboardingStatus.loading => const _WizardSkeleton(),
        OnboardingStatus.offline => AppOfflineState(onRetry: cubit.load),
        OnboardingStatus.error => AppErrorState(
            message: (state.errorMessage?.isNotEmpty ?? false)
                ? state.errorMessage!
                : 'errors.generic'.tr(),
            onRetry: cubit.load,
          ),
        OnboardingStatus.ready => _WizardContent(state: state),
      },
      // The one primary action, pinned so it never scrolls away.
      bottomNavigationBar: state.status == OnboardingStatus.ready && !state.isUnderReview
          ? _SubmitBar(state: state)
          : null,
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'common.logout'.tr(),
      body: 'common.logout_confirm'.tr(),
      confirmLabel: 'common.logout'.tr(),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<SessionCubit>().logout();
  }
}

/// The submit block, pinned under the list. When the button is disabled the
/// reason sits right above it rather than somewhere down the page.
class _SubmitBar extends StatelessWidget {
  final OnboardingState state;

  const _SubmitBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final cubit = context.read<OnboardingCubit>();
    final message = state.action.message;

    return AppBottomBar(
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null && message.isNotEmpty)
            AppBanner(
              message: message,
              tone: AppTone.danger,
              margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.allStepsComplete) ...[
                Icon(Icons.info_outline_rounded, size: 16, color: t.textTertiary),
                const SizedBox(width: AppTokens.space1),
              ],
              Flexible(
                child: Text(
                  state.allStepsComplete
                      ? 'onboarding.submit_hint'.tr()
                      : 'onboarding.submit_blocked'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
      child: SubmitButton(
        busy: state.action.isSubmitting,
        label: 'onboarding.submit_for_review'.tr(),
        onPressed: state.allStepsComplete ? cubit.submitForReview : null,
      ),
    );
  }
}

class _WizardSkeleton extends StatelessWidget {
  const _WizardSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonShimmer(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppTokens.gutter,
            AppTokens.space4,
            AppTokens.gutter,
            AppTokens.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The progress hero card, the section label, then the step rows.
              Skeleton.box(height: 150),
              SizedBox(height: AppTokens.sectionGap),
              Skeleton.line(widthFactor: 0.3, height: 12),
              SizedBox(height: AppTokens.space3),
              _RowSkeleton(),
              _RowSkeleton(),
              _RowSkeleton(),
              _RowSkeleton(),
              _RowSkeleton(),
            ],
          ),
        ),
      );
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: AppTokens.space3),
        child: Row(
          children: [
            SkeletonCircle(size: 44),
            SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton.line(widthFactor: 0.55, height: 13),
                  SizedBox(height: AppTokens.space2),
                  Skeleton.line(widthFactor: 0.3, height: 11),
                ],
              ),
            ),
          ],
        ),
      );
}

class _WizardContent extends StatelessWidget {
  final OnboardingState state;

  const _WizardContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final steps = state.steps;
    final done = steps.where((step) => step.complete).length;

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.gutter,
          AppTokens.space2,
          AppTokens.gutter,
          AppTokens.space6,
        ),
        children: [
          OnboardingProgress(
            journey: state.journey,
            organizationStatus: state.organization?.status ?? '',
            stepsComplete: done,
            stepsTotal: steps.length,
          ),

          if (state.isUnderReview) ...[
            const SizedBox(height: AppTokens.space4),
            AppBanner(
              message: 'onboarding.under_review_banner'.tr(),
              tone: AppTone.info,
              icon: Icons.hourglass_top_rounded,
              margin: EdgeInsetsDirectional.zero,
            ),
          ],
          AppSectionLabel('onboarding.checklist'.tr()),

          // The spine. Every row goes somewhere.
          AppMenuGroup(
            children: [
              for (var i = 0; i < steps.length; i++)
                StepRow(
                  label: _labelFor(steps[i].kind),
                  complete: steps[i].complete,
                  locked: steps[i].locked,
                  number: i + 1,
                  onTap: () => _open(context, steps[i].kind),
                ),
            ],
          ),

          // Secondary: the reviewer's own words, under the work they concern.
          if (_hasNotes) ...[
            AppSectionLabel('onboarding.reviewer_notes'.tr()),
            ReviewerNotes(
              title: 'profile.trader_title'.tr(),
              profile: state.journey.trader,
            ),
            ReviewerNotes(
              title: 'profile.supplier_title'.tr(),
              profile: state.journey.supplier,
            ),
          ],

          if (state.journey.timeline.isNotEmpty) ...[
            AppSectionLabel('onboarding.timeline'.tr()),
            AppCard(child: JourneyTimeline(events: state.journey.timeline)),
          ],

          if (state.requestableWorkspace != null)
            _RequestWorkspaceCard(workspace: state.requestableWorkspace!, state: state),
        ],
      ),
    );
  }

  bool get _hasNotes =>
      state.journey.trader.missing.isNotEmpty ||
      state.journey.supplier.missing.isNotEmpty ||
      state.journey.trader.status.isNotEmpty ||
      state.journey.supplier.status.isNotEmpty;

  static String _labelFor(OnboardingStepKind kind) => switch (kind) {
        OnboardingStepKind.organization => 'onboarding.step_organization'.tr(),
        OnboardingStepKind.traderProfile => 'onboarding.step_trader_profile'.tr(),
        OnboardingStepKind.supplierProfile => 'onboarding.step_supplier_profile'.tr(),
        OnboardingStepKind.branches => 'onboarding.step_branches'.tr(),
        OnboardingStepKind.bankAccounts => 'onboarding.step_bank_accounts'.tr(),
        OnboardingStepKind.documents => 'onboarding.step_documents'.tr(),
      };

  /// Opens a step's editor and re-reads **only what it could have changed**.
  ///
  /// The editor pops with the step it saved, or `null` when it was dismissed.
  /// This used to reload the whole wizard — four requests — every time a step
  /// was merely opened.
  Future<void> _open(BuildContext context, OnboardingStepKind kind) async {
    final cubit = context.read<OnboardingCubit>();

    final route = switch (kind) {
      OnboardingStepKind.organization => AppRoutes.onboardingOrganization,
      OnboardingStepKind.traderProfile => AppRoutes.onboardingProfileFor(Workspace.trader),
      OnboardingStepKind.supplierProfile => AppRoutes.onboardingProfileFor(Workspace.supplier),
      OnboardingStepKind.branches => AppRoutes.onboardingBranches,
      OnboardingStepKind.bankAccounts => AppRoutes.onboardingBankAccounts,
      OnboardingStepKind.documents => AppRoutes.onboardingDocuments,
    };

    // The profile editors are handed the row the wizard already holds, so
    // they do not re-read the bootstrap to find it.
    final changed = await context.push<OnboardingStepKind>(
      route,
      extra: _profileFor(kind),
    );
    await cubit.applyChange(changed);
  }

  /// The saved profile for a profile step, for the editor to open filled.
  OnboardingProfile? _profileFor(OnboardingStepKind kind) {
    final type = switch (kind) {
      OnboardingStepKind.traderProfile => Workspace.trader.api,
      OnboardingStepKind.supplierProfile => Workspace.supplier.api,
      _ => null,
    };
    if (type == null) return null;

    for (final profile in state.data?.profiles ?? const <OnboardingProfile>[]) {
      if (profile.profileType == type) return profile;
    }
    return null;
  }
}

/// `POST /v2/b2b/owner-console/request_workspace` — how a single-mode
/// organization becomes hybrid.
class _RequestWorkspaceCard extends StatelessWidget {
  final Workspace workspace;
  final OnboardingState state;

  const _RequestWorkspaceCard({required this.workspace, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppTokens.sectionGap),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconCircle(RoleBadge.iconFor(workspace)),
                const SizedBox(width: AppTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'onboarding.add_workspace'
                            .tr(namedArgs: {'workspace': workspaceLabel(workspace)}),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTokens.space1),
                      Text('onboarding.add_workspace_hint'.tr(), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space4),
            AppButton.outline(
              label: 'onboarding.request'.tr(),
              icon: Icons.add_rounded,
              height: 48,
              busy: state.action.isSubmitting,
              onPressed: state.action.isSubmitting
                  ? null
                  : () => context.read<OnboardingCubit>().requestWorkspace(workspace),
            ),
          ],
        ),
      ),
    );
  }
}
