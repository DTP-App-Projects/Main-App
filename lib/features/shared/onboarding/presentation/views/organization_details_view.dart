import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../compliance/org_compliance_cubit.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/models/bootstrap/organization.dart';
import '../../../../../data/models/common/country.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import '../view_models/onboarding_cubit.dart';
import '../view_models/onboarding_form_cubits.dart';

/// `PUT /api/v2/onboarding/organization`.
///
/// Required by the server: `legal_name_ar`, `trade_name`, `country_id`,
/// `city_id`. Everything else is optional and can be filled in later.
class OrganizationDetailsView extends StatelessWidget {
  const OrganizationDetailsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OrganizationFormCubit(
          getIt<OnboardingRepository>(),
          getIt<AuthRepository>(),
        )..loadCountries(),
        child: const _OrganizationForm(),
      );
}

class _OrganizationForm extends StatefulWidget {
  const _OrganizationForm();

  @override
  State<_OrganizationForm> createState() => _OrganizationFormState();
}

class _OrganizationFormState extends State<_OrganizationForm> {
  final _formKey = GlobalKey<FormState>();
  final _legalAr = TextEditingController();
  final _legalEn = TextEditingController();
  final _tradeName = TextEditingController();
  final _commercialRegNo = TextEditingController();
  final _taxNo = TextEditingController();
  final _vatNo = TextEditingController();
  final _notes = TextEditingController();

