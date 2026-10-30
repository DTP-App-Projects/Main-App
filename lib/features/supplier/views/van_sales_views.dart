import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/money.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../core/workspace/workspace_cubit.dart';
import '../../../data/models/fleet/van_trip.dart';
import '../../../data/repositories/fleet_repository.dart';
import '../view_models/van_sales_cubits.dart';
import 'fleet_widgets.dart';

/// `fleet.manage` creates, cancels and reconciles; `fleet.view` reads. The
/// owner passes both.
bool _canManage(BuildContext context) =>
    context.watch<WorkspaceCubit>().state?.can('fleet.manage') ?? false;

/// «البيع المتجول» — the trips list: status chips with their counts, the
/// cash still out on the road, then the trips.
class VanTripsView extends StatelessWidget {
  const VanTripsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => VanTripsCubit(getIt<FleetRepository>())..load(),
    child: const _TripsBody(),
  );
}

class _TripsBody extends StatelessWidget {
  const _TripsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<VanTripsCubit>();
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final total = cubit.counts.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text('van.title'.tr())),
      floatingActionButton: _canManage(context)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.vanSalesNew);
                if (context.mounted) await cubit.refresh();
              },
              icon: const Icon(Icons.add_rounded),
              label: Text('van.new'.tr()),
            )
          : null,
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.status == null,
                count: cubit.counts.isEmpty ? null : total,
                onTap: () => cubit.filter(null),
              ),
              for (final status in VanTrip.statuses)
                AppFilterOption(
                  label: StatusChip.localize(status),
                  selected: cubit.status == status,
                  count: cubit.counts[status],
                  onTap: () => cubit.filter(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<VanTrip>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.local_shipping_outlined,
              emptyTitle: 'van.empty'.tr(),
              emptyBody: 'van.empty_hint'.tr(),
              header: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                child: AppStatTile(
                  label: 'van.cash_on_road'.tr(),
                  icon: Icons.payments_outlined,
                  valueWidget: MoneyText(cubit.cashOnRoad, style: AppType.stat(t.textPrimary)),
                ),
              ),
              itemBuilder: (trip) {
                final meta = [
                  if (trip.vehicle != null) trip.vehicle!.plateNumber,
                  if (trip.warehouse != null) trip.warehouse!.name(locale),
                ].join(' · ');
                return DocumentTile(
                  code: trip.code,
                  title: trip.driver?.name ?? 'van.no_driver'.tr(),
                  status: trip.status,
                  amount: trip.salesTotal == 0 ? null : trip.salesTotal,
                  icon: Icons.local_shipping_outlined,
                  badge: meta.isEmpty
                      ? null
                      : Text(
                          meta,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () async {
                    await context.push(AppRoutes.vanTripFor(trip.id));
                    if (context.mounted) await cubit.refresh();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One trip, laid out by its status: the load code while `draft`, live
/// figures while `on_road`, the reconciliation form while `returning`, and a
/// read-only summary once `reconciled` / `canceled`.
class VanTripDetailView extends StatelessWidget {
  final int tripId;

  const VanTripDetailView({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => VanTripCubit(getIt<FleetRepository>(), tripId)..load(),
    child: const _TripBody(),
  );
}

class _TripBody extends StatelessWidget {
  const _TripBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<VanTripCubit>();
    final state = cubit.state;
    final detail = state.detail;
    final trip = detail?.trip;
    final canManage = _canManage(context);

    return Scaffold(
      appBar: AppBar(title: Text('van.detail_title'.tr())),
      bottomNavigationBar: (trip != null && trip.isDraft && canManage)
          ? AppBottomBar(
              leading: (state.action.message ?? '').isEmpty
                  ? null
                  : FormMessage(message: state.action.message),
              child: AppButton.outlineDanger(
                label: 'van.cancel'.tr(),
                icon: Icons.cancel_outlined,
                busy: state.action.isSubmitting,
                onPressed: state.action.isSubmitting ? null : () => _cancel(context, cubit),
              ),
            )
          : null,
      body: Builder(
        builder: (context) {
          if (state.loading && detail == null) return const DetailSkeleton();
          if (detail == null || trip == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.gutter,
                AppTokens.space3,
                AppTokens.gutter,
                AppTokens.space8,
              ),
              children: [
                _TripHeader(trip: trip),
                if (trip.isDraft) ...[
                  const SizedBox(height: AppTokens.space3),
                  _LoadCodeCard(code: trip.loadCode),
                  AppSectionLabel('van.load_lines'.tr()),
                  _LinesCard(trip: trip, mode: _LinesMode.loaded),
                ] else if (trip.isOnRoad) ...[
                  AppSectionLabel(
                    'van.live_figures'.tr(),
                    trailing: Icon(Icons.sensors_rounded, size: 18, color: context.tokens.primary),
                  ),
                  _CashCard(trip: trip),
                  const SizedBox(height: AppTokens.space3),
                  _LinesCard(trip: trip, mode: _LinesMode.live),
                ] else if (trip.isReturning) ...[
                  const SizedBox(height: AppTokens.space3),
                  if (canManage)
                    _ReconcileForm(trip: trip)
                  else
                    AppBanner(tone: AppTone.info, message: 'van.returning_no_permission'.tr()),
                ] else ...[
                  if (trip.status == 'reconciled') ...[
                    AppSectionLabel('van.reconciliation'.tr()),
                    _ReconciledCard(trip: trip),
                  ],
                  AppSectionLabel('van.load_lines'.tr()),
                  _LinesCard(trip: trip, mode: _LinesMode.closed),
                ],
                if (!trip.isDraft) ...[
                  AppSectionLabel('van.sales_count'.tr(namedArgs: {'n': '${detail.sales.length}'})),
                  if (detail.sales.isEmpty)
                    _Quiet('van.no_sales'.tr())
                  else
                    for (final sale in detail.sales) _SaleCard(sale: sale),
                  AppSectionLabel(
                    'van.deliveries_count'.tr(namedArgs: {'n': '${detail.deliveries.length}'}),
                  ),
                  if (detail.deliveries.isEmpty)
                    _Quiet('van.no_deliveries'.tr())
                  else
                    for (final d in detail.deliveries)
                      DocumentTile(
                        code: d.code,
                        title: d.trader,
                        subtitle: d.traderBranch,
                        status: d.status,
                        icon: Icons.local_shipping_outlined,
                        onTap: () => context.push(AppRoutes.outboundDetailFor(d.id)),
                      ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context, VanTripCubit cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'van.cancel'.tr(),
      body: 'van.cancel_confirm'.tr(),
      confirmLabel: 'van.cancel'.tr(),
      destructive: true,
    );
    if (!ok) return;
    await cubit.cancel();
  }
}

class _Quiet extends StatelessWidget {
  final String text;

  const _Quiet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textTertiary),
    ),
  );
}

class _TripHeader extends StatelessWidget {
  final VanTrip trip;

  const _TripHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final locale = context.locale.toString();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.code,
                  style: AppType.code(t.textPrimary, size: 18),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: trip.status),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          DetailRow(label: 'van.driver'.tr(), value: Text(trip.driver?.name ?? '—')),
          if ((trip.driver?.phone ?? '').isNotEmpty)
            DetailRow(
              label: 'van.driver_phone'.tr(),
              value: Text(trip.driver!.phone, textDirection: TextDirection.ltr),
            ),
          DetailRow(
            label: 'van.vehicle'.tr(),
            value: Text(trip.vehicle?.plateNumber ?? '—', textDirection: TextDirection.ltr),
          ),
          DetailRow(label: 'van.warehouse'.tr(), value: Text(trip.warehouse?.name(locale) ?? '—')),
          if (trip.maxDiscountPercent != null)
            DetailRow(
              label: 'van.max_discount'.tr(),
              value: Text('${fmtQty(trip.maxDiscountPercent!)}%', textDirection: TextDirection.ltr),
            ),
          if (trip.loadedAt != null)
            DetailRow(label: 'van.loaded_at'.tr(), value: DateText(trip.loadedAt, withTime: true)),
          if (trip.returnStartedAt != null)
            DetailRow(
              label: 'van.return_started_at'.tr(),
              value: DateText(trip.returnStartedAt, withTime: true),
            ),
          if (trip.reconciledAt != null)
            DetailRow(
              label: 'van.reconciled_at'.tr(),
              value: DateText(trip.reconciledAt, withTime: true),
            ),
          if (trip.createdBy.isNotEmpty)
            DetailRow(label: 'van.created_by'.tr(), value: Text(trip.createdBy)),
          if (trip.notes.isNotEmpty) DetailRow(label: 'van.notes'.tr(), value: Text(trip.notes)),
        ],
      ),
    );
  }
}

/// The 6-digit load code, big: the warehouse keeper gives it to the driver
/// once the van is loaded. Always a string — a leading zero is part of it.
class _LoadCodeCard extends StatelessWidget {
  final String? code;

  const _LoadCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final value = code ?? '';
    return AppCard(
      color: t.primaryTint,
      borderColor: t.primary,
      child: Column(
        children: [
          Text('van.load_code'.tr(), style: theme.textTheme.titleSmall),
          const SizedBox(height: AppTokens.space3),
          SelectableText(
            value.isEmpty ? '—' : value.split('').join(' '),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: AppType.code(t.primary, size: 40),
          ),
          const SizedBox(height: AppTokens.space3),
          Text(
            'van.load_code_hint'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space2),
            AppButton.text(
              label: 'van.copy_code'.tr(),
              icon: Icons.copy_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('van.code_copied'.tr())));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  final VanTrip trip;

  const _CashCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: AppStatTile(
            label: 'van.cash_sales'.tr(),
            icon: Icons.payments_outlined,
            valueWidget: MoneyText(trip.cashSalesTotal, style: AppType.stat(t.textPrimary)),
          ),
        ),
        const SizedBox(width: AppTokens.space3),
        Expanded(
          child: AppStatTile(
            label: 'van.sales_made'.tr(),
            icon: Icons.receipt_long_outlined,
            value: '${trip.salesCount}',
          ),
        ),
      ],
    );
  }
}

