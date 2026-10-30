import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../shared/compliance/compliance_widgets.dart';
import '../../shared/compliance/views/relationship_supply_panel.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../core/workspace/workspace.dart';
import '../../../data/models/trade/pricing.dart';
import '../../../data/models/trade/supplier_summary.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../view_models/supplier_cubits.dart';

/// Who this organization trades with, and on what terms — «العلاقات
/// التجارية» for both sides (guide Part 6.4). The supplier side adds its
/// own controls (suspend, credit); the trader side opens the supplier.
class RelationshipsView extends StatelessWidget {
  final Workspace side;

  const RelationshipsView({super.key, this.side = Workspace.supplier});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => RelationshipsCubit(getIt<SupplierRepository>())..load(),
        child: _RelationshipsBody(side: side),
      );
}

class _RelationshipsBody extends StatelessWidget {
  final Workspace side;

  const _RelationshipsBody({required this.side});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<RelationshipsCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('relationship.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.status == null,
                onTap: () => cubit.setStatus(null),
              ),
              for (final status in SupplierRepository.relationshipStatuses)
                AppFilterOption(
                  label: 'relationship.status_$status'.tr(),
                  selected: cubit.status == status,
                  onTap: () => cubit.setStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<BusinessRelationship>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.handshake_outlined,
              emptyTitle: 'relationship.empty'.tr(),
              itemBuilder: (relationship) => _RelationshipCard(relationship: relationship, side: side),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  final BusinessRelationship relationship;
  final Workspace side;

  const _RelationshipCard({required this.relationship, required this.side});

  bool get _isSupplier => side == Workspace.supplier;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RelationshipsCubit>();
    final theme = Theme.of(context);
    final name = relationship.counterparty?.name ?? '#${relationship.id}';

    return AppCard.item(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.space4,
        AppTokens.space4,
        AppTokens.space4,
        AppTokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppInitialAvatar(name: name, size: 40),
              const SizedBox(width: AppTokens.space3),
              Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: relationship.status),
            ],
          ),
          if (!relationship.isSupplyActive) ...[
            const SizedBox(height: AppTokens.space2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SupplyStatusPill(status: relationship.supplyStatus),
            ),
          ],
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: AppTokens.space2,
            runSpacing: AppTokens.space2,
            children: [
              AppBadge(
                '${'relationship.open_orders'.tr()}  ${relationship.openPurchaseOrdersCount}',
                tone: AppTone.neutral,
                icon: Icons.receipt_long_outlined,
              ),
              AppBadge(
                '${'supplier.contracts'.tr()}  ${relationship.contractsCount}',
                tone: AppTone.neutral,
                icon: Icons.description_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space1),
          // A Wrap, not a Row: three labelled actions do not fit one line in
          // Arabic on a narrow phone.
          Wrap(
            spacing: AppTokens.space1,
            children: [
              // A pending relationship is accepted on its request, by the
              // signatory, with a verification code (guide Part 6.3) — never
              // by a plain "Approve" here, which set it approved with neither.
              if (relationship.status == 'pending_review')
                AppButton.text(
                  label: 'relationship.review_request'.tr(),
                  icon: Icons.fact_check_outlined,
                  onPressed: () => context.push(AppRoutes.relationshipRequests),
                )
              else if (_isSupplier && relationship.status == 'suspended')
                AppButton.text(
                  label: 'relationship.reactivate'.tr(),
                  icon: Icons.play_circle_outline_rounded,
                  onPressed: () => _confirmReactivate(context, cubit),
                )
              else if (_isSupplier && relationship.isApproved)
                _DangerTextButton(
                  label: 'relationship.suspend'.tr(),
                  icon: Icons.pause_circle_outline_rounded,
                  onPressed: () => _confirmSuspend(context, cubit),
                ),
              if (!_isSupplier && relationship.counterparty != null)
                AppButton.text(
                  label: 'relationship.open_supplier'.tr(),
                  icon: Icons.storefront_outlined,
                  onPressed: () => context.push(AppRoutes.supplierDetailFor(relationship.counterparty!.id)),
                ),
              AppButton.text(
                label: 'rating.title'.tr(),
                icon: Icons.star_border_rounded,
                onPressed: () => context.push(AppRoutes.ratingsFor(relationship.id)),
              ),
              if (_isSupplier)
                AppButton.text(
                  label: 'credit.title'.tr(),
                  icon: Icons.credit_score_outlined,
                  onPressed: () => context.push(AppRoutes.creditFor(relationship.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Lifting a suspension the supplier itself applied — not the acceptance
  /// of a request, which only the signatory's code can give.
  Future<void> _confirmReactivate(BuildContext context, RelationshipsCubit cubit) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'relationship.reactivate'.tr(),
      body: relationship.counterparty?.name,
      confirmLabel: 'relationship.reactivate'.tr(),
    );
    if (!confirmed) return;
    await cubit.setRelationshipStatus(id: relationship.id, value: 'approved');
  }

  Future<void> _confirmSuspend(BuildContext context, RelationshipsCubit cubit) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'relationship.suspend'.tr(),
      body: 'relationship.suspend_confirm'.tr(),
      confirmLabel: 'relationship.suspend'.tr(),
      destructive: true,
    );
    if (!confirmed) return;
    await cubit.setRelationshipStatus(id: relationship.id, value: 'suspended');
  }
}

/// A text action in the danger colour (the kit's text button is teal only).
class _DangerTextButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _DangerTextButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: t.dangerText,
        minimumSize: const Size(64, 48),
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.mdRadius),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// The credit profile.
///
/// The two freeze switches are the ones that matter: they are what stops the
/// trader's *next* order, so the screen says that rather than leaving them as
/// unexplained toggles.
class CreditView extends StatelessWidget {
  final int relationshipId;

