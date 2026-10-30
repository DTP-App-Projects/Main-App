import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../compliance/otp_acceptance_sheet.dart';
import '../../compliance/views/document_flow_strip.dart';
import '../../compliance/views/order_compliance_section.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/compliance/trade_compliance.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../trader/orders/view_models/orders_cubits.dart';

/// One order. **Every button here comes from the server's own transition
/// map** — `allowed_transitions`, `reason_required_for` and
/// `can_request_cancel`. Nothing about the state machine is assumed.
class OrderDetailView extends StatelessWidget {
  final int orderId;

  const OrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => OrderDetailCubit(getIt<OrdersRepository>(), orderId)..load(),
    child: const _OrderDetailBody(),
  );
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OrderDetailCubit>();
    final state = cubit.state;
    final order = state.order;
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      // The code leads the header card; the bar names the document type.
      appBar: AppBar(title: Text('order.detail_title'.tr())),
      bottomNavigationBar: order == null ? null : _OrderActionBar(order: order),
      body: Builder(
        builder: (context) {
          if (state.loading && order == null) return const DetailSkeleton();
          if (order == null) {
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
              padding: AppTokens.pagePadding,
              children: [
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
                              order.code,
                              style: theme.textTheme.titleLarge,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space3),
                      DetailRow(
                        label: 'order.supplier'.tr(),
                        value: Text(order.supplier?.name ?? '—'),
                      ),
                      if (order.paymentTerm != null)
                        DetailRow(
                          label: 'order.payment_term'.tr(),
                          value: Text(order.paymentTerm!.label),
                        ),
                      DetailRow(
                        label: 'order.requested_delivery'.tr(),
                        value: DateText(order.requestedDeliveryDate),
                      ),
                      if (order.creditCheckStatus.isNotEmpty)
                        DetailRow(
                          label: 'order.credit_check'.tr(),
                          value: StatusChip(status: order.creditCheckStatus),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                        child: Divider(height: 1, color: t.divider),
                      ),
                      DetailRow(
                        label: 'order.subtotal'.tr(),
                        value: MoneyText(order.subtotal, currency: order.currency),
                      ),
                      DetailRow(
                        label: 'order.tax_total'.tr(),
                        value: MoneyText(order.taxTotal, currency: order.currency),
                      ),
                      DetailRow(
                        label: 'order.grand_total'.tr(),
                        emphasis: true,
                        value: MoneyText(
                          order.grandTotal,
                          currency: order.currency,
                          style: AppType.ledger(t.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- credit hold: the order exists but waits on credit ------
                if (_creditHold.contains(order.creditCheckStatus)) ...[
                  const SizedBox(height: AppTokens.space3),
                  AppBanner(
                    tone: AppTone.warning,
                    icon: Icons.credit_card_off_outlined,
                    margin: EdgeInsetsDirectional.zero,
                    title: 'order.credit_hold'.tr(),
                    message: 'order.credit_hold_body'.tr(),
                  ),
                ],

                // ---- compliance: supply model, hold, chain, evidence --------
                OrderComplianceSection(
                  order: order,
                  actionCode: state.actionCode,
                  onChanged: cubit.load,
                ),

                // ---- cancellation request -----------------------------------
                if (order.hasOpenCancelRequest) ...[
                  const SizedBox(height: AppTokens.space4),
                  _CancelRequestCard(order: order),
                ],

                // ---- ship: the selling side issues a delivery note -----------
                // `viewer_role`, not the workspace, decides (hybrid orgs).
                if (!order.isTraderView && order.canShip) ...[
                  const SizedBox(height: AppTokens.space4),
                  AppCard(
                    child: Row(
                      children: [
                        const AppIconCircle(Icons.local_shipping_outlined),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(child: Text('dn.ready_hint'.tr(), style: theme.textTheme.bodyMedium)),
                        const SizedBox(width: AppTokens.space2),
                        AppButton.primary(
                          label: 'dn.create'.tr(),
                          height: 40,
                          onPressed: () async {
                            await context.push(AppRoutes.deliveryNoteNewFor(order.id));
                            await cubit.load();
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // ---- lines --------------------------------------------------
                AppSectionLabel(
                  'order.lines'.tr(),
                  trailing: order.lines.isEmpty ? null : AppCountBadge(order.lines.length),
                ),
                AppCard.section(
                  child: Column(
                    children: [
                      for (var i = 0; i < order.lines.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTokens.space4,
                            ),
                            child: Divider(height: 1, color: t.divider),
                          ),
                        _LineRow(line: order.lines[i], currency: order.currency),
                      ],
                      if (order.lines.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppTokens.space5),
                          child: Text('order.no_lines'.tr(), style: theme.textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),

                // ---- shipments, receipts, invoices, payments ---------------
                DocumentFlowStrip(flow: state.flow, side: order.viewerWorkspace),

                // ---- timeline -----------------------------------------------
                if (cubit.timeline.isNotEmpty) ...[
                  AppSectionLabel('onboarding.timeline'.tr()),
                  AppCard(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppTokens.space5,
                      AppTokens.space5,
                      AppTokens.space5,
                      AppTokens.space1,
                    ),
                    child: DocumentTimeline(events: cubit.timeline),
                  ),
                ],

                const SizedBox(height: AppTokens.space5),
                _OrderFooter(order: order, timeline: cubit.timeline),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// `credit_check_status` values that leave a created order on credit hold.
const _creditHold = {'failed', 'manual_review'};

class _LineRow extends StatelessWidget {
  final PurchaseOrderLine line;
  final String currency;

  const _LineRow({required this.line, required this.currency});

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
                  'order.line_qty'.tr(namedArgs: {'qty': _qty(line.qty)}),
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

/// B4: the quiet footer. The role is localized (the raw `viewer_role` only
/// shows when the app has no word for it) and the time is the **most recent**
/// event — the latest `at`, not `timeline.last`, which is the oldest.
class _OrderFooter extends StatelessWidget {
  final PurchaseOrder order;
  final List<TimelineEvent> timeline;

  const _OrderFooter({required this.order, required this.timeline});

  static String roleLabel(String role) {
    final key = switch (role) {
      'trader' || 'buyer' => 'workspace.trader',
      'supplier' || 'seller' => 'workspace.supplier',
      _ => null,
    };
    if (key == null) return role.isEmpty ? '—' : role;
    final translated = key.tr();
    return translated == key ? role : translated;
  }

  static DateTime? latestEvent(List<TimelineEvent> timeline) {
    DateTime? latest;
    for (final event in timeline) {
      final at = event.at;
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final latest = latestEvent(timeline);
    final style = theme.textTheme.labelSmall?.copyWith(color: t.textTertiary);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppTokens.space1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${'order.viewing_as'.tr()}: ${roleLabel(order.viewerRole)}', style: style),
          if (latest != null) ...[
            const SizedBox(height: AppTokens.space1),
            Text(
              '${'order.last_update'.tr()}: '
              '${AppDates.dateTime(latest, context.locale.toString())}',
              style: style,
            ),
          ],
        ],
      ),
    );
  }
}

/// One thing the user can do to the order, from the server's transition map.
class _OrderAction {
  final String label;
  final IconData icon;
  final bool destructive;
  final Future<void> Function() run;

  const _OrderAction({
    required this.label,
    required this.icon,
    required this.destructive,
    required this.run,
  });
}

/// Transitions that end or refuse the order. Styled red and confirmed.
bool _isDestructive(String transition) =>
    transition == 'rejected' || transition == 'canceled' || transition == 'cancelled';

/// The sticky action bar, built entirely from the server's transition map:
/// the first allowed forward transition is the primary CTA, everything else
/// sits behind "More actions".
class _OrderActionBar extends StatelessWidget {
  final PurchaseOrder order;

  const _OrderActionBar({required this.order});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrderDetailCubit>();
    final busy = context.watch<OrderDetailCubit>().state.action.isSubmitting;
    // The last action's error sits right above the buttons that caused it —
    // unless the cancellation card is showing its own decision buttons, which
    // then carry it.
    final message = order.hasOpenCancelRequest && !order.isTraderView
        ? null
        : context.watch<OrderDetailCubit>().state.action.message;

    final actions = <_OrderAction>[
      for (final transition in order.allowedTransitions)
        _OrderAction(
          label: 'status.$transition'.tr(),
          icon: _isDestructive(transition)
              ? Icons.block_rounded
              : Icons.check_circle_outline_rounded,
          destructive: _isDestructive(transition),
          run: () => _run(context, cubit, transition, order.requiresNote(transition)),
        ),
      // Once approved, cancelling is a request the supplier decides — not a
      // transition the trader can make.
      if (order.canRequestCancel && !order.hasOpenCancelRequest)
        _OrderAction(
          label: 'order.request_cancel'.tr(),
          icon: Icons.undo_rounded,
          destructive: true,
          run: () => _requestCancel(context, cubit),
        ),
    ];

    if (actions.isEmpty) {
      return (message == null || message.isEmpty)
          ? const SizedBox.shrink()
          : AppBottomBar(child: FormMessage(message: message));
    }

    final primaryIndex = actions.indexWhere((a) => !a.destructive);
    final primary = primaryIndex == -1 ? null : actions[primaryIndex];
    final rest = [
      for (var i = 0; i < actions.length; i++)
        if (i != primaryIndex) actions[i],
    ];

    Widget child;
    if (primary != null) {
      final cta = SubmitButton(
        busy: busy,
        label: primary.label,
        onPressed: busy ? null : primary.run,
      );
      child = rest.isEmpty
          ? cta
          : Row(
              children: [
                Expanded(child: cta),
                const SizedBox(width: AppTokens.space3),
                AppButton.outline(
                  label: 'common.more_actions'.tr(),
                  icon: Icons.more_horiz_rounded,
                  expand: false,
                  onPressed: busy ? null : () => _showMore(context, rest),
                ),
              ],
            );
    } else if (rest.length == 1) {
      final only = rest.single;
      child = AppButton.outlineDanger(
        label: only.label,
        icon: only.icon,
        busy: busy,
        onPressed: busy ? null : only.run,
      );
    } else {
      child = AppButton.outline(
        label: 'common.more_actions'.tr(),
        icon: Icons.more_horiz_rounded,
        busy: busy,
        onPressed: busy ? null : () => _showMore(context, rest),
      );
    }

    return AppBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormMessage(message: message),
          child,
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<_OrderAction> actions) {
    showAppSheet<void>(
      context: context,
      title: 'common.more_actions'.tr(),
      builder: (sheetContext) => AppMenuGroup(
        children: [
          for (final action in actions)
            AppMenuRow(
              icon: action.icon,
              title: action.label,
              tone: action.destructive ? AppTone.danger : AppTone.brand,
              onTap: () {
                Navigator.of(sheetContext).pop();
                action.run();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    OrderDetailCubit cubit,
    String transition,
    bool needsNote,
  ) async {
    final destructive = _isDestructive(transition);
    String? note;
    if (needsNote) {
      note = await askForReason(
        context,
        title: 'status.$transition'.tr(),
        hint: 'order.note_required'.tr(),
        minLength: 3,
        maxLength: 500,
        destructive: destructive,
      );
      if (note == null) return;
    } else if (destructive) {
      if (!context.mounted) return;
      final label = 'status.$transition'.tr();
      final ok = await showAppConfirm(
        context,
        title: 'order.transition_confirm'.tr(namedArgs: {'status': label}),
        confirmLabel: label,
        destructive: true,
      );
      if (!ok) return;
    }
    // Transitions the server lists in `otp_required_for` (the supplier's
    // acceptance) are a level-2 act: the code sheet posts them itself.
    final order = cubit.state.order;
    if (order != null && order.compliance.needsOtp(transition)) {
      if (!context.mounted) return;
      await showOtpAcceptance(
        context,
        documentType: order.compliance.otpDocumentType,
        documentId: order.id,
        title: 'status.$transition'.tr(),
        subtitle: order.code,
        submit: (code) => cubit.changeStatusWithOtp(transition, code, note: note),
      );
      return;
    }
    final ok = await cubit.changeStatus(transition, note: note);
    if (ok || order == null || !context.mounted) return;
    // The server asked for the binding code the payload had not announced:
    // collect it rather than leave the user at an error they cannot act on.
    if (PurchaseOrderCompliance.isCodeRequired(cubit.state.actionCode)) {
      await showOtpAcceptance(
        context,
        documentType: order.compliance.otpDocumentType,
        documentId: order.id,
        title: 'status.$transition'.tr(),
        subtitle: order.code,
        submit: (code) => cubit.changeStatusWithOtp(transition, code, note: note),
      );
    }
  }

  Future<void> _requestCancel(BuildContext context, OrderDetailCubit cubit) async {
    final reason = await askForReason(
      context,
      title: 'order.request_cancel'.tr(),
      hint: 'order.cancel_reason_hint'.tr(),
      minLength: 3,
      maxLength: 500,
      destructive: true,
    );
    if (reason == null) return;
    await cubit.requestCancel(reason);
  }
}

/// The open cancellation request. The buying side sees that it is waiting;
/// the selling side gets the two buttons that settle it.
class _CancelRequestCard extends StatelessWidget {
  final PurchaseOrder order;

  const _CancelRequestCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrderDetailCubit>();
    final action = context.watch<OrderDetailCubit>().state.action;
    final busy = action.isSubmitting;
    // `viewer_role` decides, not the active workspace: a hybrid organization
    // can be the seller on this order and the buyer on the next one.
    final decides = !order.isTraderView;
    final headline = decides
        ? 'order.cancel_requested_supplier'.tr()
        : 'order.cancel_requested'.tr();
    final reason = order.cancelRequest?.reason ?? '';

    return AppBanner(
      tone: AppTone.warning,
      icon: Icons.hourglass_top_rounded,
      margin: EdgeInsetsDirectional.zero,
      title: reason.isNotEmpty ? headline : null,
      message: reason.isNotEmpty ? reason : headline,
      action: !decides
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The decision's error, above the two buttons that settle it.
                  FormMessage(message: action.message),
                  Row(
                    children: [
                      // Refusing keeps the order alive: the safe choice leads.
                      Expanded(
                        child: AppButton.outline(
                          label: 'order.cancel_reject'.tr(),
                          height: 44,
                          onPressed: busy ? null : () => _reject(context, cubit),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        child: AppButton.outlineDanger(
                          label: 'order.cancel_accept'.tr(),
                          height: 44,
                          busy: busy,
                          onPressed: busy ? null : () => _accept(context, cubit),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _accept(BuildContext context, OrderDetailCubit cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'order.cancel_accept_title'.tr(),
      body: 'order.cancel_accept_body'.tr(),
      confirmLabel: 'order.cancel_accept'.tr(),
      destructive: true,
    );
    if (!ok) return;
    await cubit.decideCancelRequest('accepted');
  }

  Future<void> _reject(BuildContext context, OrderDetailCubit cubit) async {
    // The server requires a note when rejecting.
    final note = await askForReason(
      context,
      title: 'order.cancel_reject'.tr(),
      hint: 'order.note_required'.tr(),
      minLength: 3,
      maxLength: 500,
    );
    if (note == null) return;
    await cubit.decideCancelRequest('rejected', note: note);
  }
}

/// A reason prompt with the server's own length rule, so `400 reason_required`
/// never comes back as a surprise.
///
/// Drawn as the Driver reason dialog. A note outside [minLength]..[maxLength]
/// is not returned: the prompt opens again with the length rule as its body.
/// Resolves to the trimmed note, or `null` when cancelled.
Future<String?> askForReason(
  BuildContext context, {
  required String title,
  required String hint,
  required int minLength,
  required int maxLength,
  bool destructive = false,
}) async {
  // The server's bounds are enforced in the dialog itself (confirm stays
  // disabled below the minimum), so nothing the user typed is ever lost.
  final value = await showAppReasonDialog(
    context,
    title: title,
    hint: hint,
    required: true,
    destructive: destructive,
    maxLength: maxLength,
    minLength: minLength,
    lengthRule: 'order.note_length'.tr(namedArgs: {'min': '$minLength', 'max': '$maxLength'}),
  );
  return value?.trim();
}
