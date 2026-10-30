import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../core/workspace/workspace.dart';
import '../../../../../data/models/onboarding/onboarding_bootstrap.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import '../view_models/onboarding_cubit.dart';
import '../view_models/onboarding_form_cubits.dart';

/// `PUT /api/v2/onboarding/profile` + `POST .../profile/submit`.
///
/// Sectors **and channels** on one screen, saved together, like the web
/// owner console. `profile/submit` checks the *saved* channels, and sign-up
/// saves none — so the channel chips are what make a profile submittable.
///
/// One screen per workspace. Saving keeps a draft; **submitting starts an
/// independent review for that one side**, which is why an organization can
/// end up approved as a trader and still pending as a supplier.
class ProfileFormView extends StatelessWidget {
  final Workspace workspace;

  /// The row the wizard already holds. Supplying it saves a second read of
  /// the whole onboarding bootstrap; a deep link arrives without it.
  final OnboardingProfile? known;

  const ProfileFormView({super.key, required this.workspace, this.known});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ProfileFormCubit(getIt<OnboardingRepository>())
          ..load(workspace.api, known: known),
        child: _ProfileForm(workspace: workspace),
      );
}

class _ProfileForm extends StatefulWidget {
  final Workspace workspace;

  const _ProfileForm({required this.workspace});

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  static const _natures = ['manufacturer', 'supplier', 'both'];

  final _notes = TextEditingController();
  final Set<int> _sectorIds = {};
  final Set<String> _channelCodes = {};
  String? _supplierNature;
  OnboardingProfile? _existing;
  bool _prefilled = false;

  bool get _isSupplier => widget.workspace == Workspace.supplier;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _prefillOnce(OnboardingProfile? profile) {
    if (_prefilled || profile == null) return;
    // `setState`, because the sector chips and the nature picker read these
    // fields directly — filling them silently left the form looking blank.
    setState(() {
      _existing = profile;
      _notes.text = profile.notes;
      _sectorIds
        ..clear()
        ..addAll(profile.sectorIds);
      // Already holds the channels suggested by the sectors — the web form
      // pre-ticks the same list.
      _channelCodes
        ..clear()
        ..addAll(profile.channelCodes);
      _supplierNature = profile.supplierNature.isEmpty ? null : profile.supplierNature;
      _prefilled = true;
    });
  }

  /// The submit check needs at least one of each, and an empty channel list
  /// would overwrite the saved one with nothing.
  bool get _canSave =>
      _sectorIds.isNotEmpty && _channelCodes.isNotEmpty && (!_isSupplier || _supplierNature != null);

  Future<void> _save({required bool thenSubmit}) async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    final cubit = context.read<ProfileFormCubit>();

    final saved = await cubit.save(
      profileType: widget.workspace.api,
      profileId: _existing?.id,
      supplierNature: _supplierNature,
      sectorIds: _sectorIds.toList(),
      channelCodes: _channelCodes.toList(),
      notes: _notes.text,
    );
    if (!saved || !mounted) return;

    if (thenSubmit) {
      final submitted = await cubit.submitForReview(widget.workspace.api);
      if (!submitted || !mounted) return;
    }

    // Silent, as on every onboarding screen: a loud refresh bounced
    // through the splash and rebuilt the wizard underneath.
    await context.read<SessionCubit>().refresh(silent: true);
    if (!mounted) return;
    // Names the step so the wizard re-reads the bootstrap and nothing else.
    Navigator.of(context).pop(
      _isSupplier
          ? OnboardingStepKind.supplierProfile
          : OnboardingStepKind.traderProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isSupplier ? 'profile.supplier_title'.tr() : 'profile.trader_title'.tr();

    return BlocConsumer<ProfileFormCubit, ProfileFormState>(
      // The saved profile arrives asynchronously, so the fill happens on the
      // state that carries it — not inside `build`, which was writing to
      // controllers mid-frame behind a latch.
      listenWhen: (previous, current) => previous.existing != current.existing,
      listener: (context, state) => _prefillOnce(state.existing),
      builder: (context, state) {
        if (state.loadingSectors) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const FormSkeleton(fields: 3),
          );
        }
        if (state.sectors.isEmpty && state.loadError != null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: AppErrorState(
              message: state.loadError!.isEmpty ? 'errors.generic'.tr() : state.loadError!,
              onRetry: () => context.read<ProfileFormCubit>().load(widget.workspace.api),
            ),
          );
        }

