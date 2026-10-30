import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/compliance/marketer.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';

ComplianceRepository get _repo => getIt<ComplianceRepository>();

/// A commission row, shared by both sides. Earned only once its invoice is
/// paid — the label says so in the server's own words.
Widget _commissionTile(BuildContext context, MarketerCommission c) => DocumentTile(
      code: c.purchaseOrderCode,
      title: c.assignmentNo,
      subtitle: [
        if (c.invoiceNo.isNotEmpty) c.invoiceNo,
        c.statusLabel,
        if (c.earnedAt != null) AppDates.riyadh(c.earnedAt, context.locale.toString()),
      ].where((s) => s.isNotEmpty).join(' · '),
      status: c.status,
      amount: c.commissionAmount,
      currency: c.currencyCode,
      icon: Icons.percent_rounded,
      onTap: () {},
    );

// ---------------------------------------------------------------- marketer side

/// The marketer's own home: profile and referral code, totals, assignments to
/// accept, commissions.
class MarketerHomeView extends StatefulWidget {
  const MarketerHomeView({super.key});

  @override
  State<MarketerHomeView> createState() => _MarketerHomeViewState();
}

class _MarketerHomeViewState extends State<MarketerHomeView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DetailCubit<MarketerOverview>(_repo.marketerOverview)..load(),
        child: BlocBuilder<DetailCubit<MarketerOverview>, DetailState<MarketerOverview>>(
          builder: (context, state) {
            final cubit = context.read<DetailCubit<MarketerOverview>>();
            final data = state.data;
            return Scaffold(
              appBar: AppBar(title: Text('marketer.title'.tr())),
              body: Builder(builder: (context) {
                if (state.loading && data == null) return const DetailSkeleton();
                if (data == null) {
                  if (state.offline) return AppOfflineState(onRetry: cubit.load);
                  return AppErrorState(message: messageOr(state.errorMessage), onRetry: cubit.load);
                }
                if (!data.isRegistered) return _Register(cubit: cubit, state: state);
                return Column(
                  children: [
                    Padding(
                      padding: AppTokens.pagePadding,
                      child: _ProfileCard(overview: data),
                    ),
                    AppFilterBar(
                      options: [
                        AppFilterOption(label: 'marketer.assignments'.tr(), selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                        AppFilterOption(label: 'marketer.commissions'.tr(), selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                      ],
                    ),
                    Expanded(
                      child: _tab == 0
                          ? _MyAssignments(onChanged: cubit.load)
                          : _PagedBody<MarketerCommission>(
                              fetch: (page) => _repo.myMarketerCommissions(page: page),
                              emptyTitle: 'marketer.no_commissions'.tr(),
                              emptyBody: 'marketer.no_commissions_hint'.tr(),
                              icon: Icons.percent_rounded,
                              item: _commissionTile,
                            ),
                    ),
                  ],
                );
              }),
            );
          },
        ),
      );
}

class _Register extends StatelessWidget {
  final DetailCubit<MarketerOverview> cubit;
  final DetailState<MarketerOverview> state;

  const _Register({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) => ListView(
        padding: AppTokens.pagePadding,
        children: [
          AppEmptyState(
            icon: Icons.campaign_outlined,
            title: 'marketer.register_title'.tr(),
            body: 'marketer.register_body'.tr(),
          ),
          FormMessage(message: state.action.message),
          SubmitButton(
            busy: state.action.isSubmitting,
            label: 'marketer.register'.tr(),
            onPressed: () => cubit.run(_repo.registerMarketer),
          ),
        ],
      );
}

class _ProfileCard extends StatelessWidget {
  final MarketerOverview overview;

