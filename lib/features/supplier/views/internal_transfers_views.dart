import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../core/workspace/workspace_cubit.dart';
import '../../../data/models/fleet/internal_transfer.dart';
import '../../../data/repositories/internal_transfers_repository.dart';
import '../view_models/internal_transfers_cubits.dart';
import 'fleet_widgets.dart';

/// `.manage` creates, cancels and edits lines; `.approve` approves — two
/// separate permissions, both passed by the owner.
({bool manage, bool approve}) _perms(BuildContext context) {
  final ws = context.watch<WorkspaceCubit>().state;
  return (
    manage: ws?.can('internal_transfers.manage') ?? false,
    approve: ws?.can('internal_transfers.approve') ?? false,
  );
}

String _priorityLabel(String code) {
  final key = 'transfer.priority_$code';
  final translated = key.tr();
  return translated == key ? code : translated;
}

/// «النقل الداخلي» — the transfers list.
class InternalTransfersView extends StatelessWidget {
  const InternalTransfersView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => InternalTransfersCubit(getIt<InternalTransfersRepository>())..load(),
    child: const _ListBody(),
  );
}

class _ListBody extends StatelessWidget {
  const _ListBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<InternalTransfersCubit>();
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    // From → to, pointing the way the line is read.
    final arrow = Directionality.of(context) == TextDirection.rtl ? '←' : '→';