        final locale = context.locale.toString();
        final locked = _existing?.isUnderReview ?? false;
        final t = context.tokens;

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              AppTokens.space2,
              AppTokens.gutter,
              AppTokens.space6,
            ),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space1),
                child: Text(
                  'profile.subtitle'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                ),
              ),
              const SizedBox(height: AppTokens.space4),

              if (locked)
                AppBanner(
                  message: 'profile.locked'.tr(),
                  tone: AppTone.info,
                  icon: Icons.lock_outline_rounded,
                ),
              if (_isSupplier)
                AppCard(
                  margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.cardPadding,
                    AppTokens.cardPadding,
                    AppTokens.cardPadding,
                    0,
                  ),
                  child: CodePicker(
                    label: 'profile.supplier_nature'.tr(),
                    value: _supplierNature,
                    codes: _natures,
                    labelOf: (code) => 'profile.nature_$code'.tr(),
                    error: state.submit.fieldError('supplier_nature'),
                    // «طبيعة المورد» is part of a supplier profile (guide 2.2).
                    required: true,
                    enabled: !locked,
                    onChanged: (value) => setState(() => _supplierNature = value),
                  ),
                ),

              AppSectionLabel(
                'profile.sectors'.tr(),
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppTokens.space1,
                  _isSupplier ? AppTokens.space4 : AppTokens.space2,
                  AppTokens.space1,
                  AppTokens.space3,
                ),
              ),
              AppCard(
                child: state.sectors.isEmpty
                    ? Text(
                        'profile.sectors_empty'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                      )
                    : Wrap(
                        spacing: AppTokens.space2,
                        runSpacing: AppTokens.space2,
                        children: [
                          for (final sector in state.sectors)
                            FilterChip(
                              label: Text(sector.displayName(locale)),
                              selected: _sectorIds.contains(sector.id),
                              onSelected: locked
                                  ? null
                                  : (selected) => setState(() {
                                        if (selected) {
                                          _sectorIds.add(sector.id);
                                        } else {
                                          _sectorIds.remove(sector.id);
                                        }
                                      }),
                            ),
                        ],
                      ),
              ),

              AppSectionLabel('profile.channels'.tr()),
              AppCard(
                child: state.channels.isEmpty
                    ? Text(
                        'profile.channels_empty'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                      )
                    : Wrap(
                        spacing: AppTokens.space2,
                        runSpacing: AppTokens.space2,
                        children: [
                          for (final channel in state.channels)
                            FilterChip(
                              label: Text(channel.label),
                              selected: _channelCodes.contains(channel.code),
                              onSelected: locked
                                  ? null
                                  : (selected) => setState(() {
                                        if (selected) {
                                          _channelCodes.add(channel.code);
                                        } else {
                                          _channelCodes.remove(channel.code);
                                        }
                                      }),
                            ),
                        ],
                      ),
              ),
              if (state.submit.fieldError('channel_codes') case final error?)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.space1,
                    AppTokens.space2,
                    AppTokens.space1,
                    0,
                  ),
                  child: Text(
                    error,
                    style: theme.textTheme.labelSmall?.copyWith(color: t.fieldError),
                  ),
                ),
              const SizedBox(height: AppTokens.space4),

              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: AppField(
                  controller: _notes,
                  label: 'profile.notes'.tr(),
                  hint: 'common.optional'.tr(),
                  enabled: !locked,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  serverError: state.submit.fieldError('notes'),
                ),
              ),
            ],
          ),
          // Sending for review is the step that moves the organization
          // forward, so it is the primary; keeping a draft is the quieter one.
          bottomNavigationBar: locked
              ? null
              : AppBottomBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The save's answer, right above the buttons.
                      FormMessage(message: state.submit.message),
                      if (!_canSave)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
                          child: Text(
                            'profile.pick_both'.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                          ),
                        ),
                      SubmitButton(
                        busy: state.submit.isSubmitting,
                        label: 'profile.submit_review'.tr(),
                        onPressed: _canSave ? () => _save(thenSubmit: true) : null,
                      ),
                      const SizedBox(height: AppTokens.space2),
                      AppButton.outline(
                        label: 'profile.save_draft'.tr(),
                        height: 48,
                        onPressed: state.submit.isSubmitting || !_canSave
                            ? null
                            : () => _save(thenSubmit: false),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
