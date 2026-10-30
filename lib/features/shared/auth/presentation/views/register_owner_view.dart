import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/roots/app_router.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../core/workspace/workspace.dart';
import '../../../../../data/models/common/country.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../view_models/register_owner_cubit.dart';
import 'widgets/auth_widgets.dart';

/// B2B sign-up, in the website's four steps (`/register`): business mode and
/// activity, owner, organization, then terms and submit. `business_mode` comes
/// first because it decides which workspace(s) the new organization gets — and
/// `hybrid` is the only value that produces a workspace switcher.
///
/// After the account exists the router holds the user in the onboarding
/// wizard until the organization's profile is complete.
class RegisterOwnerView extends StatelessWidget {
  const RegisterOwnerView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        RegisterOwnerCubit(getIt<AuthRepository>(), getIt<SessionCubit>(), getIt<PushService>())
          ..loadCountries()
          ..loadTerms(),
    // The account exists once the code is mailed: replace the stack, so Back
    // can never return to the filled form (a resend would hit "email taken").
    child: BlocListener<RegisterOwnerCubit, RegisterOwnerState>(
      listenWhen: (previous, current) =>
          previous.verification == null && current.verification != null,
      listener: (context, state) =>
          context.go(AppRoutes.verifyEmail, extra: state.verification),
      child: const _RegisterFlow(),
    ),
  );
}

/// Owns every field of every step, so going back and forth never loses what
/// was typed. Only the current step is built, so one form key serves all.
class _RegisterFlow extends StatefulWidget {
  const _RegisterFlow();

  @override
  State<_RegisterFlow> createState() => _RegisterFlowState();
}

class _RegisterFlowState extends State<_RegisterFlow> {
  static const _total = 4;

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _organization = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();

  int? _countryId;
  int? _cityId;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _password,
      _passwordConfirm,
      _organization,
      _address,
      _phone,
      _whatsapp,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Validates the fields on screen, then moves on.
  void _next() {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<RegisterOwnerCubit>().next();
  }

  void _submit() {
    final cubit = context.read<RegisterOwnerCubit>();
    if (!cubit.state.termsAccepted || _countryId == null || _cityId == null) return;
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();

    cubit.submit(
      firstName: _firstName.text,
      lastName: _lastName.text,
      organizationName: _organization.text,
      email: _email.text,
      password: _password.text,
      countryId: _countryId!,
      cityId: _cityId!,
      phone: _phone.text,
      whatsapp: _whatsapp.text,
      address: _address.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final step = context.select<RegisterOwnerCubit, RegisterStep>((c) => c.state.step);

    return PopScope(
      canPop: step == RegisterStep.mode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.back();
      },
      child: Form(
        key: _formKey,
        child: switch (step) {
          RegisterStep.mode => _modeStep(context),
          RegisterStep.owner => _ownerStep(context),
          RegisterStep.organization => _organizationStep(context),
          RegisterStep.terms => _termsStep(context),
        },
      ),
    );
  }

  // ------------------------------------------------------------ step 1 of 4