enum _LinesMode { loaded, live, closed }

/// Per item: what went out and where it went. Loaded = sold + delivered +
/// returned + damaged + missing.
class _LinesCard extends StatelessWidget {
  final VanTrip trip;
  final _LinesMode mode;

  const _LinesCard({required this.trip, required this.mode});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    if (trip.lines.isEmpty) return _Quiet('van.no_lines'.tr());

    return AppCard.section(
      child: Column(
        children: [
          for (var i = 0; i < trip.lines.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppTokens.space5,
                endIndent: AppTokens.space5,
                color: t.divider,
              ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppTokens.space5,
                vertical: AppTokens.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(trip.lines[i].name, style: theme.textTheme.titleSmall)),
                      if (trip.lines[i].unitPrice > 0)
                        MoneyText(trip.lines[i].unitPrice, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space3),
                  _figures(context, trip.lines[i]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _figures(BuildContext context, VanTripLine line) {
    final t = context.tokens;
    final cells = <Widget>[
      FleetFigure(label: 'van.loaded'.tr(), value: line.loaded),
      if (mode != _LinesMode.loaded) ...[
        FleetFigure(label: 'van.sold'.tr(), value: line.sold),
        FleetFigure(label: 'van.delivered'.tr(), value: line.delivered),
      ],
      if (mode == _LinesMode.live) ...[
        FleetFigure(label: 'van.in_van'.tr(), value: line.inVan, color: t.primary),
        if (line.inTransit > 0) FleetFigure(label: 'van.in_transit'.tr(), value: line.inTransit),
      ],
      if (mode == _LinesMode.closed) ...[
        FleetFigure(label: 'van.returned'.tr(), value: line.returned),
        FleetFigure(
          label: 'van.damaged'.tr(),
          value: line.damaged,
          color: line.damaged > 0 ? t.warningText : null,
        ),
        FleetFigure(
          label: 'van.missing'.tr(),
          value: line.missing,
          color: line.missing > 0 ? t.dangerText : null,
        ),
      ],
    ];
    return Row(children: [for (final c in cells) Expanded(child: c)]);
  }
}

class _ReconciledCard extends StatelessWidget {
  final VanTrip trip;

  const _ReconciledCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final variance = trip.cashVariance;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailRow(
            label: 'van.cash_expected'.tr(),
            value: MoneyText(trip.cashExpected ?? trip.cashSalesTotal),
          ),
          DetailRow(label: 'van.cash_handed_over'.tr(), value: MoneyText(trip.cashHandedOver ?? 0)),
          if (variance != null)
            DetailRow(
              label: 'van.cash_variance'.tr(),
              emphasis: true,
              value: MoneyText(
                variance,
                colorNegative: true,
                style: variance == 0
                    ? null
                    : AppType.ledger(variance < 0 ? t.dangerText : t.textPrimary),
              ),
            ),
          if (trip.varianceReason.isNotEmpty)
            DetailRow(label: 'van.variance_reason'.tr(), value: Text(trip.varianceReason)),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final VanSale sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final url = sale.invoice?.shareUrl ?? '';
    return AppCard.item(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sale.buyerName.isEmpty ? 'van.walk_in_buyer'.tr() : sale.buyerName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              MoneyText(sale.grandTotal, style: AppType.ledger(t.textPrimary)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (sale.buyerPhone.isNotEmpty) ...[
                Text(
                  sale.buyerPhone,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: AppTokens.space2),
              ],
              Expanded(
                child: DateText(sale.createdAt, withTime: true, style: theme.textTheme.bodySmall),
              ),
              if (sale.paymentMethod.isNotEmpty)
                AppBadge(_paymentLabel(sale.paymentMethod), tone: AppTone.neutral),
            ],
          ),
          if (sale.invoice != null) ...[
            const SizedBox(height: AppTokens.space2),
            Row(
              children: [
                Icon(Icons.receipt_outlined, size: 16, color: t.iconMuted),
                const SizedBox(width: AppTokens.space1),
                Expanded(
                  child: Text(
                    sale.invoice!.invoiceNo,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: AppType.code(t.textSecondary, size: 13),
                  ),
                ),
                if (url.isNotEmpty)
                  AppButton.text(
                    label: 'van.open_invoice'.tr(),
                    icon: Icons.open_in_new_rounded,
                    onPressed: () =>
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _paymentLabel(String method) {
    final key = 'van.payment_$method';
    final translated = key.tr();
    return translated == key ? method : translated;
  }
}

/// «تسوية الرحلة»: the warehouse keeper enters the driver's return code,
/// counts what came back (returned / damaged per item) and the cash.
class _ReconcileForm extends StatefulWidget {
  final VanTrip trip;

  const _ReconcileForm({required this.trip});

  @override
  State<_ReconcileForm> createState() => _ReconcileFormState();
}

class _ReconcileFormState extends State<_ReconcileForm> {
  final _code = TextEditingController();
  final _cash = TextEditingController();
  final _reason = TextEditingController();
  final Map<int, TextEditingController> _returned = {};
  final Map<int, TextEditingController> _damaged = {};

  @override
  void initState() {
    super.initState();
    for (final line in widget.trip.lines) {
      // The driver's own declaration is the starting point of the count.
      _returned[line.skuId] = TextEditingController(
        text: fmtQty(line.driverReturned ?? line.inVan),
      );
      _damaged[line.skuId] = TextEditingController(text: '0');
    }
    _cash.text = fmtQty(widget.trip.cashSalesTotal);
  }

  @override
  void dispose() {
    _code.dispose();
    _cash.dispose();
    _reason.dispose();
    for (final c in [..._returned.values, ..._damaged.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<int, ({double returned, double damaged})> get _counted => {
    for (final line in widget.trip.lines)
      line.skuId: (
        returned: parseFleetNumber(_returned[line.skuId]!.text) ?? 0,
        damaged: parseFleetNumber(_damaged[line.skuId]!.text) ?? 0,
      ),
  };

  bool get _variance => vanReconcileHasVariance(
    lines: widget.trip.lines,
    counted: _counted,
    expectedCash: widget.trip.cashSalesTotal,
    cash: parseFleetNumber(_cash.text),
  );

  bool get _ready {
    final cash = parseFleetNumber(_cash.text);
    if (_code.text.trim().length != 6 || cash == null || cash < 0) return false;
    return !_variance || _reason.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    final counted = _counted;
    final ok = await context.read<VanTripCubit>().reconcile(
      returnCode: _code.text.trim(),
      cashHandedOver: parseFleetNumber(_cash.text) ?? 0,
      varianceReason: _reason.text,
      lines: [
        for (final line in widget.trip.lines)
          VanReturnLineInput(
            skuId: line.skuId,
            returnedQty: counted[line.skuId]!.returned,
            damagedQty: counted[line.skuId]!.damaged,
          ),
      ],
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('van.reconciled'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final submit = context.watch<VanTripCubit>().state.action;
    final variance = _variance;

    void changed(String _) => setState(() {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(tone: AppTone.info, message: 'van.reconcile_hint'.tr()),
        AppCard(
          child: AppField(
            controller: _code,
            label: 'van.return_code'.tr(),
            hint: '000000',
            required: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              _AsciiDigits(),
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            serverError: submit.fieldError('return_code'),
            onChanged: changed,
          ),
        ),
        AppSectionLabel('van.count_lines'.tr()),
        for (final line in widget.trip.lines)
          AppCard.item(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(line.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'van.count_line_hint'.tr(
                    namedArgs: {
                      'in_van': fmtQty(line.inVan),
                      'declared': line.driverReturned == null ? '—' : fmtQty(line.driverReturned!),
                    },
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppQtyField(
                        controller: _returned[line.skuId]!,
                        label: 'van.returned'.tr(),
                        onChanged: changed,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppQtyField(
                        controller: _damaged[line.skuId]!,
                        label: 'van.damaged'.tr(),
                        onChanged: changed,
                      ),
                    ),
                  ],
                ),
                if (_mismatch(line))
                  Text(
                    'van.count_mismatch'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.warningText),
                  ),
              ],
            ),
          ),
        AppSectionLabel('van.cash_section'.tr()),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailRow(
                label: 'van.cash_expected'.tr(),
                value: MoneyText(widget.trip.cashSalesTotal),
              ),
              const SizedBox(height: AppTokens.space3),
              AppField(
                controller: _cash,
                label: 'van.cash_handed_over'.tr(),
                required: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                suffixText: AppMoney.defaultCurrency,
                serverError: submit.fieldError('cash_handed_over'),
                onChanged: changed,
              ),
              AppField(
                controller: _reason,
                label: 'van.variance_reason'.tr(),
                required: variance,
                hint: variance ? 'van.variance_reason_hint'.tr() : 'common.optional'.tr(),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                serverError: submit.fieldError('variance_reason'),
                onChanged: changed,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        FormMessage(message: submit.message),
        SubmitButton(
          busy: submit.isSubmitting,
          label: 'van.reconcile'.tr(),
          icon: Icons.fact_check_outlined,
          onPressed: _ready ? _submit : null,
        ),
      ],
    );
  }

  bool _mismatch(VanTripLine line) {
    final c = _counted[line.skuId]!;
    return ((c.returned + c.damaged) - line.inVan).abs() > 0.0005;
  }
}

/// ٠-٩ and ۰-۹ become 0-9 in the code field.
class _AsciiDigits extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = String.fromCharCodes(
      newValue.text.runes.map((r) {
        if (r >= 0x0660 && r <= 0x0669) return 0x30 + r - 0x0660;
        if (r >= 0x06F0 && r <= 0x06F9) return 0x30 + r - 0x06F0;
        return r;
      }),
    );
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }
}

/// «ورقة تحميل جديدة»: driver, vehicle, warehouse, then items from that
/// warehouse's stock.
class VanLoadSheetView extends StatelessWidget {
  const VanLoadSheetView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => VanLoadSheetCubit(getIt<FleetRepository>())..load(),
    child: const _LoadSheetBody(),
  );
}

class _LoadSheetBody extends StatefulWidget {
  const _LoadSheetBody();

  @override
  State<_LoadSheetBody> createState() => _LoadSheetBodyState();
}

class _LoadSheetBodyState extends State<_LoadSheetBody> {
  final _discount = TextEditingController();
  final _notes = TextEditingController();
  final Map<int, TextEditingController> _qty = {};
  final Map<int, TextEditingController> _price = {};

  @override
  void dispose() {
    _discount.dispose();
    _notes.dispose();
    for (final c in [..._qty.values, ..._price.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<VanLoadSheetCubit>();
    final trip = await cubit.submit(
      maxDiscountPercent: parseFleetNumber(_discount.text),
      notes: _notes.text,
    );
    if (trip == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('van.created'.tr())));
    // Replace: Back must not offer to load the same van twice. The detail
    // shows the load code big.
    context.pushReplacement(AppRoutes.vanTripFor(trip.id));
  }

  Future<void> _addItem(VanLoadSheetCubit cubit) async {
    final item = await showAppSheet<VanStockItem>(
      context: context,
      title: 'van.add_item'.tr(),
      builder: (_) => _StockPicker(items: cubit.state.pickable),
    );
    if (item == null) return;
    cubit.addItem(item);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<VanLoadSheetCubit>();
    final state = cubit.state;
    final options = state.options;
    final theme = Theme.of(context);
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('van.new'.tr())),
      bottomNavigationBar: options == null
          ? null
          : AppBottomBar(
              leading: (state.submit.message ?? '').isEmpty
                  ? null
                  : FormMessage(message: state.submit.message),
              child: SubmitButton(
                busy: state.submit.isSubmitting,
                label: 'van.create'.tr(),
                onPressed: state.canSubmit ? _submit : null,
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading) return const FormSkeleton(fields: 4);
          if (options == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(
              message: (state.errorMessage ?? '').isEmpty
                  ? 'errors.generic'.tr()
                  : state.errorMessage!,
              onRetry: cubit.load,
            );
          }
          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              if (options.drivers.isEmpty)
                AppBanner(tone: AppTone.warning, message: 'van.no_free_drivers'.tr()),
              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: Column(
                  children: [
                    IdPicker<VanDriverOption>(
                      label: 'van.driver'.tr(),
                      value: state.driverId,
                      items: options.drivers,
                      idOf: (d) => d.id,
                      labelOf: (d) => d.phone.isEmpty ? d.name : '${d.name} · ${d.phone}',
                      error: state.submit.fieldError('driver_id'),
                      onChanged: cubit.chooseDriver,
                    ),
                    IdPicker<VanVehicleOption>(
                      label: 'van.vehicle'.tr(),
                      value: state.vehicleId,
                      items: options.vehicles,
                      required: false,
                      idOf: (v) => v.id,
                      labelOf: (v) => v.vehicleType.isEmpty
                          ? v.plateNumber
                          : '${v.plateNumber} · ${v.vehicleType}',
                      error: state.submit.fieldError('vehicle_id'),
                      onChanged: cubit.chooseVehicle,
                    ),
                    IdPicker<VanWarehouse>(
                      label: 'van.warehouse'.tr(),
                      value: state.warehouseId,
                      items: options.warehouses,
                      idOf: (w) => w.id,
                      labelOf: (w) => w.place.name(locale),
                      error: state.submit.fieldError('warehouse_branch_id'),
                      onChanged: cubit.chooseWarehouse,
                    ),
                  ],
                ),
              ),
              AppSectionLabel(
                'van.load_lines'.tr(),
                trailing: state.warehouse == null || state.pickable.isEmpty
                    ? null
                    : AppButton.text(
                        label: 'van.add_item'.tr(),
                        icon: Icons.add_rounded,
                        onPressed: () => _addItem(cubit),
                      ),
              ),
              if (state.warehouse == null)
                _Quiet('van.pick_warehouse_first'.tr())
              else if (state.lines.isEmpty)
                _Quiet(
                  state.warehouse!.stock.isEmpty
                      ? 'van.warehouse_empty'.tr()
                      : 'van.no_items_yet'.tr(),
                ),
              if (state.submit.fieldError('lines') != null)
                FormMessage(message: state.submit.fieldError('lines')),
              for (final line in state.lines)
                AppCard.item(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(line.item.name, style: theme.textTheme.titleSmall)),
                          IconButton(
                            tooltip: 'common.delete'.tr(),
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () {
                              _qty.remove(line.item.skuId)?.dispose();
                              _price.remove(line.item.skuId)?.dispose();
                              cubit.removeItem(line.item.skuId);
                            },
                          ),
                        ],
                      ),
                      Text(
                        'van.available'.tr(namedArgs: {'qty': fmtQty(line.item.availableQty)}),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppQtyField(
                              controller: _qty.putIfAbsent(
                                line.item.skuId,
                                TextEditingController.new,
                              ),
                              label: 'van.qty'.tr(),
                              onChanged: (value) {
                                final typed = parseFleetNumber(value) ?? 0;
                                final kept = cubit.setQty(line.item.skuId, typed);
                                // Above the warehouse stock: show what was kept.
                                if (kept != typed) _qty[line.item.skuId]!.text = fmtQty(kept);
                              },
                            ),
                          ),
                          const SizedBox(width: AppTokens.space3),
                          Expanded(
                            child: AppQtyField(
                              controller: _price.putIfAbsent(
                                line.item.skuId,
                                TextEditingController.new,
                              ),
                              label: 'van.unit_price'.tr(),
                              helper: 'van.unit_price_hint'.tr(),
                              onChanged: (value) =>
                                  cubit.setPrice(line.item.skuId, parseFleetNumber(value)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              AppSectionLabel('van.options_section'.tr()),
              AppField(
                controller: _discount,
                label: 'van.max_discount'.tr(),
                hint: 'common.optional'.tr(),
                helper: 'van.max_discount_hint'.tr(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                suffixText: '%',
                serverError: state.submit.fieldError('max_discount_percent'),
              ),
              AppField(
                controller: _notes,
                label: 'van.notes'.tr(),
                hint: 'common.optional'.tr(),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                serverError: state.submit.fieldError('notes'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The selected warehouse's stock, searchable by name, code or barcode.
class _StockPicker extends StatefulWidget {
  final List<VanStockItem> items;

  const _StockPicker({required this.items});

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items
              .where(
                (i) =>
                    i.name.toLowerCase().contains(q) ||
                    i.code.toLowerCase().contains(q) ||
                    i.barcode.contains(q),
              )
              .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _search,
          hint: 'common.search'.tr(),
          padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (shown.isEmpty)
          _Quiet('van.no_matching_items'.tr())
        else
          AppMenuGroup(
            children: [
              for (final item in shown)
                AppMenuRow(
                  icon: Icons.inventory_2_outlined,
                  title: item.name,
                  subtitle: [
                    if (item.code.isNotEmpty) item.code,
                    if (item.barcode.isNotEmpty) item.barcode,
                  ].join(' · '),
                  value: fmtQty(item.availableQty),
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
      ],
    );
  }
}
