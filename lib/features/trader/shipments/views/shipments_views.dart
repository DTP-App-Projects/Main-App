import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/shipments_repository.dart';
import '../view_models/shipments_cubits.dart';

const _shipmentStatuses = [
  'created',
  'dispatched',
  'en_route',
  'arrived',
  'delivered',
  'canceled',
];

/// The forward path a shipment travels, in order. Used only to draw
/// progress; the status itself is always the server's.
const _progressSteps = ['created', 'dispatched', 'en_route', 'arrived', 'delivered'];

class ShipmentsView extends StatelessWidget {
  const ShipmentsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShipmentsCubit(getIt<ShipmentsRepository>())..load(),
        child: const _ShipmentsBody(),
      );
}

class _ShipmentsBody extends StatelessWidget {
  const _ShipmentsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShipmentsCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('shipment.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.statuses.isEmpty,
                onTap: () => cubit.clearStatuses(),
              ),
              for (final status in _shipmentStatuses)
                AppFilterOption(
                  label: 'status.$status'.tr(),
                  selected: cubit.statuses.contains(status),
                  onTap: () => cubit.toggleStatus(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<DeliveryNote>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.local_shipping_outlined,
              emptyTitle: 'shipment.empty'.tr(),
              itemBuilder: (note) => DocumentTile(
                code: note.code,
                title: note.purchaseOrderCode.isEmpty
                    ? ''
                    : '${'order.title'.tr()} ${note.purchaseOrderCode}',
                subtitle: note.supplierBranch?.name ?? '',
                status: note.status,
                amount: note.grandTotal == 0 ? null : note.grandTotal,
                currency: note.currency,
                icon: Icons.local_shipping_outlined,
                badge: note.sealsTampered
                    ? const StatusChip(status: 'disputed')
                    : null,
                onTap: () => context.push(AppRoutes.shipmentDetailFor(note.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Track one shipment: where it is, who is carrying it, whether the seals
/// still match, and the chain-of-custody trail.
class ShipmentTrackingView extends StatefulWidget {
  final int deliveryNoteId;

  const ShipmentTrackingView({super.key, required this.deliveryNoteId});

  @override
  State<ShipmentTrackingView> createState() => _ShipmentTrackingViewState();
}

class _ShipmentTrackingViewState extends State<ShipmentTrackingView>
    with WidgetsBindingObserver {
  late final TrackingCubit _cubit =
      TrackingCubit(getIt<ShipmentsRepository>(), widget.deliveryNoteId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Closing the cubit cancels the poll — a tracking screen left behind must
    // not keep spending the request budget.
    _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _cubit.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: const _TrackingBody(),
      );
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TrackingCubit>();
    final state = cubit.state;
    final note = state.note;
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      // The code leads the header card; the bar names the screen.
      appBar: AppBar(
        title: Text('shipment.tracking_title'.tr()),
        actions: [
          if (state.live)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppTokens.space4),
              child: Center(
                child: AppBadge('shipment.live'.tr(), icon: Icons.circle),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (note != null && note.canReceive)
          ? AppBottomBar(
              child: AppButton.primary(
                label: 'receipt.confirm'.tr(),
                icon: Icons.inventory_2_outlined,
                onPressed: () => context.push(AppRoutes.goodsReceiptFor(note.id)),
              ),
            )
          : null,
      body: Builder(
        builder: (context) {
          if (state.loading && note == null) return const DetailSkeleton();
          if (note == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.refresh);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                // The tamper check earns the top of the screen when it fails.
                if (note.sealsTampered)
                  AppBanner(
                    message: 'shipment.seals_mismatch'.tr(),
                    tone: AppTone.danger,
                    icon: Icons.gpp_bad_outlined,
                  ),

                // ---- header -------------------------------------------------
                AppCard(
                  shadow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              note.code,
                              style: theme.textTheme.titleLarge,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: note.status),
                        ],
                      ),
                      if (!note.isCanceled && _progressSteps.contains(note.status)) ...[
                        const SizedBox(height: AppTokens.space4),
                        _ShipmentProgress(status: note.status),
                      ],
                      const SizedBox(height: AppTokens.space3),
                      DetailRow(
                        label: 'order.title'.tr(),
                        value: Text(note.purchaseOrderCode, textDirection: TextDirection.ltr),
                      ),
                      DetailRow(
                        label: 'shipment.from'.tr(),
                        value: Text(note.supplierBranch?.name ?? '—'),
                      ),
                      DetailRow(
                        label: 'shipment.to'.tr(),
                        value: Text(note.traderBranch?.name ?? '—'),
                      ),
                      DetailRow(
                        label: 'shipment.dispatched_at'.tr(),
                        value: DateText(note.dispatchedAt, withTime: true),
                      ),
                      if (note.routeStop?.plannedArrivalTime != null)
                        DetailRow(
                          label: 'shipment.planned_arrival'.tr(),
                          value: DateText(
                            note.routeStop!.plannedArrivalTime,
                            withTime: true,
                          ),
                        ),
                      if (note.isCanceled && note.cancelReasonLabel.isNotEmpty)
                        DetailRow(
                          label: 'shipment.cancel_reason'.tr(),
                          value: Text(note.cancelReasonLabel),
                        ),
                    ],
                  ),
                ),

                // ---- carrier ------------------------------------------------
                if (note.driver != null || note.vehicle != null) ...[
                  AppSectionLabel('shipment.carrier'.tr()),
                  _CarrierCard(driver: note.driver, vehicle: note.vehicle),
                ],

                // ---- seals --------------------------------------------------
                if (note.pickupSealNumbers.isNotEmpty) ...[
                  AppSectionLabel('shipment.seals'.tr()),
                  AppCard(
                    padding: const EdgeInsetsDirectional.all(AppTokens.space4),
                    child: Wrap(
                      spacing: AppTokens.space2,
                      runSpacing: AppTokens.space2,
                      children: [
                        for (final seal in note.pickupSealNumbers)
                          AppBadge(
                            seal,
                            icon: Icons.verified_outlined,
                            tone: note.sealsTampered ? AppTone.danger : AppTone.neutral,
                          ),
                      ],
                    ),
                  ),
                ],

                // ---- chain of custody --------------------------------------
                if (note.routeStop?.proofs.isNotEmpty ?? false) ...[
                  AppSectionLabel('shipment.handoff'.tr()),
                  AppCard(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppTokens.space5,
                      AppTokens.space5,
                      AppTokens.space5,
                      AppTokens.space1,
                    ),
                    child: _ProofTimeline(proofs: note.routeStop!.proofs),
                  ),
                ],

                // ---- lines --------------------------------------------------
                AppSectionLabel(
                  'order.lines'.tr(),
                  trailing: note.lines.isEmpty ? null : AppCountBadge(note.lines.length),
                ),
                AppCard.section(
                  child: Column(
                    children: [
                      for (var i = 0; i < note.lines.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTokens.space4,
                            ),
                            child: Divider(height: 1, color: t.divider),
                          ),
                        _ShipmentLineRow(line: note.lines[i], currency: note.currency),
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
}

/// A segmented bar over the forward path, filled up to the current status,
/// with that status named underneath.
class _ShipmentProgress extends StatelessWidget {
  final String status;

  const _ShipmentProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final current = _progressSteps.indexOf(status);
    final next = current + 1 < _progressSteps.length ? _progressSteps[current + 1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < _progressSteps.length; i++) ...[
              if (i > 0) const SizedBox(width: AppTokens.space1),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= current ? t.primary : t.primaryTint,
                    borderRadius: AppTokens.fullRadius,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTokens.space2),
        Row(
          children: [
            Expanded(
              child: Text(
                StatusChip.localize(status),
                style: theme.textTheme.labelMedium?.copyWith(color: t.primary),
              ),
            ),
            if (next != null)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        StatusChip.localize(next),
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    DirectionalChevron(size: 16, color: t.iconMuted),
                  ],
                ),
              ),
            const SizedBox(width: AppTokens.space2),
            Text(
              '${current + 1} / ${_progressSteps.length}',
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _ShipmentLineRow extends StatelessWidget {
  final DeliveryLine line;
  final String currency;

  const _ShipmentLineRow({required this.line, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppTokens.space4,
        vertical: AppTokens.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.skuName.isEmpty ? line.productName : line.skuName,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'shipment.shipped_qty'.tr(namedArgs: {'qty': _qty(line.shippedQty)}),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          MoneyText(line.lineTotal, currency: currency, style: AppType.ledger(t.textPrimary)),
        ],
      ),
    );
  }

  static String _qty(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

class _CarrierCard extends StatelessWidget {
  final DriverInfo? driver;
  final VehicleInfo? vehicle;

  const _CarrierCard({required this.driver, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return AppMenuGroup(
      children: [
        if (driver != null)
          _CarrierRow(
            icon: Icons.person_outline_rounded,
            title: driver!.name,
            subtitle: driver!.phone,
            trailing: driver!.phone.isEmpty
                ? null
                : AppCircleButton(
                    icon: Icons.call_outlined,
                    size: 44,
                    onPressed: () => launchUrl(Uri.parse('tel:${driver!.phone}')),
                  ),
          ),
        if (vehicle != null)
          _CarrierRow(
            icon: Icons.local_shipping_outlined,
            title: vehicle!.plateNumber,
            titleStyle: theme.textTheme.titleSmall?.copyWith(color: t.textPrimary),
          ),
      ],
    );
  }
}

/// A menu-shaped row that is not a link: icon disc, title, an LTR detail line
/// (phone, plate) and an optional action at the end.
class _CarrierRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;

  const _CarrierRow({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.trailing,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTokens.rowHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppTokens.space5,
          vertical: AppTokens.space3,
        ),
        child: Row(
          children: [
            AppIconCircle(icon),
            const SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle ?? theme.textTheme.titleSmall),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTokens.space2),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The chain of custody: pickup photo and signature at the supplier, delivery
/// photo and signature at the trader — drawn on the shared timeline rail,
/// newest first like every other timeline in the app.
class _ProofTimeline extends StatelessWidget {
  final List<DeliveryProof> proofs;

  const _ProofTimeline({required this.proofs});

  @override
  Widget build(BuildContext context) {
    final events = [
      for (final proof in proofs.reversed)
        TimelineEvent(
          event: proof.proofType,
          title: proof.proofCategory.isEmpty ? proof.proofType : proof.proofCategory,
          description: proof.signerName.isEmpty
              ? ''
              : '${proof.signerName} · ${proof.signerRole}',
          status: '',
          actorName: proof.signerName,
          at: proof.capturedAt,
        ),
    ];
    return DocumentTimeline(events: events);
  }
}