  const CreditView({super.key, required this.relationshipId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CreditCubit(getIt<SupplierRepository>(), relationshipId)..load(),
        child: const _CreditBody(),
      );
}

class _CreditBody extends StatefulWidget {
  const _CreditBody();

  @override
  State<_CreditBody> createState() => _CreditBodyState();
}

class _CreditBodyState extends State<_CreditBody> {
  final _creditLimit = TextEditingController();
  final _maxDueDays = TextEditingController();
  final _maxOverdueDays = TextEditingController();
  final _upfront = TextEditingController();

  String? _grade;
  bool _freezeOnLimit = true;
  bool _freezeOnOverdue = true;
  bool _prefilled = false;

  @override
  void dispose() {
    for (final controller in [_creditLimit, _maxDueDays, _maxOverdueDays, _upfront]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefillOnce(CreditProfile? profile) {
    if (_prefilled || profile == null) return;
    _grade = profile.grade.isEmpty ? 'B' : profile.grade;
    _creditLimit.text = profile.creditLimit.toStringAsFixed(2);
    _maxDueDays.text = '${profile.maxDueDays}';
    _maxOverdueDays.text = '${profile.maxOverdueDays}';
    _upfront.text = profile.upfrontRequiredPercent.toStringAsFixed(0);
    _freezeOnLimit = profile.autoFreezeOnLimit;
    _freezeOnOverdue = profile.autoFreezeOnOverdue;
    _prefilled = true;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CreditCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;

    final showForm = !(state.loading && state.profile == null && state.exposure == null) &&
        !(state.errorMessage != null && state.profile == null);

    return Scaffold(
      appBar: AppBar(title: Text('credit.title'.tr())),
      bottomNavigationBar: !showForm
          ? null
          : AppBottomBar(
              // The save's error sits right above the save button.
              leading: (state.action.message ?? '').isEmpty ? null : FormMessage(message: state.action.message),
              child: SubmitButton(
                busy: state.action.isSubmitting,
                label: 'common.save'.tr(),
                onPressed: () => cubit.save(
                  grade: _grade ?? 'B',
                  creditLimit: double.tryParse(_creditLimit.text.trim()) ?? 0,
                  maxDueDays: int.tryParse(_maxDueDays.text.trim()),
                  maxOverdueDays: int.tryParse(_maxOverdueDays.text.trim()),
                  upfrontRequiredPercent: double.tryParse(_upfront.text.trim()),
                  autoFreezeOnLimit: _freezeOnLimit,
                  autoFreezeOnOverdue: _freezeOnOverdue,
                ),
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading && state.profile == null && state.exposure == null) {
            return const FormSkeleton(fields: 5);
          }
          if (state.errorMessage != null && state.profile == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage!;
            return AppErrorState(
              message: message.isEmpty ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }

          _prefillOnce(state.profile);
          final exposure = state.exposure;
          final currency = state.profile?.currencyCode ?? '';
          final currencySuffix = currency.isEmpty ? null : currency;

          Widget money(double value, Color color) =>
              MoneyText(value, style: AppType.stat(color));

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              AppTokens.space3,
              AppTokens.gutter,
              AppTokens.space8,
            ),
            children: [
              // Supply status (late-payment path), restore, dispute pack.
              RelationshipSupplyPanel(relationshipId: context.read<CreditCubit>().relationshipId),

              if (exposure != null) ...[
                AppSectionLabel(
                  'credit.exposure'.tr(),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.space1,
                    0,
                    AppTokens.space1,
                    AppTokens.space3,
                  ),
                ),
                // The headline: what the trader can still order on credit.
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('credit.available'.tr(), style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppTokens.space1),
                      MoneyText(
                        exposure.availableCredit,
                        style: AppType.ledgerLarge(t.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
                Row(
                  children: [
                    Expanded(
                      child: AppStatTile(
                        label: 'credit.open_orders'.tr(),
                        valueWidget: money(exposure.openOrdersAmount, t.textPrimary),
                        tone: AppTone.neutral,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppStatTile(
                        label: 'credit.issued_invoices'.tr(),
                        valueWidget: money(exposure.issuedInvoicesAmount, t.textPrimary),
                        tone: AppTone.neutral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space3),
                Row(
                  children: [
                    Expanded(
                      child: AppStatTile(
                        label: 'credit.due'.tr(),
                        valueWidget: money(exposure.dueAmount, t.textPrimary),
                        tone: AppTone.neutral,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppStatTile(
                        label: 'credit.overdue'.tr(),
                        valueWidget: money(
                          exposure.overdueAmount,
                          exposure.hasOverdue ? t.dangerText : t.textPrimary,
                        ),
                        tone: exposure.hasOverdue ? AppTone.danger : AppTone.neutral,
                      ),
                    ),
                  ],
                ),
              ],

              AppSectionLabel('credit.terms'.tr()),
              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CodePicker(
                      label: 'credit.grade'.tr(),
                      value: _grade,
                      codes: CreditProfile.grades,
                      labelOf: (code) => code,
                      error: state.action.fieldError('grade'),
                      onChanged: (value) => setState(() => _grade = value),
                    ),
                    AppField(
                      controller: _creditLimit,
                      label: 'credit.limit'.tr(),
                      suffixText: currencySuffix,
                      textDirection: TextDirection.ltr,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      serverError: state.action.fieldError('credit_limit'),
                    ),
                    AppField(
                      controller: _maxDueDays,
                      label: 'credit.max_due_days'.tr(),
                      suffixText: 'credit.days_suffix'.tr(),
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      serverError: state.action.fieldError('max_due_days'),
                    ),
                    AppField(
                      controller: _maxOverdueDays,
                      label: 'credit.max_overdue_days'.tr(),
                      suffixText: 'credit.days_suffix'.tr(),
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      serverError: state.action.fieldError('max_overdue_days'),
                    ),
                    AppField(
                      controller: _upfront,
                      label: 'credit.upfront_percent'.tr(),
                      suffixText: '%',
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      serverError: state.action.fieldError('upfront_required_percent'),
                    ),
                  ],
                ),
              ),

              AppSectionLabel('credit.freeze_title'.tr()),
              AppBanner(message: 'credit.freeze_hint'.tr(), tone: AppTone.warning),
              AppCard.section(
                child: Column(
                  children: [
                    _FreezeSwitch(
                      title: 'credit.freeze_on_limit'.tr(),
                      subtitle: 'credit.freeze_on_limit_hint'.tr(),
                      value: _freezeOnLimit,
                      onChanged: (value) => setState(() => _freezeOnLimit = value),
                    ),
                    Divider(
                      height: 1,
                      indent: AppTokens.space5,
                      endIndent: AppTokens.space5,
                      color: t.divider,
                    ),
                    _FreezeSwitch(
                      title: 'credit.freeze_on_overdue'.tr(),
                      subtitle: 'credit.freeze_on_overdue_hint'.tr(),
                      value: _freezeOnOverdue,
                      onChanged: (value) => setState(() => _freezeOnOverdue = value),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FreezeSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FreezeSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppTokens.space5,
        vertical: AppTokens.space1,
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
