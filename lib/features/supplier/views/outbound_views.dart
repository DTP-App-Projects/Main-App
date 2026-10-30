import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/trade/delivery_note.dart';
import '../../../data/repositories/shipments_repository.dart';
import '../view_models/supplier_cubits.dart';

const _outboundStatuses = [
  'created',
  'dispatched',
  'en_route',
  'arrived',
  'delivered',
  'canceled',
];

/// Outbound shipments — what this supplier is sending out.
class OutboundShipmentsView extends StatelessWidget {
  const OutboundShipmentsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OutboundShipmentsCubit(getIt<ShipmentsRepository>())..load(),
        child: const _OutboundBody(),
      );
}

class _OutboundBody extends StatelessWidget {
  const _OutboundBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OutboundShipmentsCubit>();
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('outbound.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.statuses.isEmpty,
                onTap: cubit.clearStatuses,
              ),
              for (final status in _outboundStatuses)
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
              emptyTitle: 'outbound.empty'.tr(),
              emptyBody: 'outbound.empty_hint'.tr(),
              itemBuilder: (note) {
                final branch = note.traderBranch?.name ?? '';
                return DocumentTile(
                  code: note.code,
                  title: note.purchaseOrderCode.isEmpty
                      ? ''
                      : '${'order.title'.tr()} ${note.purchaseOrderCode}',
                  status: note.status,
                  amount: note.grandTotal == 0 ? null : note.grandTotal,
                  currency: note.currency,
                  icon: Icons.local_shipping_outlined,
                  // The trader's branch as a meta line, marked with a store.
                  badge: branch.isEmpty
                      ? null
                      : Row(
                          children: [
                            Icon(Icons.storefront_outlined, size: 16, color: t.iconMuted),
                            const SizedBox(width: AppTokens.space1),
                            Expanded(
                              child: Text(
                                branch,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                  onTap: () => context.push(AppRoutes.outboundDetailFor(note.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One outbound shipment: seals on, then dispatch.
///
/// The server enforces the order — seals cannot be applied once it has left
/// (`409`), and dispatch is refused without them (`422`) — so the screen puts
/// them in that order and says why.
class OutboundDetailView extends StatelessWidget {
  final int deliveryNoteId;

  const OutboundDetailView({super.key, required this.deliveryNoteId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            DeliveryEditorCubit(getIt<ShipmentsRepository>(), deliveryNoteId)..load(),
        child: const _OutboundDetailBody(),
      );
}

class _OutboundDetailBody extends StatelessWidget {
  const _OutboundDetailBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DeliveryEditorCubit>();
    final state = cubit.state;
    final note = state.note;
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      // The code is the header card's anchor; the bar names the document type.
      appBar: AppBar(title: Text('outbound.detail_title'.tr())),
      bottomNavigationBar:
          (note == null || note.isCanceled) ? null : _OutboundActionBar(note: note),
      body: Builder(
        builder: (context) {
          if (state.loading && note == null) return const DetailSkeleton();
          if (note == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }

          final beforeDispatch = note.dispatchedAt == null && !note.isCanceled;

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
                // With the action bar up, the message sits above its buttons
                // instead; a cancelled note has no bar and keeps it here.
                if (note.isCanceled) FormMessage(message: state.action.message),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.code,
                              style: AppType.code(t.textPrimary, size: 18),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: note.status),
                        ],
                      ),
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
                    ],
                  ),
                ),

                if (_ProgressStepper.stepFor(note.status) >= 0) ...[
                  const SizedBox(height: AppTokens.space3),
                  AppCard(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppTokens.space3,
                      vertical: AppTokens.space4,
                    ),
                    child: _ProgressStepper(current: _ProgressStepper.stepFor(note.status)),
                  ),
                ],

                AppSectionLabel('shipment.seals'.tr()),
                _SealsCard(note: note, editable: beforeDispatch),

                if (note.lines.isNotEmpty) ...[
                  AppSectionLabel('order.lines'.tr()),
                  AppCard.section(
                    child: Column(
                      children: [
                        for (var i = 0; i < note.lines.length; i++) ...[
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.lines[i].skuName.isEmpty
                                            ? note.lines[i].productName
                                            : note.lines[i].skuName,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'shipment.shipped_qty'.tr(
                                          namedArgs: {'qty': _fmt(note.lines[i].shippedQty)},
                                        ),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppTokens.space3),
                                MoneyText(
                                  note.lines[i].lineTotal,
                                  currency: note.currency,
                                  style: AppType.ledger(t.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

/// Created → dispatched → en route → delivered, read off the status alone.
class _ProgressStepper extends StatelessWidget {
  final int current;

  const _ProgressStepper({required this.current});

  static const _steps = ['created', 'dispatched', 'en_route', 'delivered'];

  /// The last step reached, or -1 when the status is not on this path
  /// (cancelled, or a value the app does not know) and no stepper is drawn.
  static int stepFor(String status) => switch (status) {
        'created' => 0,
        'dispatched' => 1,
        // Arrived is the end of the road, not yet handed over.
        'en_route' || 'arrived' => 2,
        'delivered' => 3,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);

    Widget rail(bool on) => Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: on ? t.primary : t.divider,
              borderRadius: AppTokens.fullRadius,
            ),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    i == 0 ? const Spacer() : rail(i <= current),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? t.primary : t.surface,
                        border: Border.all(color: i <= current ? t.primary : t.inputBorder, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: i < current
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : (i == current
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                )
                              : null),
                    ),
                    i == _steps.length - 1 ? const Spacer() : rail(i < current),
                  ],
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  StatusChip.localize(_steps[i]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: i <= current ? t.textPrimary : t.textTertiary,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SealsCard extends StatefulWidget {
  final DeliveryNote note;
  final bool editable;

  const _SealsCard({required this.note, required this.editable});

  @override
  State<_SealsCard> createState() => _SealsCardState();
}

class _SealsCardState extends State<_SealsCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _controller.text.trim();
    if (value.isEmpty || value.length > 64) return;

    final seals = [...widget.note.pickupSealNumbers, value];
    if (seals.length > 50) return;

    final ok = await context.read<DeliveryEditorCubit>().setSeals(seals);
    if (ok && mounted) _controller.clear();
  }

  /// `POST /seals` replaces the whole list (the add above relies on the same
  /// semantics), so removing one posts the rest. The server requires at
  /// least one seal, so the last one cannot be removed — only replaced.
  Future<void> _remove(String seal) async {
    final seals = [...widget.note.pickupSealNumbers]..remove(seal);
    if (seals.isEmpty) return;
    await context.read<DeliveryEditorCubit>().setSeals(seals);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final busy = context.watch<DeliveryEditorCubit>().state.action.isSubmitting;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBanner(
            message: widget.editable ? 'outbound.seals_hint'.tr() : 'outbound.seals_locked'.tr(),
            tone: widget.editable ? AppTone.info : AppTone.neutral,
            icon: widget.editable ? null : Icons.lock_outline_rounded,
            margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
          ),
          if (widget.note.pickupSealNumbers.isEmpty)
            Text(
              'outbound.no_seals'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
            )
          else
            // Removable while seals can still be set (before dispatch) and
            // more than one remains — the server needs at least one.
            Wrap(
              spacing: AppTokens.space2,
              runSpacing: AppTokens.space2,
              children: [
                for (final seal in widget.note.pickupSealNumbers)
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppTokens.space3,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: t.neutralTint,
                      borderRadius: AppTokens.fullRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 14, color: t.primary),
                        const SizedBox(width: AppTokens.space1),
                        Text(
                          seal,
                          textDirection: TextDirection.ltr,
                          style: AppType.code(t.textPrimary, size: 13),
                        ),
                        if (widget.editable && widget.note.pickupSealNumbers.length > 1) ...[
                          const SizedBox(width: AppTokens.space1),
                          InkResponse(
                            onTap: busy ? null : () => _remove(seal),
                            radius: 18,
                            child: Semantics(
                              button: true,
                              label: 'common.clear'.tr(),
                              child: Icon(Icons.close_rounded, size: 16, color: t.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          if (widget.editable) ...[
            const SizedBox(height: AppTokens.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 64,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'outbound.seal_number'.tr(),
                      counterText: '',
                      // The server's limits, said up front instead of a
                      // silently ignored tap.
                      helperText: 'outbound.seals_limit'.tr(),
                      helperMaxLines: 2,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: AppTokens.space3),
                AppCircleButton(
                  icon: Icons.add_rounded,
                  tooltip: 'outbound.seal_number'.tr(),
                  onPressed: busy ? null : _add,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The sticky footer: the next step as the one primary action, the rest in
/// a "More actions" sheet.
class _OutboundActionBar extends StatelessWidget {
  final DeliveryNote note;

  const _OutboundActionBar({required this.note});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryEditorCubit>();
    final action = context.watch<DeliveryEditorCubit>().state.action;
    final busy = action.isSubmitting;
    final beforeDispatch = note.dispatchedAt == null;
    final canMarkDelivered = !beforeDispatch && !note.isDelivered;

    final more = AppButton.outline(
      label: 'common.more_actions'.tr(),
      icon: Icons.more_horiz_rounded,
      height: 48,
      onPressed: busy ? null : () => _openMore(context, cubit),
    );

    final Widget? primary = beforeDispatch
        ? SubmitButton(
            busy: busy,
            label: 'outbound.dispatch'.tr(),
            icon: Icons.send_rounded,
            onPressed: () => cubit.dispatch(),
          )
        : canMarkDelivered
            ? SubmitButton(
                busy: busy,
                label: 'outbound.mark_delivered'.tr(),
                icon: Icons.check_rounded,
                onPressed: () => _markDelivered(context, cubit),
              )
            : null;

    return AppBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The last action's error, right above the buttons.
          FormMessage(message: action.message),
          primary == null
              ? more
              : Row(
                  children: [
                    Expanded(flex: 2, child: primary),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(child: more),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _openMore(BuildContext context, DeliveryEditorCubit cubit) async {
    final action = await showAppSheet<String>(
      context: context,
      title: 'common.more_actions'.tr(),
      builder: (sheetContext) => AppMenuGroup(
        children: [
          AppMenuRow(
            icon: Icons.event_repeat_rounded,
            title: 'outbound.reschedule'.tr(),
            onTap: () => Navigator.of(sheetContext).pop('reschedule'),
          ),
          AppMenuRow(
            icon: Icons.cancel_outlined,
            title: 'outbound.cancel'.tr(),
            tone: AppTone.danger,
            onTap: () => Navigator.of(sheetContext).pop('cancel'),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'reschedule':
        await _reschedule(context, cubit);
      case 'cancel':
        await _cancel(context, cubit);
    }
  }

  Future<void> _markDelivered(BuildContext context, DeliveryEditorCubit cubit) async {
    String? proof;
    // Only Continue resolves to true; dismissing or cancelling the sheet
    // leaves the shipment as it is.
    final confirmed = await showAppSheet<bool>(
      context: context,
      title: 'outbound.mark_delivered'.tr(),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProofFileField(
            label: 'outbound.delivery_proof'.tr(),
            module: 'delivery_notes',
            fieldKey: 'proof_file',
            onUploaded: (path) => proof = path,
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  label: 'common.cancel'.tr(),
                  height: 48,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: AppButton.solid(
                  label: 'common.continue'.tr(),
                  height: 48,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await cubit.markDelivered(proofFile: proof);
  }

  Future<void> _reschedule(BuildContext context, DeliveryEditorCubit cubit) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    await cubit.reschedule(picked);
  }

  /// The reason is a fixed code, not free text — the server rejects anything
  /// outside its list.
  Future<void> _cancel(BuildContext context, DeliveryEditorCubit cubit) async {
    final reason = await showAppSheet<String>(
      context: context,
      title: 'outbound.cancel_reason'.tr(),
      destructive: true,
      builder: (sheetContext) => AppMenuGroup(
        children: [
          for (final code in ShipmentsRepository.cancelReasons)
            AppMenuRow(
              icon: Icons.label_outline_rounded,
              tone: AppTone.neutral,
              title: 'outbound.reason_$code'.tr(),
              onTap: () => Navigator.of(sheetContext).pop(code),
            ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    final ok = await showAppConfirm(
      context,
      title: 'outbound.cancel'.tr(),
      body: 'outbound.reason_$reason'.tr(),
      confirmLabel: 'outbound.cancel'.tr(),
      destructive: true,
    );
    if (!ok) return;
    await cubit.cancel(reason: reason);
  }
}
