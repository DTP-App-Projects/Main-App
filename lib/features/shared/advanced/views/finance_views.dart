import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/advanced/finance.dart';
import '../../../../data/models/bootstrap/flags.dart';
import '../../../../data/repositories/account_repository.dart';
import '../view_models/advanced_cubits.dart';

/// A state view never shows an empty message.
String _messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

/// Settlement runs. Every figure is the server's arithmetic, shown as sent.
class SettlementsView extends StatelessWidget {
  const SettlementsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SettlementsCubit(getIt<AccountRepository>())..load(),
        child: const _SettlementsBody(),
      );
}

class _SettlementsBody extends StatelessWidget {
  const _SettlementsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SettlementsCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('settlement.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.status == null,
                onTap: () => cubit.setStatus(null),
              ),
              for (final status in Settlement.statuses)
                AppFilterOption(
                  label: 'settlement.status_$status'.tr(),
                  selected: cubit.status == status,
                  onTap: () => cubit.setStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<Settlement>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.account_balance_outlined,
              emptyTitle: 'settlement.empty'.tr(),
              itemBuilder: (settlement) => _SettlementCard(settlement: settlement),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gross → deductions → the net payable, read top to bottom like a ledger.
class _SettlementCard extends StatelessWidget {
  final Settlement settlement;

  const _SettlementCard({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    Widget deduction(String label, double amount) => DetailRow(
          label: label,
          value: _Deduction(amount: amount),
        );

    return AppCard.item(
      padding: const EdgeInsetsDirectional.all(AppTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconCircle(Icons.date_range_outlined, size: 40),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Text(
                  '${AppDates.date(settlement.periodStart, locale)}'
                  ' – ${AppDates.date(settlement.periodEnd, locale)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: settlement.status),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          DetailRow(
            label: 'settlement.gross_sales'.tr(),
            value: MoneyText(settlement.grossSales, style: AppType.ledger(t.textPrimary)),
          ),
          deduction('settlement.returns'.tr(), settlement.returnsTotal),
          deduction('settlement.damage'.tr(), settlement.damageTotal),
          deduction('settlement.expiry'.tr(), settlement.expiryTotal),
          deduction('settlement.shelf_fees'.tr(), settlement.shelfFees),
          Divider(height: AppTokens.space4, color: t.divider),
          Row(
            children: [
              Expanded(
                child: Text('settlement.net_payable'.tr(), style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: AppTokens.space3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: MoneyText(
                    settlement.netPayableSupplier,
                    style: AppType.stat(t.primary),
                  ),
                ),
              ),
            ],
          ),
          if (settlement.payouts.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space3),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppTokens.space3,
                vertical: AppTokens.space1,
              ),
              decoration: BoxDecoration(color: t.neutralTint, borderRadius: AppTokens.mdRadius),
              child: Column(
                children: [
                  for (final payout in settlement.payouts)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space2),
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 20, color: t.iconMuted),
                          const SizedBox(width: AppTokens.space2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MoneyText(payout.amount, style: AppType.ledger(t.textPrimary)),
                                if (payout.referenceNo.isNotEmpty)
                                  Text(
                                    payout.referenceNo,
                                    style: theme.textTheme.bodySmall,
                                    textDirection: TextDirection.ltr,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: payout.status),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A deduction, shown with its minus sign and in the muted ink so the eye
/// reads it as subtracted from the gross above.
class _Deduction extends StatelessWidget {
  final double amount;

  const _Deduction({required this.amount});

  @override
  Widget build(BuildContext context) {
    final style = AppType.ledger(context.tokens.textSecondary).copyWith(
      fontWeight: FontWeight.w500,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      // The sign sits before the figure in both languages.
      textDirection: TextDirection.ltr,
      children: [
        Text('−', style: style),
        const SizedBox(width: 2),
        Flexible(child: MoneyText(amount, style: style)),
      ],
    );
  }
}

/// The organization wallet, its history, and how to top it up.
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WalletCubit(getIt<AccountRepository>())..load(),
        child: const _WalletBody(),
      );
}

class _WalletBody extends StatelessWidget {
  const _WalletBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<WalletCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('wallet.title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading && state.wallet == null) return const DetailSkeleton();
          if (state.wallet == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
          }

          final wallet = state.wallet!;
          final currency = wallet.currencyCode.isEmpty ? 'SAR' : wallet.currencyCode;
          final onGradient = Colors.white.withValues(alpha: 0.82);

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                FormMessage(
                  message: state.action.message,
                  success: state.action.isSuccess,
                ),
                // The balance hero: the one gradient on the screen.
                Container(
                  padding: const EdgeInsetsDirectional.all(AppTokens.cardPadding),
                  decoration: const BoxDecoration(
                    gradient: AppTokens.brandGradient,
                    borderRadius: AppTokens.xlRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 20, color: onGradient),
                          const SizedBox(width: AppTokens.space2),
                          Text(
                            'wallet.balance'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(color: onGradient),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: MoneyText(
                          wallet.balance,
                          currency: currency,
                          style: AppType.ledgerLarge(Colors.white),
                        ),
                      ),
                      if (wallet.pendingBalance > 0) ...[
                        const SizedBox(height: AppTokens.space3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'wallet.pending'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(color: onGradient),
                              ),
                            ),
                            MoneyText(
                              wallet.pendingBalance,
                              style: AppType.ledger(Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                AppButton.solid(
                  icon: Icons.add_card_rounded,
                  label: 'wallet.topup'.tr(),
                  onPressed: state.methods.isEmpty ? null : () => _topup(context, cubit),
                ),
                if (state.methods.isEmpty) ...[
                  const SizedBox(height: AppTokens.space2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: t.iconMuted),
                      const SizedBox(width: AppTokens.space1 + 2),
                      Expanded(
                        child: Text(
                          'wallet.topup_unavailable'.tr(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],

                AppSectionLabel('wallet.transactions'.tr()),
                if (state.transactions.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        const AppIconCircle(Icons.receipt_long_outlined, tone: AppTone.neutral),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: Text(
                            'wallet.no_transactions'.tr(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AppCard.section(
                    child: Column(
                      children: [
                        for (var i = 0; i < state.transactions.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: AppTokens.space4 + 40 + AppTokens.space3,
                                end: AppTokens.space4,
                              ),
                              child: Divider(height: 1, color: t.divider),
                            ),
                          _TransactionRow(transaction: state.transactions[i], locale: locale),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _topup(BuildContext context, WalletCubit cubit) => showAppSheet<void>(
        context: context,
        title: 'wallet.topup'.tr(),
        builder: (_) => BlocProvider.value(value: cubit, child: const _TopupSheet()),
      );
}

class _TransactionRow extends StatelessWidget {
  final WalletTransaction transaction;
  final String locale;

  const _TransactionRow({required this.transaction, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final date = AppDates.date(transaction.createdAt, locale);
    final title = transaction.description.isNotEmpty ? transaction.description : date;
    final subtitle = transaction.description.isNotEmpty ? date : '';

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppTokens.space4,
        vertical: AppTokens.space3,
      ),
      child: Row(
        children: [
          AppIconCircle(
            transaction.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 40,
            tone: transaction.isCredit ? AppTone.brand : AppTone.danger,
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subtitle.isNotEmpty) Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(
                transaction.amount,
                colorNegative: true,
                style: AppType.ledger(t.textPrimary),
              ),
              if (transaction.status.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space1),
                StatusChip(status: transaction.status),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TopupSheet extends StatefulWidget {
  const _TopupSheet();

  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();

  String? _method;
  String? _proofPath;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<WalletCubit>();
    final state = cubit.state;
    final locale = context.locale.toString();

    // A gateway the platform has switched off must not be offered, even if
    // the methods endpoint still lists it.
    final flags = context.watch<SessionCubit>().state.bootstrap?.platformFlags;
    final methods = state.methods.where((method) {
      if (!method.enabled) return false;
      if (method.code == TopupMethod.hyperpay) {
        return flags?.paymentGatewayEnabled ?? false;
      }
      if (method.code == TopupMethod.applePay) return flags?.applePayEnabled ?? false;
      if (method.code == TopupMethod.bankTransfer) {
        return flags?.bankTransferEnabled ?? true;
      }
      return true;
    }).toList();

    final bankTransfer = _method == TopupMethod.bankTransfer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormMessage(message: state.action.message),

        AppField(
          controller: _amount,
          label: 'invoice.amount'.tr(),
          required: true,
          icon: Icons.payments_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          helper: 'wallet.min_amount'.tr(),
          serverError: state.action.fieldError('amount'),
        ),
        CodePicker(
          label: 'wallet.method'.tr(),
          value: _method,
          codes: methods.map((method) => method.code).toList(),
          labelOf: (code) => methods
              .firstWhere(
                (method) => method.code == code,
                orElse: () => TopupMethod(
                  code: code,
                  labelAr: '',
                  labelEn: code,
                  enabled: true,
                ),
              )
              .label(locale),
          error: state.action.fieldError('method'),
          onChanged: (value) => setState(() => _method = value),
        ),

        // Only a bank transfer needs a reference and a receipt.
        if (bankTransfer) ...[
          AppField(
            controller: _reference,
            label: 'wallet.bank_reference'.tr(),
            textDirection: TextDirection.ltr,
            serverError: state.action.fieldError('bank_reference'),
          ),
          ProofFileField(
            label: 'wallet.transfer_proof'.tr(),
            module: 'wallet',
            fieldKey: 'transfer_proof_path',
            onUploaded: (path) => _proofPath = path,
          ),
        ],

        const SizedBox(height: AppTokens.space2),
        SubmitButton(
          busy: state.action.isSubmitting,
          label: 'wallet.request_topup'.tr(),
          onPressed: _method == null
              ? null
              : () async {
                  final amount = double.tryParse(_amount.text.trim()) ?? 0;
                  if (amount < 1) return;
                  final ok = await cubit.requestTopup(
                    amount: amount,
                    method: _method!,
                    bankReference:
                        _reference.text.trim().isEmpty ? null : _reference.text.trim(),
                    proofPath: _proofPath,
                  );
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

/// The plan, the billing mode, and the trial.
class SubscriptionView extends StatelessWidget {
  const SubscriptionView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SubscriptionCubit(getIt<AccountRepository>())..load(),
        child: const _SubscriptionBody(),
      );
}

class _SubscriptionBody extends StatelessWidget {
  const _SubscriptionBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SubscriptionCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('subscription.title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading && state.summary == null) return const DetailSkeleton();
          if (state.summary == null && state.errorMessage != null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
          }

          final summary = state.summary;
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                FormMessage(
                  message: state.action.message,
                  success: state.action.isSuccess,
                ),
                if (summary != null)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppIconCircle(Icons.workspace_premium_outlined),
                            const SizedBox(width: AppTokens.space3),
                            Expanded(
                              child: Text(
                                summary.planName.isEmpty
                                    ? 'subscription.no_plan'.tr()
                                    : summary.planName,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: AppTokens.space2),
                            StatusChip(status: summary.status),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space3),
                        DetailRow(
                          label: 'subscription.billing_mode'.tr(),
                          value: Text(
                            summary.billingMode.isEmpty
                                ? '—'
                                : 'subscription.mode_${summary.billingMode}'.tr(),
                          ),
                        ),
                        if (summary.renewsAt != null)
                          DetailRow(
                            label: 'subscription.renews'.tr(),
                            value: DateText(summary.renewsAt),
                          ),
                        if (summary.trialEndsAt != null)
                          DetailRow(
                            label: 'subscription.trial_ends'.tr(),
                            value: DateText(summary.trialEndsAt),
                          ),
                      ],
                    ),
                  ),

                AppSectionLabel('subscription.billing_mode'.tr()),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('subscription.billing_mode_hint'.tr(), style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppTokens.space3),
                      Wrap(
                        spacing: AppTokens.space2,
                        runSpacing: AppTokens.space2,
                        children: [
                          for (final mode in SubscriptionSummary.billingModes)
                            ChoiceChip(
                              label: Text('subscription.mode_$mode'.tr()),
                              selected: summary?.billingMode == mode,
                              onSelected: state.action.isSubmitting
                                  ? null
                                  : (_) => cubit.setBillingMode(mode),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (summary != null && !summary.onTrial) ...[
                  const SizedBox(height: AppTokens.space4),
                  AppButton.outline(
                    icon: Icons.card_giftcard_rounded,
                    label: 'subscription.start_trial'.tr(),
                    onPressed: state.action.isSubmitting ? null : cubit.startTrial,
                  ),
                ],

                AppSectionLabel('subscription.plans'.tr()),
                if (state.plans.isEmpty)
                  AppCard(
                    child: Text('subscription.no_plans'.tr(), style: theme.textTheme.bodySmall),
                  )
                else
                  for (final plan in state.plans)
                    _PlanCard(
                      name: plan.label(locale),
                      current: plan.id == summary?.planId,
                      monthly: plan.monthlyPrice,
                      yearly: plan.yearlyPrice,
                      currency: plan.currencyCode.isEmpty ? 'SAR' : plan.currencyCode,
                    ),
                const SizedBox(height: AppTokens.space2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: t.iconMuted),
                    const SizedBox(width: AppTokens.space1 + 2),
                    Expanded(
                      child: Text(
                        'subscription.payment_note'.tr(),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A plan as a selectable-looking card. Display only: the current plan is
/// the marked one; choosing a plan is not something this screen does.
class _PlanCard extends StatelessWidget {
  final String name;
  final bool current;
  final double monthly;
  final double yearly;
  final String currency;

  const _PlanCard({
    required this.name,
    required this.current,
    required this.monthly,
    required this.yearly,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return AppCard.item(
      color: current ? t.primaryTintSoft : null,
      borderColor: current ? t.primary : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            current ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: current ? t.primary : t.iconMuted,
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
                    if (current) const StatusChip(status: 'active'),
                  ],
                ),
                const SizedBox(height: AppTokens.space1),
                DetailRow(
                  label: 'subscription.monthly'.tr(),
                  value: MoneyText(monthly, currency: currency, style: AppType.ledger(t.textPrimary)),
                ),
                if (yearly > 0)
                  DetailRow(
                    label: 'subscription.yearly'.tr(),
                    value: MoneyText(yearly, currency: currency, style: AppType.ledger(t.textPrimary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
