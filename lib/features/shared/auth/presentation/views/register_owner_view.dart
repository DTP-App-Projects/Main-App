import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

/// B2B sign-up. `business_mode` is picked first because it decides which
/// workspace(s) the new organization gets — and `hybrid` is the only value
/// that produces a workspace switcher.
class RegisterOwnerView extends StatelessWidget {
  const RegisterOwnerView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        RegisterOwnerCubit(getIt<AuthRepository>(), getIt<SessionCubit>(), getIt<PushService>())
          ..loadCountries(),
    child: const _RegisterFlow(),
  );
}

class _RegisterFlow extends StatelessWidget {
  const _RegisterFlow();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final step = context.select<RegisterOwnerCubit, RegisterStep>((c) => c.state.step);

    return PopScope(
      canPop: step == RegisterStep.mode,
      // The step lives in the cubit, so back is one call rather than a
      // `setState` in a widget that does not own the decision.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.back();
      },
      child: switch (step) {
        RegisterStep.mode => const _ModeStep(),
        RegisterStep.details => const _DetailsStep(),
      },
    );
  }
}

/// Choosing a mode chooses which workspace(s) the organization gets, so each
/// option says what it unlocks. Driver selectable cards: icon disc, title,
/// hint, and a radio mark on the end side.
class _ModeStep extends StatelessWidget {
  const _ModeStep();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterOwnerCubit>();
    final selected = context.select<RegisterOwnerCubit, String>((c) => c.state.businessMode);

    return AuthScaffold(
      step: (1, 2),
      plain: true,
      title: 'register.mode_title'.tr(),
      subtitle: 'register.mode_subtitle'.tr(),
      cta: AppButton.primary(label: 'common.continue'.tr(), onPressed: cubit.toDetails),
      footer: AuthFooterLink(
        question: 'auth.have_account'.tr(),
        action: 'auth.sign_in'.tr(),
        onPressed: () => context.go(AppRoutes.login),
      ),
      children: [
        AuthChoiceCard(
          icon: Icons.storefront_outlined,
          title: 'register.mode_trader'.tr(),
          body: 'register.mode_trader_hint'.tr(),
          selected: selected == BusinessMode.trader,
          onTap: () => cubit.chooseMode(BusinessMode.trader),
        ),
        AuthChoiceCard(
          icon: Icons.local_shipping_outlined,
          title: 'register.mode_supplier'.tr(),
          body: 'register.mode_supplier_hint'.tr(),
          selected: selected == BusinessMode.supplier,
          onTap: () => cubit.chooseMode(BusinessMode.supplier),
        ),
        AuthChoiceCard(
          icon: Icons.swap_horiz_rounded,
          title: 'register.mode_hybrid'.tr(),
          body: 'register.mode_hybrid_hint'.tr(),
          selected: selected == BusinessMode.hybrid,
          onTap: () => cubit.chooseMode(BusinessMode.hybrid),
        ),
      ],
    );
  }
}

class _DetailsStep extends StatefulWidget {
  const _DetailsStep();

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _organization = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _address = TextEditingController();

  int? _countryId;
  int? _cityId;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _organization,
      _email,
      _password,
      _phone,
      _whatsapp,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // The country and city pickers are required form fields, so a missing
    // one fails `validate()` with its own message under the picker.
    if (!_formKey.currentState!.validate()) return;
    if (_countryId == null || _cityId == null) return;
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();

    context.read<RegisterOwnerCubit>().submit(
      firstName: _firstName.text,
      lastName: _lastName.text,
      organizationName: _organization.text,
      email: _email.text,
      password: _password.text,
      countryId: _countryId!,
      cityId: _cityId!,
      phone: _phone.text,
      // Reached the repository all along but was never collected.
      whatsapp: _whatsapp.text,
      address: _address.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterOwnerCubit, RegisterOwnerState>(
      builder: (context, state) {
        final cubit = context.read<RegisterOwnerCubit>();

        // Loading and error keep the auth chrome (step bar, language pill),
        // so the screen does not jump between states.
        if (state.loadingCountries) {
          return AuthScaffold(
            step: (2, 2),
            plain: true,
            title: 'register.details_title'.tr(),
            children: const [SizedBox(height: 460, child: FormSkeleton(fields: 5))],
          );
        }
        if (state.countriesError != null && state.countries.isEmpty) {
          return AuthScaffold(
            step: (2, 2),
            plain: true,
            title: 'register.details_title'.tr(),
            children: [AppErrorState(message: state.countriesError!, onRetry: cubit.loadCountries)],
          );
        }

        final countries = state.countries;
        final cities = countries.where((c) => c.id == _countryId).expand((c) => c.cities).toList();

        return Form(
          key: _formKey,
          child: AuthScaffold(
            step: (2, 2),
            plain: true,
            title: 'register.details_title'.tr(),
            subtitle: 'register.details_body'.tr(),
            banner: FormMessage(message: state.submit.message),
            cta: SubmitButton(
              busy: state.submit.isSubmitting,
              label: 'register.submit'.tr(),
              onPressed: _submit,
            ),
            children: [
              // Three cards for the three questions the form is asking,
              // rather than one wall of nine fields.
              _Section(
                label: 'register.section_you'.tr(),
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
                          helper: 'validation.password_min'.tr(),
                          autofillHints: const [AutofillHints.newPassword],
                          validator: AppValidators.password,
                          serverError: state.submit.fieldError('password'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _Section(
                label: 'register.section_business'.tr(),
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
                  AppField(
                    controller: _phone,
                    label: 'register.phone'.tr(),
                    icon: Icons.phone_outlined,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    serverError: state.submit.fieldError('phone'),
                  ),
                  AppField(
                    controller: _whatsapp,
                    label: 'register.whatsapp'.tr(),
                    hint: 'common.optional'.tr(),
                    icon: Icons.chat_outlined,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    serverError: state.submit.fieldError('whatsapp'),
                  ),
                ],
              ),
              _Section(
                label: 'register.section_location'.tr(),
                children: [
                  IdPicker<Country>(
                    label: 'register.country'.tr(),
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
                    value: _cityId,
                    items: cities,
                    idOf: (c) => c.id,
                    labelOf: (c) => c.name,
                    enabled: _countryId != null,
                    error: state.submit.fieldError('city_id'),
                    onChanged: (id) => setState(() => _cityId = id),
                  ),
                  AppField(
                    controller: _address,
                    label: 'register.address'.tr(),
                    hint: 'common.optional'.tr(),
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    serverError: state.submit.fieldError('address'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A section label over a form card.
class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool first;

  const _Section({required this.label, required this.children, this.first = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionLabel(
        label,
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
