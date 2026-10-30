import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/money.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../core/workspace/workspace_cubit.dart';
import '../../../data/models/fleet/fleet_contract.dart';
import '../../../data/repositories/fleet_repository.dart';
import '../view_models/delivery_contracts_cubit.dart';
import 'fleet_widgets.dart';

/// «عقود التوصيل» — the supplier asks an approved delivery company to deliver
/// for it; the company accepts or rejects from its own panel.
class DeliveryContractsView extends StatelessWidget {
  const DeliveryContractsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DeliveryContractsCubit(getIt<FleetRepository>())..load(),
    child: const _Body(),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DeliveryContractsCubit>();
    final state = cubit.state;
    final overview = state.overview;
    final canManage = context.watch<WorkspaceCubit>().state?.can('fleet.manage') ?? false;
    final canRequest = canManage && (overview?.availableCompanies.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: Text('fleet_contract.title'.tr())),
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: () => _request(context, cubit),
              icon: const Icon(Icons.add_rounded),
              label: Text('fleet_contract.request'.tr()),
            )
          : null,
      body: Builder(
        builder: (context) {
          if (state.loading && overview == null) return const ListSkeleton(rows: 4);
          if (overview == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }
          return RefreshIndicator(
            onRefresh: () => cubit.load(quiet: true),
            child: overview.contracts.isEmpty
                ? AppEmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'fleet_contract.empty'.tr(),
                    body: overview.availableCompanies.isEmpty
                        ? 'fleet_contract.no_companies'.tr()
                        : 'fleet_contract.empty_hint'.tr(),
                  )
                : ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppTokens.gutter,
                      AppTokens.space3,
                      AppTokens.gutter,
                      // Clear of the floating Request button.
                      AppTokens.space8 * 3,
                    ),
                    children: [
                      FormMessage(message: state.action.message),
                      for (final contract in overview.contracts)
                        _ContractCard(
                          contract: contract,
                          canEnd: canManage && contract.canEnd,
                          busy: state.action.isSubmitting,
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _request(BuildContext context, DeliveryContractsCubit cubit) async {
    cubit.resetForm();
    final ok = await showAppSheet<bool>(
      context: context,
      title: 'fleet_contract.request'.tr(),
      builder: (_) => BlocProvider.value(value: cubit, child: const _RequestForm()),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('fleet_contract.requested'.tr())));
    }
  }
}

class _ContractCard extends StatelessWidget {
  final FleetContract contract;
  final bool canEnd;
  final bool busy;