    return Scaffold(
      appBar: AppBar(title: Text('transfer.title'.tr())),
      floatingActionButton: _perms(context).manage
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.internalTransfersNew);
                if (context.mounted) await cubit.refresh();
              },
              icon: const Icon(Icons.add_rounded),
              label: Text('transfer.new'.tr()),
            )
          : null,
      body: Column(
        children: [
          AppFilterBar(
            options: [
              AppFilterOption(
                label: 'order.filter_all'.tr(),
                selected: cubit.status == null,
                onTap: () => cubit.filter(null),
              ),
              for (final status in InternalTransfer.statuses)
                AppFilterOption(
                  label: StatusChip.localize(status),
                  selected: cubit.status == status,
                  onTap: () => cubit.filter(status),
                ),
            ],
          ),
          Expanded(
            child: PagedListView<InternalTransfer>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.swap_horiz_rounded,
              emptyTitle: 'transfer.empty'.tr(),
              emptyBody: 'transfer.empty_hint'.tr(),
              itemBuilder: (transfer) => DocumentTile(
                code: transfer.code.isEmpty ? '#${transfer.id}' : transfer.code,
                title:
                    '${transfer.sourceBranch?.name(locale) ?? '—'}  $arrow  '
                    '${transfer.destinationBranch?.name(locale) ?? '—'}',
                status: transfer.status,
                icon: Icons.swap_horiz_rounded,
                badge: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: t.iconMuted),
                    const SizedBox(width: AppTokens.space1),
                    Text(
                      'transfer.n_lines'.tr(namedArgs: {'n': '${transfer.lines.length}'}),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (transfer.priority.isNotEmpty && transfer.priority != 'normal') ...[
                      const SizedBox(width: AppTokens.space2),
                      AppBadge(
                        _priorityLabel(transfer.priority),
                        tone: transfer.priority == 'critical' ? AppTone.danger : AppTone.warning,
                      ),
                    ],
                  ],
                ),
                onTap: () async {
                  await context.push(AppRoutes.internalTransferFor(transfer.id));
                  if (context.mounted) await cubit.refresh();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One transfer. While `draft`: approve, cancel (with a reason) and edit its
/// lines; once received: close.
class InternalTransferDetailView extends StatelessWidget {
  final int transferId;

  const InternalTransferDetailView({super.key, required this.transferId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => InternalTransferCubit(getIt<InternalTransfersRepository>(), transferId)..load(),
    child: const _DetailBody(),
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<InternalTransferCubit>();
    final state = cubit.state;
    final transfer = state.transfer;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final perms = _perms(context);

    final editable = transfer != null && transfer.isDraft && perms.manage;
    final showBar =
        transfer != null &&
        ((transfer.isDraft && (perms.manage || perms.approve)) ||
            (transfer.canClose && perms.manage));

    return Scaffold(
      appBar: AppBar(title: Text('transfer.detail_title'.tr())),
      bottomNavigationBar: showBar ? _ActionBar(transfer: transfer, perms: perms) : null,
      body: Builder(
        builder: (context) {
          if (state.loading && transfer == null) return const DetailSkeleton();
          if (transfer == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }
          return RefreshIndicator(
            onRefresh: () => cubit.load(quiet: true),
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.gutter,
                AppTokens.space3,
                AppTokens.gutter,
                AppTokens.space8,
              ),
              children: [
                if (!showBar) FormMessage(message: state.action.message),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transfer.code.isEmpty ? '#${transfer.id}' : transfer.code,
                              style: AppType.code(t.textPrimary, size: 18),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: transfer.status),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space3),
                      DetailRow(
                        label: 'transfer.source'.tr(),
                        value: Text(transfer.sourceBranch?.name(locale) ?? '—'),
                      ),
                      DetailRow(
                        label: 'transfer.destination'.tr(),
                        value: Text(transfer.destinationBranch?.name(locale) ?? '—'),
                      ),
                      if (transfer.priority.isNotEmpty)
                        DetailRow(
                          label: 'transfer.priority'.tr(),
                          value: Text(_priorityLabel(transfer.priority)),
                        ),
                      if (transfer.requiredByDate != null)
                        DetailRow(
                          label: 'transfer.required_by'.tr(),
                          value: DateText(transfer.requiredByDate),
                        ),
                      if (transfer.requestedBy.isNotEmpty)
                        DetailRow(
                          label: 'transfer.requested_by'.tr(),
                          value: Text(transfer.requestedBy),
                        ),
                      if (transfer.approvedBy.isNotEmpty)
                        DetailRow(
                          label: 'transfer.approved_by'.tr(),
                          value: Text(transfer.approvedBy),
                        ),
                      if (transfer.driverName.isNotEmpty)
                        DetailRow(label: 'transfer.driver'.tr(), value: Text(transfer.driverName)),
                      if (transfer.vehiclePlate.isNotEmpty)
                        DetailRow(
                          label: 'transfer.vehicle'.tr(),
                          value: Text(transfer.vehiclePlate, textDirection: TextDirection.ltr),
                        ),
                      DetailRow(
                        label: 'transfer.created_at'.tr(),
                        value: DateText(transfer.createdAt, withTime: true),
                      ),
                      if (transfer.notes.isNotEmpty)
                        DetailRow(label: 'transfer.notes'.tr(), value: Text(transfer.notes)),
                    ],
                  ),
                ),
                if (transfer.status == 'canceled' && transfer.cancellationReason.isNotEmpty)
                  AppBanner(
                    tone: AppTone.danger,
                    title: 'transfer.cancellation_reason'.tr(),
                    message: transfer.cancellationReason,
                    margin: const EdgeInsetsDirectional.only(top: AppTokens.space3),
                  ),
                AppSectionLabel(
                  'transfer.lines'.tr(),
                  trailing: editable
                      ? AppButton.text(
                          label: 'transfer.add_line'.tr(),
                          icon: Icons.add_rounded,
                          onPressed: state.action.isSubmitting
                              ? null
                              : () => _addLine(context, cubit),
                        )
                      : null,
                ),
                if (transfer.lines.isEmpty)
                  Text(
                    'transfer.no_lines'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  )
                else
                  AppCard.section(
                    child: Column(
                      children: [
                        for (var i = 0; i < transfer.lines.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: AppTokens.space5,
                              endIndent: AppTokens.space5,
                              color: t.divider,
                            ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              AppTokens.space5,
                              AppTokens.space3,
                              AppTokens.space2,
                              AppTokens.space3,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transfer.lines[i].label(locale),
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      if (transfer.lines[i].skuCode.isNotEmpty)
                                        Text(
                                          transfer.lines[i].skuCode,
                                          textDirection: TextDirection.ltr,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  fmtQty(transfer.lines[i].requestedQty),
                                  textDirection: TextDirection.ltr,
                                  style: AppType.ledger(t.textPrimary),
                                ),
                                if (editable)
                                  IconButton(
                                    tooltip: 'common.delete'.tr(),
                                    icon: Icon(Icons.delete_outline_rounded, color: t.iconMuted),
                                    onPressed: state.action.isSubmitting
                                        ? null
                                        : () => _deleteLine(context, cubit, transfer.lines[i]),
                                  )
                                else
                                  const SizedBox(width: AppTokens.space3),
                              ],
                            ),
                          ),
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

  Future<void> _addLine(BuildContext context, InternalTransferCubit cubit) async {
    final skus = await cubit.skus();
    if (!context.mounted || skus.isEmpty) return;
    final taken = {for (final l in cubit.state.transfer?.lines ?? const <TransferLine>[]) l.skuId};
    final result = await showAppSheet<(int, double)>(
      context: context,
      title: 'transfer.add_line'.tr(),
      builder: (_) => _AddLineSheet(
        skus: [
          for (final s in skus)
            if (!taken.contains(s.id)) s,
        ],
      ),
    );
    if (result == null) return;
    await cubit.addLine(result.$1, result.$2);
  }

  Future<void> _deleteLine(
    BuildContext context,
    InternalTransferCubit cubit,
    TransferLine line,
  ) async {
    final ok = await showAppConfirm(
      context,
      title: 'transfer.delete_line'.tr(),
      body: line.label(context.locale.toString()),
      confirmLabel: 'common.delete'.tr(),
      destructive: true,
    );
    if (!ok) return;
    await cubit.deleteLine(line.id);
  }
}

class _ActionBar extends StatelessWidget {
  final InternalTransfer transfer;
  final ({bool manage, bool approve}) perms;

  const _ActionBar({required this.transfer, required this.perms});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InternalTransferCubit>();
    final action = context.watch<InternalTransferCubit>().state.action;
    final busy = action.isSubmitting;

    final buttons = <Widget>[
      if (transfer.isDraft && perms.approve)
        SubmitButton(
          busy: busy,
          label: 'transfer.approve'.tr(),
          icon: Icons.check_rounded,
          onPressed: () => _approve(context, cubit),
        ),
      if (transfer.isDraft && perms.manage)
        AppButton.outlineDanger(
          label: 'transfer.cancel'.tr(),
          icon: Icons.cancel_outlined,
          onPressed: busy ? null : () => _cancel(context, cubit),
        ),
      if (transfer.canClose && perms.manage)
        SubmitButton(
          busy: busy,
          label: 'transfer.close'.tr(),
          icon: Icons.lock_outline_rounded,
          onPressed: () => _close(context, cubit),
        ),
    ];

    return AppBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormMessage(message: action.message),
          Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: AppTokens.space3),
                Expanded(child: buttons[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, InternalTransferCubit cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'transfer.approve'.tr(),
      body: 'transfer.approve_confirm'.tr(),
      confirmLabel: 'transfer.approve'.tr(),
    );
    if (!ok) return;
    await cubit.approve();
  }

  Future<void> _cancel(BuildContext context, InternalTransferCubit cubit) async {
    final reason = await showAppReasonDialog(
      context,
      title: 'transfer.cancel'.tr(),
      body: 'transfer.cancel_confirm'.tr(),
      hint: 'transfer.cancel_reason_hint'.tr(),
      confirmLabel: 'transfer.cancel'.tr(),
      required: true,
      destructive: true,
      maxLength: 500,
    );
    if (reason == null || reason.trim().isEmpty) return;
    await cubit.cancel(reason);
  }

  Future<void> _close(BuildContext context, InternalTransferCubit cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'transfer.close'.tr(),
      body: 'transfer.close_confirm'.tr(),
      confirmLabel: 'transfer.close'.tr(),
    );
    if (!ok) return;
    await cubit.closeTransfer();
  }
}

/// Pick a SKU and a quantity; pops `(skuId, qty)`.
class _AddLineSheet extends StatefulWidget {
  final List<TransferSku> skus;

  const _AddLineSheet({required this.skus});

  @override
  State<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends State<_AddLineSheet> {
  int? _skuId;
  final _qty = TextEditingController(text: '1');

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = parseFleetNumber(_qty.text) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IdPicker<TransferSku>(
          label: 'transfer.sku'.tr(),
          value: _skuId,
          items: widget.skus,
          idOf: (s) => s.id,
          labelOf: (s) => s.code.isEmpty ? s.label : '${s.label} · ${s.code}',
          onChanged: (id) => setState(() => _skuId = id),
        ),
        AppQtyField(
          controller: _qty,
          label: 'transfer.qty'.tr(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppTokens.space3),
        AppButton.solid(
          label: 'transfer.add_line'.tr(),
          onPressed: (_skuId == null || qty <= 0)
              ? null
              : () => Navigator.of(context).pop((_skuId!, qty)),
        ),
      ],
    );
  }
}

/// «طلب نقل داخلي».
class InternalTransferFormView extends StatelessWidget {
  const InternalTransferFormView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => InternalTransferFormCubit(getIt<InternalTransfersRepository>())..load(),
    child: const _FormBody(),
  );
}

class _FormBody extends StatefulWidget {
  const _FormBody();

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final _notes = TextEditingController();
  final Map<int, TextEditingController> _qty = {};

  @override
  void dispose() {
    _notes.dispose();
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(bool mayApprove) async {
    final transfer = await context.read<InternalTransferFormCubit>().submit(
      notes: _notes.text,
      mayApprove: mayApprove,
    );
    if (transfer == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('transfer.created'.tr())));
    context.pushReplacement(AppRoutes.internalTransferFor(transfer.id));
  }

  Future<void> _pickDate(InternalTransferFormCubit cubit) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.state.requiredBy ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null) cubit.setRequiredBy(picked);
  }

  Future<void> _addSku(InternalTransferFormCubit cubit) async {
    final sku = await showAppSheet<TransferSku>(
      context: context,
      title: 'transfer.add_line'.tr(),
      builder: (sheetContext) => AppMenuGroup(
        children: [
          for (final s in cubit.state.pickable)
            AppMenuRow(
              icon: Icons.inventory_2_outlined,
              title: s.label,
              subtitle: s.code.isEmpty ? null : s.code,
              onTap: () => Navigator.of(sheetContext).pop(s),
            ),
        ],
      ),
    );
    if (sku == null) return;
    cubit.addSku(sku);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<InternalTransferFormCubit>();
    final state = cubit.state;
    final options = state.options;
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    final mayApprove = _perms(context).approve;

    return Scaffold(
      appBar: AppBar(title: Text('transfer.new'.tr())),
      bottomNavigationBar: options == null
          ? null
          : AppBottomBar(
              leading: (state.submit.message ?? '').isEmpty
                  ? null
                  : FormMessage(message: state.submit.message),
              child: SubmitButton(
                busy: state.submit.isSubmitting,
                label: 'transfer.create'.tr(),
                onPressed: (state.canSubmit || state.sameBranch) ? () => _submit(mayApprove) : null,
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
              if (options.branches.length < 2)
                AppBanner(tone: AppTone.warning, message: 'transfer.need_two_branches'.tr()),
              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: Column(
                  children: [
                    IdPicker(
                      label: 'transfer.source'.tr(),
                      value: state.sourceId,
                      items: options.branches,
                      idOf: (b) => b.id,
                      labelOf: (b) => b.name(locale),
                      error: state.submit.fieldError('source_branch_id'),
                      onChanged: cubit.chooseSource,
                    ),
                    IdPicker(
                      label: 'transfer.destination'.tr(),
                      value: state.destinationId,
                      items: options.branches,
                      idOf: (b) => b.id,
                      labelOf: (b) => b.name(locale),
                      error: state.sameBranch
                          ? 'transfer.same_branch'.tr()
                          : state.submit.fieldError('destination_branch_id'),
                      onChanged: cubit.chooseDestination,
                    ),
                    CodePicker(
                      label: 'transfer.priority'.tr(),
                      value: state.priority,
                      codes: options.priorities,
                      labelOf: _priorityLabel,
                      error: state.submit.fieldError('priority'),
                      onChanged: cubit.choosePriority,
                    ),
                    AppDateField(
                      label: 'transfer.required_by'.tr(),
                      value: state.requiredBy,
                      hint: 'common.optional'.tr(),
                      error: state.submit.fieldError('required_by_date'),
                      onTap: () => _pickDate(cubit),
                      onClear: state.requiredBy == null ? null : () => cubit.setRequiredBy(null),
                    ),
                  ],
                ),
              ),
              AppSectionLabel(
                'transfer.lines'.tr(),
                trailing: state.pickable.isEmpty
                    ? null
                    : AppButton.text(
                        label: 'transfer.add_line'.tr(),
                        icon: Icons.add_rounded,
                        onPressed: () => _addSku(cubit),
                      ),
              ),
              if (state.lines.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                  child: Text(
                    options.skus.isEmpty ? 'transfer.no_skus'.tr() : 'transfer.no_lines_yet'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.textTertiary),
                  ),
                ),
              if (state.submit.fieldError('lines') != null)
                FormMessage(message: state.submit.fieldError('lines')),
              for (final line in state.lines)
                AppCard.item(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(top: AppTokens.space3),
                          child: Text(line.sku.label, style: theme.textTheme.titleSmall),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Expanded(
                        flex: 2,
                        child: AppQtyField(
                          controller: _qty.putIfAbsent(
                            line.sku.id,
                            () => TextEditingController(text: fmtQty(line.qty)),
                          ),
                          onChanged: (value) =>
                              cubit.setQty(line.sku.id, parseFleetNumber(value) ?? 0),
                        ),
                      ),
                      IconButton(
                        tooltip: 'common.delete'.tr(),
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () {
                          _qty.remove(line.sku.id)?.dispose();
                          cubit.removeSku(line.sku.id);
                        },
                      ),
                    ],
                  ),
                ),
              AppField(
                controller: _notes,
                label: 'transfer.notes'.tr(),
                hint: 'common.optional'.tr(),
                maxLength: 1000,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                serverError: state.submit.fieldError('notes'),
              ),
              // Only for whoever may approve; anyone else's transfer starts
              // as a draft for someone who can.
              if (mayApprove)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('transfer.approve_now'.tr()),
                  subtitle: Text('transfer.approve_now_hint'.tr()),
                  value: state.approveNow,
                  onChanged: cubit.setApproveNow,
                ),
            ],
          );
        },
      ),
    );
  }
}
