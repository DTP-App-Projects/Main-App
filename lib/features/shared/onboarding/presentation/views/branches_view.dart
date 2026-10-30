import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/models/common/branch.dart';
import '../../../../../data/models/common/country.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import '../view_models/onboarding_form_cubits.dart';
import 'widgets/collection_scaffold.dart';
import 'widgets/location_picker.dart';
import '../view_models/onboarding_cubit.dart';

/// `POST /api/v2/onboarding/branches` — an upsert, so the same form both
/// creates and edits and a retry can never duplicate a branch.
class BranchesView extends StatelessWidget {
  const BranchesView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => BranchesCubit(getIt<OnboardingRepository>(), getIt<AuthRepository>())
      ..load()
      ..loadCountries(),
    child: const _BranchesBody(),
  );
}

class _BranchesBody extends StatelessWidget {
  const _BranchesBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<BranchesCubit>();
    final locale = context.locale.toString();

    return CollectionScaffold<Branch>(
      title: 'branch.title'.tr(),
      subtitle: 'branch.subtitle'.tr(),
      emptyMessage: 'branch.empty'.tr(),
      addLabel: 'branch.add'.tr(),
      state: cubit.state,
      onRetry: cubit.load,
      onAdd: () => _openEditor(context, null),
      changeKind: OnboardingStepKind.branches,
      emptyIcon: Icons.store_outlined,
      itemBuilder: (branch) => CollectionTile(
        icon: Icons.store_outlined,
        title: branch.displayName(locale),
        // The pin is what puts a branch on a driver's route (guide 5.1).
        subtitle: [
          branch.addressText,
          branch.hasLocation ? 'branch.location_set'.tr() : 'branch.location_missing'.tr(),
        ].where((s) => s.isNotEmpty).join(' · '),
        trailing: branch.isDefault ? 'branch.default'.tr() : null,
        onTap: () => _openEditor(context, branch),
      ),
    );
  }

  void _openEditor(BuildContext context, Branch? branch) {
    final cubit = context.read<BranchesCubit>();
    cubit.resetForm();

    showEditorSheet(
      context: context,
      title: branch == null ? 'branch.add'.tr() : 'branch.edit'.tr(),
      fields: (sheetContext) => [
        BlocProvider.value(
          value: cubit,
          child: _BranchForm(branch: branch),
        ),
      ],
    );
  }
}

class _BranchForm extends StatefulWidget {
  final Branch? branch;

  const _BranchForm({required this.branch});

  @override
  State<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends State<_BranchForm> {
  /// The documented `branch_type` enum.
  static const _types = ['hq', 'warehouse', 'store', 'branch', 'delivery_point', 'shelf_location'];

  final _formKey = GlobalKey<FormState>();
  late final _nameAr = TextEditingController(text: widget.branch?.nameAr ?? '');
  late final _nameEn = TextEditingController(text: widget.branch?.nameEn ?? '');
  late final _address = TextEditingController(text: widget.branch?.addressText ?? '');
  late final _contactName = TextEditingController(text: widget.branch?.contactName ?? '');
  late final _contactPhone = TextEditingController(text: widget.branch?.contactPhone ?? '');

  late String? _type = widget.branch?.type.isNotEmpty == true ? widget.branch!.type : 'hq';
  late int? _countryId = widget.branch?.countryId;
  late int? _cityId = widget.branch?.cityId;
  late double? _latitude = widget.branch?.latitude;
  late double? _longitude = widget.branch?.longitude;
  late bool _isDefault = widget.branch?.isDefault ?? false;

  @override
  void dispose() {
    for (final controller in [_nameAr, _nameEn, _address, _contactName, _contactPhone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // The type, country and city pickers are required form fields, so a
    // missing one fails `validate()` with its own "required" message under
    // the field — the null check below is only a type guard.
    if (!_formKey.currentState!.validate()) return;
    if (_countryId == null || _cityId == null || _type == null) return;

    final saved = await context.read<BranchesCubit>().save(
      branchId: widget.branch?.id,
      branchType: _type!,
      nameAr: _nameAr.text,
      countryId: _countryId!,
      cityId: _cityId!,
      addressText: _address.text,
      nameEn: _nameEn.text,
      contactName: _contactName.text,
      contactPhone: _contactPhone.text,
      latitude: _latitude,
      longitude: _longitude,
      // Only sent when it changes: the flag is the organization's.
      isDefault: _isDefault != (widget.branch?.isDefault ?? false) ? _isDefault : null,
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<BranchesCubit>();
    final submit = cubit.state.submit;
    final countries = cubit.countries;
    final cities = countries.where((c) => c.id == _countryId).expand((c) => c.cities).toList();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodePicker(
            label: 'branch.type'.tr(),
            required: true,
            value: _type,
            codes: _types,
            labelOf: (code) => 'branch.type_$code'.tr(),
            error: submit.fieldError('branch_type'),
            onChanged: (value) => setState(() => _type = value),
          ),
          AppField(
            controller: _nameAr,
            label: 'branch.name_ar'.tr(),
            required: true,
            validator: AppValidators.required,
            serverError: submit.fieldError('name_ar'),
          ),
          AppField(
            controller: _nameEn,
            label: 'branch.name_en'.tr(),
            serverError: submit.fieldError('name_en'),
          ),
          IdPicker<Country>(
            label: 'register.country'.tr(),
            required: true,
            value: _countryId,
            items: countries,
            idOf: (c) => c.id,
            labelOf: (c) => c.name,
            error: submit.fieldError('country_id'),
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
            error: submit.fieldError('city_id'),
            onChanged: (id) => setState(() => _cityId = id),
          ),
          AppField(
            controller: _address,
            label: 'branch.address'.tr(),
            required: true,
            icon: Icons.location_on_outlined,
            validator: AppValidators.required,
            serverError: submit.fieldError('address_text'),
          ),
          // «موقع الفرع على الخريطة» — what puts the branch on a driver's
          // route. Its pair (or both null) is always sent: omitting them
          // would keep a pin the user just cleared.
          BranchLocationPicker(
            initialLat: _latitude,
            initialLng: _longitude,
            addressController: _address,
            error: submit.fieldError('latitude') ?? submit.fieldError('longitude'),
            onChanged: (lat, lng) {
              _latitude = lat;
              _longitude = lng;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('branch.make_default'.tr()),
            value: _isDefault,
            onChanged: (value) => setState(() => _isDefault = value),
          ),
          AppField(
            controller: _contactName,
            label: 'branch.contact_name'.tr(),
            icon: Icons.person_outline_rounded,
            serverError: submit.fieldError('contact_name'),
          ),
          AppField(
            controller: _contactPhone,
            label: 'branch.contact_phone'.tr(),
            keyboardType: TextInputType.phone,
            icon: Icons.phone_outlined,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            hint: SaudiPhone.hint,
            inputFormatters: SaudiPhone.formatters,
            serverError: submit.fieldError('contact_phone'),
          ),
          const SizedBox(height: AppTokens.space2),
          FormMessage(message: submit.message),
          SubmitButton(busy: submit.isSubmitting, label: 'common.save'.tr(), onPressed: _save),
        ],
      ),
    );
  }
}