  const _ContractCard({required this.contract, required this.canEnd, required this.busy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final company = contract.company;

    return AppCard.item(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconCircle(Icons.local_shipping_outlined, size: 40),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Text(
                  company?.name(locale) ?? '—',
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: contract.status),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          DetailRow(
            label: 'fleet_contract.billing_mode'.tr(),
            value: Text('fleet_contract.mode_${contract.billingMode}'.tr()),
          ),
          if (contract.isMonthly)
            DetailRow(
              label: 'fleet_contract.monthly_amount'.tr(),
              value: MoneyText(contract.monthlyRetainerAmount ?? 0, currency: contract.currency),
            )
          else ...[
            if (contract.ratePerDelivery != null)
              DetailRow(
                label: 'fleet_contract.rate_per_delivery'.tr(),
                value: MoneyText(contract.ratePerDelivery!, currency: contract.currency),
              ),
            if (contract.ratePerKm != null)
              DetailRow(
                label: 'fleet_contract.rate_per_km'.tr(),
                value: MoneyText(contract.ratePerKm!, currency: contract.currency),
              ),
          ],
          DetailRow(
            label: 'fleet_contract.deliveries_this_month'.tr(),
            emphasis: true,
            value: Text('${contract.deliveriesThisMonth}', textDirection: TextDirection.ltr),
          ),
          if (contract.expectedDeliveriesPerMonth != null)
            DetailRow(
              label: 'fleet_contract.expected_per_month'.tr(),
              value: Text(
                '${contract.expectedDeliveriesPerMonth}',
                textDirection: TextDirection.ltr,
              ),
            ),
          if (contract.driversCount != null)
            DetailRow(
              label: 'fleet_contract.drivers_count'.tr(),
              value: Text('${contract.driversCount}', textDirection: TextDirection.ltr),
            ),
          if (contract.coverageNotes.isNotEmpty)
            DetailRow(
              label: 'fleet_contract.coverage_notes'.tr(),
              value: Text(contract.coverageNotes),
            ),
          DetailRow(
            label: 'fleet_contract.requested_at'.tr(),
            value: DateText(contract.requestedAt),
          ),
          if (contract.acceptedAt != null)
            DetailRow(
              label: 'fleet_contract.accepted_at'.tr(),
              value: DateText(contract.acceptedAt),
            ),
          if (contract.endedAt != null)
            DetailRow(label: 'fleet_contract.ended_at'.tr(), value: DateText(contract.endedAt)),
          if (contract.status == 'rejected' && contract.rejectionReason.isNotEmpty)
            AppBanner(
              tone: AppTone.danger,
              title: 'fleet_contract.rejection_reason'.tr(),
              message: contract.rejectionReason,
              margin: const EdgeInsetsDirectional.only(top: AppTokens.space3),
            ),
          if (contract.status == 'ended' && contract.endReason.isNotEmpty)
            AppBanner(
              tone: AppTone.neutral,
              title: 'fleet_contract.end_reason'.tr(),
              message: contract.endReason,
              margin: const EdgeInsetsDirectional.only(top: AppTokens.space3),
            ),
          if (canEnd) ...[
            const SizedBox(height: AppTokens.space3),
            AppButton.outlineDanger(
              label: 'fleet_contract.end'.tr(),
              icon: Icons.block_rounded,
              height: 44,
              onPressed: busy ? null : () => _end(context),
            ),
          ],
          if (contract.status == 'suspended')
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppTokens.space2),
              child: Text(
                'fleet_contract.suspended_hint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: t.warningText),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _end(BuildContext context) async {
    final cubit = context.read<DeliveryContractsCubit>();
    final reason = await showAppReasonDialog(
      context,
      title: 'fleet_contract.end'.tr(),
      body: 'fleet_contract.end_confirm'.tr(),
      hint: 'fleet_contract.end_reason_hint'.tr(),
      confirmLabel: 'fleet_contract.end'.tr(),
      destructive: true,
      maxLength: 200,
    );
    if (reason == null) return;
    await cubit.end(contract.id, reason: reason);
  }
}

/// The request form: the company, then the price fields of the chosen
/// billing mode.
class _RequestForm extends StatefulWidget {
  const _RequestForm();

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  int? _companyId;
  String _mode = FleetContract.perDelivery;
  final _perDelivery = TextEditingController();
  final _perKm = TextEditingController();
  final _monthly = TextEditingController();
  final _drivers = TextEditingController();
  final _expected = TextEditingController();
  final _coverage = TextEditingController();

  @override
  void dispose() {
    for (final c in [_perDelivery, _perKm, _monthly, _drivers, _expected, _coverage]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _monthlyMode => _mode == FleetContract.monthlyRetainer;

  /// The server's rule, said up front: per delivery needs at least one
  /// rate; a retainer needs an amount above zero.
  bool get _ready {
    if (_companyId == null) return false;
    if (_monthlyMode) return (parseFleetNumber(_monthly.text) ?? 0) > 0;
    return parseFleetNumber(_perDelivery.text) != null || parseFleetNumber(_perKm.text) != null;
  }

  Future<void> _submit() async {
    final ok = await context.read<DeliveryContractsCubit>().request(
      fleetCompanyId: _companyId!,
      billingMode: _mode,
      ratePerDelivery: parseFleetNumber(_perDelivery.text),
      ratePerKm: parseFleetNumber(_perKm.text),
      monthlyRetainerAmount: parseFleetNumber(_monthly.text),
      driversCount: parseFleetNumber(_drivers.text)?.toInt(),
      expectedDeliveriesPerMonth: parseFleetNumber(_expected.text)?.toInt(),
      coverageNotes: _coverage.text,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeliveryContractsCubit>().state;
    final overview = state.overview;
    final submit = state.submit;
    final locale = context.locale.toString();
    final theme = Theme.of(context);
    void changed(String _) => setState(() {});

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IdPicker<FleetCompany>(
          label: 'fleet_contract.company'.tr(),
          value: _companyId,
          items: overview?.availableCompanies ?? const [],
          idOf: (c) => c.id,
          labelOf: (c) => c.name(locale),
          error: submit.fieldError('fleet_company_id'),
          onChanged: (id) => setState(() => _companyId = id),
        ),
        if (_companyId != null)
          _CompanySummary(
            company: overview!.availableCompanies.firstWhere((c) => c.id == _companyId),
          ),
        CodePicker(
          label: 'fleet_contract.billing_mode'.tr(),
          value: _mode,
          codes:
              overview?.billingModes ??
              const [FleetContract.perDelivery, FleetContract.monthlyRetainer],
          labelOf: (code) => 'fleet_contract.mode_$code'.tr(),
          error: submit.fieldError('billing_mode'),
          onChanged: (code) => setState(() => _mode = code ?? FleetContract.perDelivery),
        ),
        if (_monthlyMode)
          AppField(
            controller: _monthly,
            label: 'fleet_contract.monthly_amount'.tr(),
            required: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            suffixText: AppMoney.defaultCurrency,
            serverError: submit.fieldError('monthly_retainer_amount'),
            onChanged: changed,
          )
        else ...[
          Text('fleet_contract.rate_rule'.tr(), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppTokens.space3),
          AppField(
            controller: _perDelivery,
            label: 'fleet_contract.rate_per_delivery'.tr(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            suffixText: AppMoney.defaultCurrency,
            serverError: submit.fieldError('rate_per_delivery'),
            onChanged: changed,
          ),
          AppField(
            controller: _perKm,
            label: 'fleet_contract.rate_per_km'.tr(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            suffixText: AppMoney.defaultCurrency,
            serverError: submit.fieldError('rate_per_km'),
            onChanged: changed,
          ),
        ],
        AppField(
          controller: _drivers,
          label: 'fleet_contract.drivers_count'.tr(),
          hint: 'common.optional'.tr(),
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          serverError: submit.fieldError('drivers_count'),
        ),
        AppField(
          controller: _expected,
          label: 'fleet_contract.expected_per_month'.tr(),
          hint: 'common.optional'.tr(),
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          serverError: submit.fieldError('expected_deliveries_per_month'),
        ),
        AppField(
          controller: _coverage,
          label: 'fleet_contract.coverage_notes'.tr(),
          hint: 'fleet_contract.coverage_hint'.tr(),
          maxLength: 500,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          serverError: submit.fieldError('coverage_notes'),
        ),
        FormMessage(message: submit.message),
        SubmitButton(
          busy: submit.isSubmitting,
          label: 'fleet_contract.send_request'.tr(),
          onPressed: _ready ? _submit : null,
        ),
      ],
    );
  }
}

/// A service code in words; an unknown code is shown as it came.
String _serviceLabel(String code) {
  final key = 'fleet_contract.service_$code';
  final translated = key.tr();
  return translated == key ? code.replaceAll('_', ' ') : translated;
}

class _CompanySummary extends StatelessWidget {
  final FleetCompany company;

  const _CompanySummary({required this.company});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (company.coverageAreas.isNotEmpty) company.coverageAreas,
      if (company.serviceTypes.isNotEmpty) company.serviceTypes.map(_serviceLabel).join('، '),
      if (company.driverCount != null)
        'fleet_contract.n_drivers'.tr(namedArgs: {'n': '${company.driverCount}'}),
      if (company.ratingAvg != null) '★ ${company.ratingAvg!.toStringAsFixed(1)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
      child: Text(parts.join(' · '), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