  int? _countryId;
  int? _cityId;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    for (final controller in [
      _legalAr,
      _legalEn,
      _tradeName,
      _commercialRegNo,
      _taxNo,
      _vatNo,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Bootstrap already carries whatever has been saved before, so the form
  /// opens filled rather than blank on a second visit.
  ///
  /// Runs once, from [initState]. It used to be called from `build()` behind a
  /// latch, which meant reading a cubit and writing to controllers in the
  /// middle of a build.
  void _prefill() {
    final organization = context.read<SessionCubit>().state.organization;
    if (organization != null) _fill(organization);
  }

  /// The session's `/v2/bootstrap` summary has no legal identity, so the full
  /// row from `GET /v2/organization` overwrites it once it arrives.
  void _fill(Organization organization) {
    _legalAr.text = organization.legalNameAr;
    _legalEn.text = organization.legalNameEn;
    _tradeName.text = organization.tradeName;
    _commercialRegNo.text = organization.commercialRegNo;
    _taxNo.text = organization.taxNo;
    _vatNo.text = organization.vatNo;
    _notes.text = organization.notes;
    _countryId = organization.countryId;
    _cityId = organization.cityId;
  }

  Future<void> _save() async {
    // B7: every field is built (a plain scroll view, not a lazy list), so the
    // required country / city pickers always take part in validation and
    // show their own "required" message; the first failing field is scrolled
    // into view so that message is never off screen.
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      final first = invalid.first.context;
      if (first.mounted) {
        await Scrollable.ensureVisible(
          first,
          alignment: 0.2,
          duration: const Duration(milliseconds: 250),
        );
      }
      return;
    }
    if (_countryId == null || _cityId == null) return;
    FocusScope.of(context).unfocus();

    final cubit = context.read<OrganizationFormCubit>();
    final saved = await cubit.save(
      legalNameAr: _legalAr.text,
      tradeName: _tradeName.text,
      countryId: _countryId!,
      cityId: _cityId!,
      legalNameEn: _legalEn.text,
      commercialRegNo: _commercialRegNo.text,
      taxNo: _taxNo.text,
      vatNo: _vatNo.text,
      notes: _notes.text,
    );
    if (saved == null || !mounted) return;

    // The organization drives routing and the shell header, so the session
    // has to learn about the change.
    // Silent: a loud refresh routes through the splash screen, which tore
    // down the wizard (and the guided walk) behind this one.
    await context.read<SessionCubit>().refresh(silent: true);
    // Tells the wizard what to re-read, so it does not reload everything.
    if (mounted) Navigator.of(context).pop(OnboardingStepKind.organization);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrganizationFormCubit, OrganizationFormState>(
      listenWhen: (previous, current) => previous.existing == null && current.existing != null,
      listener: (context, state) => setState(() => _fill(state.existing!)),
      builder: (context, state) {
        if (state.loadingCountries) {
          return Scaffold(
            appBar: AppBar(title: Text('organization.details_title'.tr())),
            body: const FormSkeleton(fields: 6),
          );
        }
        if (state.countries.isEmpty && state.loadError != null) {
          return Scaffold(
            appBar: AppBar(title: Text('organization.details_title'.tr())),
            body: AppErrorState(
              message: state.loadError!.isEmpty ? 'errors.generic'.tr() : state.loadError!,
              onRetry: context.read<OrganizationFormCubit>().loadCountries,
            ),
          );
        }

        final cities =
            state.countries.where((c) => c.id == _countryId).expand((c) => c.cities).toList();
        final theme = Theme.of(context);
        final locked = context.watch<OrgComplianceCubit>().state?.registrationLocked ?? false;

        return Scaffold(
          appBar: AppBar(title: Text('organization.details_title'.tr())),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.gutter,
                AppTokens.space2,
                AppTokens.gutter,
                AppTokens.space6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space1),
                    child: Text(
                      'organization.details_subtitle'.tr(),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: context.tokens.textSecondary),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  // Once the organization is active the registration data is
                  // frozen (spec §3): shown, never edited by members.
                  if (locked)
                    AppBanner(
                      key: const Key('registration_locked_banner'),
                      tone: AppTone.info,
                      icon: Icons.lock_outline_rounded,
                      message: 'registration.locked_hint'.tr(),
                    ),

                  _FormSection(
                    label: 'organization.section_identity'.tr(),
                    first: true,
                    children: [
                      AppField(
                        controller: _legalAr,
                        enabled: !locked,
                        label: 'organization.legal_name_ar'.tr(),
                        required: true,
                        validator: AppValidators.required,
                        serverError: state.submit.fieldError('legal_name_ar'),
                      ),
                      AppField(
                        controller: _legalEn,
                        enabled: !locked,
                        label: 'organization.legal_name_en'.tr(),
                        hint: 'common.optional'.tr(),
                        serverError: state.submit.fieldError('legal_name_en'),
                      ),
                      AppField(
                        controller: _tradeName,
                        label: 'organization.trade_name'.tr(),
                        required: true,
                        icon: Icons.storefront_outlined,
                        validator: AppValidators.required,
                        serverError: state.submit.fieldError('trade_name'),
                      ),
                    ],
                  ),

                  _FormSection(
                    label: 'register.section_location'.tr(),
                    children: [
                      IdPicker<Country>(
                        label: 'register.country'.tr(),
                        required: true,
                        value: _countryId,
                        items: state.countries,
                        idOf: (c) => c.id,
                        labelOf: (c) => c.name,
                        error: state.submit.fieldError('country_id'),
                        onChanged: (id) => setState(() {
                          _countryId = id;
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
                        error: state.submit.fieldError('city_id'),
                        onChanged: (id) => setState(() => _cityId = id),
                      ),
                    ],
                  ),

                  _FormSection(
                    label: 'organization.section_registration'.tr(),
                    children: [
                      AppField(
                        controller: _commercialRegNo,
                        enabled: !locked,
                        label: 'organization.commercial_reg_no'.tr(),
                        keyboardType: TextInputType.number,
                        icon: Icons.badge_outlined,
                        required: true,
                        validator: AppValidators.required,
                        textDirection: TextDirection.ltr,
                        serverError: state.submit.fieldError('commercial_reg_no'),
                      ),
                      AppField(
                        controller: _taxNo,
                        enabled: !locked,
                        label: 'organization.tax_no'.tr(),
                        keyboardType: TextInputType.number,
                        hint: 'common.optional'.tr(),
                        textDirection: TextDirection.ltr,
                        serverError: state.submit.fieldError('tax_no'),
                      ),
                      AppField(
                        controller: _vatNo,
                        enabled: !locked,
                        label: 'organization.vat_no'.tr(),
                        keyboardType: TextInputType.number,
                        hint: 'common.optional'.tr(),
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.done,
                        serverError: state.submit.fieldError('vat_no'),
                      ),
                      AppField(
                        controller: _notes,
                        label: 'organization.notes'.tr(),
                        hint: 'common.optional'.tr(),
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                        serverError: state.submit.fieldError('notes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The save's answer, right above the button.
                FormMessage(message: state.submit.message),
                SubmitButton(
                  busy: state.submit.isSubmitting,
                  label: 'common.save'.tr(),
                  onPressed: _save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A section label over a form card, the fields inside it.
class _FormSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool first;

  const _FormSection({required this.label, required this.children, this.first = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionLabel(
            label,
            padding: EdgeInsetsDirectional.fromSTEB(
              AppTokens.space1,
              first ? AppTokens.space2 : AppTokens.sectionGap,
              AppTokens.space1,
              AppTokens.space3,
            ),
          ),
          AppCard(
            // Fields carry their own bottom gap; trim the last one's.
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.cardPadding,
              AppTokens.cardPadding,
              AppTokens.cardPadding,
              0,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      );
}