  /// Choosing a mode chooses which workspace(s) the organization gets, and the
  /// activity options follow the mode, exactly as on the website.
  Widget _modeStep(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final state = context.watch<RegisterOwnerCubit>().state;
    final theme = Theme.of(context);

    return AuthScaffold(
      step: (1, _total),
      plain: true,
      title: 'register.mode_title'.tr(),
      subtitle: 'register.mode_subtitle'.tr(),
      cta: AppButton.primary(
        label: 'common.continue'.tr(),
        onPressed: state.activityType == null ? null : _next,
      ),
      footer: AuthFooterLink(
        question: 'auth.have_account'.tr(),
        action: 'auth.sign_in'.tr(),
        onPressed: () => context.go(AppRoutes.login),
      ),
      children: [
        for (final mode in const [BusinessMode.trader, BusinessMode.supplier, BusinessMode.hybrid])
          AuthChoiceCard(
            icon: _modeIcon(mode),
            title: 'register.mode_$mode'.tr(),
            body: 'register.mode_${mode}_hint'.tr(),
            selected: state.businessMode == mode,
            onTap: () => cubit.chooseMode(mode),
          ),
        AppSectionLabel(
          'register.activity_type'.tr(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.space1,
            AppTokens.sectionGap,
            AppTokens.space1,
            AppTokens.space1,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.space1,
            0,
            AppTokens.space1,
            AppTokens.space3,
          ),
          child: Text(
            'register.activity_hint'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
          ),
        ),
        for (final activity in ActivityType.forMode(state.businessMode))
          AuthChoiceCard(
            icon: _activityIcon(activity),
            title: 'register.activity_$activity'.tr(),
            body: 'register.activity_${activity}_hint'.tr(),
            selected: state.activityType == activity,
            onTap: () => cubit.chooseActivity(activity),
          ),
        if (state.submit.fieldError('activity_type') case final error?)
          _FieldErrorText(error),
        // «شركة نقل أو توصيل؟» — fleets register on their own portal.
        const SizedBox(height: AppTokens.space4),
        AppCard(
          child: Row(
            children: [
              const AppIconCircle(Icons.local_shipping_outlined, tone: AppTone.neutral),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('register.fleet_title'.tr(), style: theme.textTheme.titleSmall),
                    Text('register.fleet_hint'.tr(), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              AppButton.text(
                label: 'register.fleet_action'.tr(),
                onPressed: () => launchUrl(
                  Uri.parse('https://tacaml.com/fleet/register'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _modeIcon(String mode) => switch (mode) {
    BusinessMode.supplier => Icons.local_shipping_outlined,
    BusinessMode.hybrid => Icons.swap_horiz_rounded,
    _ => Icons.storefront_outlined,
  };

  static IconData _activityIcon(String activity) => switch (activity) {
    'factory' => Icons.factory_outlined,
    'supplier_trader' => Icons.inventory_2_outlined,
    ActivityType.marketer => Icons.campaign_outlined,
    _ => Icons.shopping_bag_outlined,
  };

  // ------------------------------------------------------------ step 2 of 4

  Widget _ownerStep(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final state = context.watch<RegisterOwnerCubit>().state;

    return AuthScaffold(
      step: (2, _total),
      plain: true,
      title: 'register.owner_title'.tr(),
      subtitle: 'register.owner_body'.tr(),
      banner: FormMessage(message: state.submit.message),
      cta: AppButton.primary(label: 'common.continue'.tr(), onPressed: _next),
      children: [
        _Section(
          first: true,
          children: [
            AppField(
              controller: _firstName,
              label: 'register.first_name'.tr(),
              required: true,
              autofillHints: const [AutofillHints.givenName],
              validator: AppValidators.required,
              serverError: state.submit.fieldError('first_name'),
              onChanged: (_) => cubit.clearMessage(),
            ),
            AppField(
              controller: _lastName,
              label: 'register.last_name'.tr(),
              required: true,
              autofillHints: const [AutofillHints.familyName],
              validator: AppValidators.required,
              serverError: state.submit.fieldError('last_name'),
            ),
            AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppField(
                    controller: _email,
                    label: 'auth.email'.tr(),
                    required: true,
                    icon: Icons.mail_outline_rounded,
                    hint: 'auth.email_hint'.tr(),
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.newUsername],
                    validator: AppValidators.email,
                    serverError: state.submit.fieldError('email'),
                    onChanged: (_) => cubit.clearMessage(),
                  ),
                  AppField(
                    controller: _password,
                    label: 'auth.password'.tr(),
                    required: true,
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    helper: 'validation.password_min8'.tr(),
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AppValidators.newPassword,
                    serverError: state.submit.fieldError('password'),
                    onChanged: (_) => setState(() {}),
                  ),
                  PasswordStrengthMeter(password: _password.text),
                  AppField(
                    controller: _passwordConfirm,
                    label: 'register.password_confirm'.tr(),
                    required: true,
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'validation.required'.tr();
                      return value == _password.text ? null : 'validation.password_match'.tr();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ step 3 of 4

  Widget _organizationStep(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final state = context.watch<RegisterOwnerCubit>().state;
    final title = 'register.organization_title'.tr();

    // Loading and error keep the auth chrome (step bar, language pill), so
    // the screen does not jump between states.
    if (state.loadingCountries) {
      return AuthScaffold(
        step: (3, _total),
        plain: true,
        title: title,
        children: const [SizedBox(height: 460, child: FormSkeleton(fields: 5))],
      );
    }
    if (state.countriesError != null && state.countries.isEmpty) {
      return AuthScaffold(
        step: (3, _total),
        plain: true,
        title: title,
        children: [AppErrorState(message: state.countriesError!, onRetry: cubit.loadCountries)],
      );
    }

    final countries = state.countries;
    final cities = countries.where((c) => c.id == _countryId).expand((c) => c.cities).toList();

    return AuthScaffold(
      step: (3, _total),
      plain: true,
      title: title,
      subtitle: 'register.organization_body'.tr(),
      banner: FormMessage(message: state.submit.message),
      cta: AppButton.primary(label: 'common.continue'.tr(), onPressed: _next),
      children: [
        _Section(
          first: true,
          children: [
            AppField(
              controller: _organization,
              label: 'register.organization_name'.tr(),
              required: true,
              icon: Icons.business_outlined,
              validator: AppValidators.required,
              serverError: state.submit.fieldError('organization_name'),
              onChanged: (_) => cubit.clearMessage(),
            ),
            IdPicker<Country>(
              label: 'register.country'.tr(),
              required: true,
              value: _countryId,
              items: countries,
              idOf: (c) => c.id,
              labelOf: (c) => c.name,
              error: state.submit.fieldError('country_id'),
              onChanged: (id) => setState(() {
                _countryId = id;
                // The old city belongs to the old country.
                _cityId = null;
              }),
            ),
            IdPicker<City>(
              label: 'register.city'.tr(),
              required: true,
              value: _cityId,
              items: cities,
              idOf: (c) => c.id,
              labelOf: (c) => c.name,
              enabled: _countryId != null,
              error: state.submit.fieldError('city_id'),
              onChanged: (id) => setState(() => _cityId = id),
            ),
            // Required server-side since the compliance release; it becomes
            // the organization's first (HQ) branch.
            AppField(
              controller: _address,
              label: 'register.address'.tr(),
              required: true,
              validator: AppValidators.required,
              maxLines: 2,
              serverError: state.submit.fieldError('address'),
            ),
            AppField(
              controller: _phone,
              label: 'register.phone'.tr(),
              required: true,
              icon: Icons.phone_outlined,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              hint: SaudiPhone.hint,
              inputFormatters: SaudiPhone.formatters,
              validator: _saudiMobile,
              serverError: state.submit.fieldError('phone'),
            ),
            AppField(
              controller: _whatsapp,
              label: 'register.whatsapp'.tr(),
              required: true,
              hint: SaudiPhone.hint,
              icon: Icons.chat_outlined,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: SaudiPhone.formatters,
              validator: _saudiMobile,
              serverError: state.submit.fieldError('whatsapp'),
            ),
          ],
        ),
      ],
    );
  }

  /// Both numbers are required on the website, as a full `05XXXXXXXX`.
  static String? _saudiMobile(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.required'.tr();
    return RegExp(r'^05\d{8}$').hasMatch(value.trim()) ? null : 'validation.saudi_mobile'.tr();
  }

  // ------------------------------------------------------------ step 4 of 4

  /// What is about to be created, then the terms and the one button.
  Widget _termsStep(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final state = context.watch<RegisterOwnerCubit>().state;
    final owner = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final activity = state.activityType;

    return AuthScaffold(
      step: (4, _total),
      plain: true,
      title: 'register.review_title'.tr(),
      subtitle: 'register.review_body'.tr(),
      banner: FormMessage(message: state.submit.message),
      cta: SubmitButton(
        busy: state.submit.isSubmitting,
        label: 'register.submit'.tr(),
        // The terms checkbox is mandatory: no acceptance, no account.
        onPressed: state.termsAccepted ? _submit : null,
      ),
      children: [
        _Section(
          label: 'register.summary'.tr(),
          first: true,
          children: [
            DetailRow(
              label: 'register.summary_mode'.tr(),
              value: Text([
                'register.mode_${state.businessMode}'.tr(),
                if (activity != null) 'register.activity_$activity'.tr(),
              ].join(' · ')),
            ),
            DetailRow(label: 'register.summary_owner'.tr(), value: Text(owner)),
            DetailRow(label: 'auth.email'.tr(), value: Text(_email.text.trim())),
            DetailRow(
              label: 'register.summary_organization'.tr(),
              value: Text(_organization.text.trim()),
            ),
          ],
        ),
        _Section(
          label: 'register.section_terms'.tr(),
          children: [_SignupTermsBlock(state: state)],
        ),
        if (!state.termsAccepted)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppTokens.space3),
            child: Text(
              'register.terms_needed'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.tokens.textSecondary),
            ),
          ),
        // Kept reachable in case the reader wants to change something.
        Align(
          child: AppButton.text(label: 'common.back'.tr(), onPressed: cubit.back),
        ),
      ],
    );
  }
}

class _FieldErrorText extends StatelessWidget {
  final String message;

  const _FieldErrorText(this.message);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(AppTokens.space1, AppTokens.space2, AppTokens.space1, 0),
    child: Text(
      message,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.tokens.fieldError),
    ),
  );
}

/// The platform terms on the sign-up form, with the mandatory checkbox and
/// the legal wording of a level-1 acceptance.
class _SignupTermsBlock extends StatelessWidget {
  final RegisterOwnerState state;

  const _SignupTermsBlock({required this.state});

  void _read(BuildContext context) {
    final html = state.terms?.html ?? '';
    showAppSheet<void>(
      context: context,
      title: 'register.terms_title'.tr(),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Html(data: html),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final theme = Theme.of(context);
    final t = context.tokens;

    if (state.loadingTerms && state.terms == null) return const Skeleton(height: 56);
    if (state.terms == null) {
      return AppErrorState(
        message: state.termsError ?? 'errors.generic'.tr(),
        onRetry: cubit.loadTerms,
      );
    }
    final missing = state.submit.fieldError('accept_terms');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'register.terms_title'.tr(),
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (state.terms!.version.isNotEmpty)
              AppBadge(
                'terms.version'.tr(namedArgs: {'version': state.terms!.version}),
                tone: AppTone.neutral,
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(label: 'terms.read_full'.tr(), onPressed: () => _read(context)),
        ),
        // Named by the server once it knows the activity: every document the
        // new organization accepts with this one tick.
        if (state.requiredTerms.isNotEmpty) ...[
          Text('register.terms_required_list'.tr(), style: theme.textTheme.labelMedium),
          for (final v in state.requiredTerms)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
              child: Text(
                '• ${v.title}  (${'terms.version'.tr(namedArgs: {'version': v.version})})',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppTokens.space2),
        ],
        CheckboxListTile(
          key: const Key('signup_accept_terms'),
          value: state.termsAccepted,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => cubit.setTermsAccepted(v ?? false),
          title: Text('register.terms_agree'.tr(), style: theme.textTheme.bodyMedium),
          subtitle: Text('acceptance.click_legal'.tr(), style: theme.textTheme.labelSmall),
        ),
        if (missing != null)
          Text(missing, style: theme.textTheme.labelSmall?.copyWith(color: t.fieldError)),
      ],
    );
  }
}

/// An optional section label over a form card.
class _Section extends StatelessWidget {
  final String? label;
  final List<Widget> children;
  final bool first;

  const _Section({this.label, required this.children, this.first = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label != null)
        AppSectionLabel(
          label!,
          padding: EdgeInsetsDirectional.fromSTEB(
            AppTokens.space1,
            first ? 0 : AppTokens.sectionGap,
            AppTokens.space1,
            AppTokens.space3,
          ),
        ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ],
  );
}