  const _ProfileCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final p = overview.profile!;
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              Expanded(child: Text('marketer.referral_code'.tr(), style: theme.textTheme.labelMedium)),
              SelectableText(p.referralCode, style: AppType.code(context.tokens.textPrimary)),
              IconButton(
                tooltip: 'marketer.copy'.tr(),
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: p.referralCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('marketer.copied'.tr())));
                },
              ),
            ],
          ),
          Text('marketer.referral_hint'.tr(), style: theme.textTheme.labelSmall),
          const SizedBox(height: AppTokens.space3),
          Row(
            children: [
              for (final (label, value) in [
                ('status.earned'.tr(), overview.earned),
                ('status.pending'.tr(), overview.pending),
                ('status.void'.tr(), overview.voided),
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text(label, style: theme.textTheme.labelSmall),
                      MoneyText(value),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyAssignments extends StatelessWidget {
  final Future<void> Function() onChanged;

  const _MyAssignments({required this.onChanged});

  @override
  Widget build(BuildContext context) => _PagedBody<MarketerAssignment>(
        fetch: (page) => _repo.myMarketerAssignments(page: page),
        emptyTitle: 'marketer.no_assignments'.tr(),
        emptyBody: 'marketer.no_assignments_hint'.tr(),
        icon: Icons.assignment_ind_outlined,
        item: (context, a) => DocumentTile(
          code: a.assignmentNo,
          title: a.supplierName,
          subtitle: '${a.rateLabel} · ${'marketer.earned_on_collection'.tr()}',
          status: a.status,
          icon: Icons.assignment_ind_outlined,
          badge: a.isOffered ? AppBadge('marketer.offer'.tr(), tone: AppTone.info) : null,
          onTap: () => _showAssignment(context, a, onChanged),
        ),
      );

  static Future<void> _showAssignment(BuildContext context, MarketerAssignment a, Future<void> Function() onChanged) async {
    final paged = context.read<FetchPagedCubit<MarketerAssignment>>();
    var submit = const SubmitState();
    await showAppSheet<void>(
      context: context,
      title: a.assignmentNo,
      subtitle: a.supplierName,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailRow(label: 'marketer.rate'.tr(), value: Text(a.rateLabel)),
            DetailRow(label: 'marketer.earned_on'.tr(), value: Text('marketer.earned_on_collection'.tr())),
            DetailRow(label: 'quotation.sent_at'.tr(), value: Text(AppDates.riyadh(a.createdAt, sheet.locale.toString()))),
            if (a.acceptedAt != null)
              DetailRow(label: 'quotation.accepted_at'.tr(), value: Text(AppDates.riyadh(a.acceptedAt, sheet.locale.toString()))),
            if (a.isOffered) ...[
              const SizedBox(height: AppTokens.space3),
              // Level 1: a click acceptance.
              Text('acceptance.click_legal'.tr(), style: Theme.of(sheet).textTheme.labelMedium),
              const SizedBox(height: AppTokens.space2),
              FormMessage(message: submit.message),
              SubmitButton(
                busy: submit.isSubmitting,
                label: 'marketer.accept'.tr(),
                onPressed: () async {
                  setSheet(() => submit = const SubmitState(status: FormStatus.submitting));
                  final result = await _repo.acceptMarketerAssignment(a.id);
                  if (!sheet.mounted) return;
                  if (result is Ok || result is NoContent) {
                    Navigator.of(sheet).pop();
                    await paged.refresh();
                    await onChanged();
                    return;
                  }
                  setSheet(() => submit = result.failureState);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A paginated body without its own scaffold, for tabbed screens.
class _PagedBody<T> extends StatelessWidget {
  final Future<ApiResult<Paged<T>>> Function(int page) fetch;
  final String emptyTitle;
  final String emptyBody;
  final IconData icon;
  final Widget Function(BuildContext context, T item) item;

  const _PagedBody({
    required this.fetch,
    required this.emptyTitle,
    required this.emptyBody,
    required this.icon,
    required this.item,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FetchPagedCubit<T>(fetch)..load(),
        child: BlocBuilder<FetchPagedCubit<T>, PagedState<T>>(
          builder: (context, state) {
            final cubit = context.read<FetchPagedCubit<T>>();
            return PagedListView<T>(
              state: state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: icon,
              emptyTitle: emptyTitle,
              emptyBody: emptyBody,
              itemBuilder: (row) => item(context, row),
            );
          },
        ),
      );
}

// ---------------------------------------------------------------- supplier side

/// The supplier's marketers: offer an assignment by referral code, end one,
/// link an order to it, and read the commissions it earns.
class SupplierMarketersView extends StatefulWidget {
  const SupplierMarketersView({super.key});

  @override
  State<SupplierMarketersView> createState() => _SupplierMarketersViewState();
}

class _SupplierMarketersViewState extends State<SupplierMarketersView> {
  int _tab = 0;
  int _generation = 0;

  Future<void> _offer() async {
    final code = TextEditingController();
    final rate = TextEditingController();
    var submit = const SubmitState();
    final created = await showAppSheet<bool>(
      context: context,
      title: 'marketer.offer_title'.tr(),
      subtitle: 'marketer.offer_hint'.tr(),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              controller: code,
              label: 'marketer.referral_code'.tr(),
              textDirection: TextDirection.ltr,
              serverError: submit.fieldError('marketer_code'),
            ),
            AppField(
              controller: rate,
              label: 'marketer.rate_percent'.tr(),
              suffixText: '%',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              serverError: submit.fieldError('rate_value'),
            ),
            const SizedBox(height: AppTokens.space3),
            FormMessage(message: submit.message),
            SubmitButton(
              busy: submit.isSubmitting,
              label: 'marketer.send_offer'.tr(),
              onPressed: () async {
                setSheet(() => submit = const SubmitState(status: FormStatus.submitting));
                final result = await _repo.offerMarketerAssignment(
                  marketerCode: code.text.trim(),
                  rateType: 'percent',
                  rateValue: double.tryParse(rate.text.trim()) ?? 0,
                );
                if (!sheet.mounted) return;
                if (result is Ok<MarketerAssignment>) {
                  Navigator.of(sheet).pop(true);
                  return;
                }
                setSheet(() => submit = result.failureState);
              },
            ),
          ],
        ),
      ),
    );
    if (created == true && mounted) setState(() => _generation++);
  }

  Future<void> _manage(MarketerAssignment a) async {
    final po = TextEditingController();
    var submit = const SubmitState();
    await showAppSheet<void>(
      context: context,
      title: a.assignmentNo,
      subtitle: a.marketer?.displayName,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          Future<void> act(Future<ApiResult<void>> Function() call, String okMessage) async {
            setSheet(() => submit = const SubmitState(status: FormStatus.submitting));
            final result = await call();
            if (!sheet.mounted) return;
            setSheet(() => submit = (result is Ok || result is NoContent)
                ? SubmitState(status: FormStatus.success, message: okMessage)
                : result.failureState);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailRow(label: 'marketer.rate'.tr(), value: Text(a.rateLabel)),
              DetailRow(label: 'marketer.status'.tr(), value: StatusChip(status: a.status)),
              if (a.isActive) ...[
                const SizedBox(height: AppTokens.space3),
                AppField(
                  controller: po,
                  label: 'marketer.link_po'.tr(),
                  helper: 'marketer.link_po_hint'.tr(),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                ),
                FormMessage(message: submit.message, success: submit.isSuccess),
                AppButton.outline(
                  label: 'marketer.link'.tr(),
                  height: 44,
                  onPressed: submit.isSubmitting
                      ? null
                      : () {
                          final id = int.tryParse(po.text.trim());
                          if (id != null) act(() => _repo.linkMarketerPurchaseOrder(a.id, id), 'marketer.linked'.tr());
                        },
                ),
                const SizedBox(height: AppTokens.space3),
                AppButton.outlineDanger(
                  label: 'marketer.end'.tr(),
                  height: 44,
                  onPressed: submit.isSubmitting ? null : () => act(() => _repo.endMarketerAssignment(a.id), 'marketer.ended'.tr()),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('marketer.supplier_title'.tr())),
        floatingActionButton: _tab == 0
            ? FloatingActionButton.extended(
                onPressed: _offer,
                icon: const Icon(Icons.person_add_alt_outlined),
                label: Text('marketer.offer_title'.tr()),
              )
            : null,
        body: Column(
          children: [
            AppFilterBar(
              options: [
                AppFilterOption(label: 'marketer.assignments'.tr(), selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                AppFilterOption(label: 'marketer.commissions'.tr(), selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
              ],
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('$_tab-$_generation'),
                child: _tab == 0
                    ? _PagedBody<MarketerAssignment>(
                        fetch: (page) => _repo.supplierMarketerAssignments(page: page),
                        emptyTitle: 'marketer.no_assignments'.tr(),
                        emptyBody: 'marketer.supplier_empty_hint'.tr(),
                        icon: Icons.assignment_ind_outlined,
                        item: (context, a) => DocumentTile(
                          code: a.assignmentNo,
                          title: a.marketer?.displayName ?? '',
                          subtitle: a.rateLabel,
                          status: a.status,
                          icon: Icons.assignment_ind_outlined,
                          onTap: () => _manage(a),
                        ),
                      )
                    : _PagedBody<MarketerCommission>(
                        fetch: (page) => _repo.supplierMarketerCommissions(page: page),
                        emptyTitle: 'marketer.no_commissions'.tr(),
                        emptyBody: 'marketer.no_commissions_hint'.tr(),
                        icon: Icons.percent_rounded,
                        item: _commissionTile,
                      ),
              ),
            ),
          ],
        ),
      );
}
