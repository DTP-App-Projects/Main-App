import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/repositories/shipments_repository.dart';
import '../view_models/goods_receipt_cubit.dart';

/// Confirm goods receipt: count each line, attach proof, submit — then
/// dispute if what arrived does not match what was shipped.
class GoodsReceiptFormView extends StatelessWidget {
  final int deliveryNoteId;

  const GoodsReceiptFormView({super.key, required this.deliveryNoteId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            GoodsReceiptCubit(getIt<ShipmentsRepository>(), deliveryNoteId)..load(),
        child: const _ReceiptBody(),
      );
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GoodsReceiptCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final showForm = state.note != null && state.created == null;

    return Scaffold(
      appBar: AppBar(title: Text('receipt.title'.tr())),
      bottomNavigationBar: !showForm
          ? null
          : AppBottomBar(
              // Why the button is off, said right above it.
              leading: state.missingReason
                  ? Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: t.fieldError),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: Text(
                            'receipt.reason_required'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(color: t.fieldError),
                          ),
                        ),
                      ],
                    )
                  : null,
              child: SubmitButton(
                busy: state.action.isSubmitting,
                label: 'receipt.submit'.tr(),
                onPressed: state.missingReason ? null : cubit.submit,
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading && state.note == null) return const FormSkeleton(fields: 4);
          if (state.note == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }

          // Once the receipt exists the form is done; what is left is the
          // dispute window.
          if (state.created != null) return _ReceiptDone(cubit: cubit);

          final balanced = state.lines.where((line) => line.balances).length;
          final total = state.lines.length;

          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              FormMessage(message: state.action.message),
              AppBanner(message: 'receipt.hint'.tr(), tone: AppTone.info),

              // ---- progress ------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text('order.lines'.tr(), style: theme.textTheme.titleSmall),
                  ),
                  AppBadge(
                    'receipt.lines_checked'.tr(namedArgs: {
                      'done': '$balanced',
                      'total': '$total',
                    }),
                    icon: balanced == total
                        ? Icons.check_circle_outline_rounded
                        : Icons.pending_outlined,
                    tone: balanced == total ? AppTone.brand : AppTone.warning,
                  ),
                ],
              ),
              if (state.hasMismatch)
                AppBanner(
                  message: 'receipt.mismatch_warning'.tr(),
                  tone: AppTone.warning,
                  margin: const EdgeInsetsDirectional.only(top: AppTokens.space3),
                ),
              const SizedBox(height: AppTokens.space3),

              for (final draft in state.lines)
                _ReceiptLineCard(draft: draft, cubit: cubit),

              // ---- proof and notes -----------------------------------------
              AppSectionLabel('receipt.proof'.tr()),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProofFileField(
                      label: 'receipt.proof'.tr(),
                      module: 'goods_receipts',
                      fieldKey: 'proof_file',
                      onUploaded: cubit.setProof,
                    ),
                    _NotesField(onChanged: cubit.setNotes),
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

class _ReceiptLineCard extends StatelessWidget {
  final ReceiptLineDraft draft;
  final GoodsReceiptCubit cubit;

  const _ReceiptLineCard({required this.draft, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return AppCard.item(
      borderColor: draft.balances ? null : t.warning.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  draft.line.skuName.isEmpty ? draft.line.productName : draft.line.skuName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              // What the driver handed over: the figure every count is
              // checked against.
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppTokens.space3,
                  vertical: AppTokens.space1,
                ),
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppTokens.mdRadius,
                ),
                child: Text(
                  'receipt.shipped'.tr(namedArgs: {'qty': _fmt(draft.line.shippedQty)}),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: t.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _QtyField(
                  label: 'receipt.received'.tr(),
                  value: draft.receivedQty,
                  onChanged: (value) => cubit.updateLine(draft.line.id, received: value),
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: _QtyField(
                  label: 'receipt.rejected'.tr(),
                  value: draft.rejectedQty,
                  onChanged: (value) => cubit.updateLine(draft.line.id, rejected: value),
                ),
              ),
            ],
          ),
          if (draft.rejectedQty > 0)
            AppFieldShell(
              label: 'receipt.rejection_reason'.tr(),
              required: true,
              bottom: AppTokens.space3,
              child: TextField(
                decoration: InputDecoration(
                  errorText: draft.needsReason ? 'validation.required'.tr() : null,
                ),
                onChanged: (value) => cubit.updateLine(draft.line.id, reason: value),
              ),
            ),
          if (!draft.balances)
            AppBanner(
              message: 'receipt.unaccounted'.tr(namedArgs: {'qty': _fmt(draft.unaccounted)}),
              tone: AppTone.warning,
              margin: EdgeInsetsDirectional.zero,
            ),
        ],
      ),
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

class _QtyField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _QtyField({required this.label, required this.value, required this.onChanged});

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final _controller = TextEditingController(text: _fmt(widget.value));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppQtyField(
        controller: _controller,
        label: widget.label,
        onChanged: (text) => widget.onChanged(double.tryParse(text.trim()) ?? 0),
      );

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

/// The notes field owns its controller; every edit still goes straight to
/// the cubit, as before.
class _NotesField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _NotesField({required this.onChanged});

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppField(
        controller: _controller,
        label: 'receipt.notes'.tr(),
        hint: 'common.optional'.tr(),
        maxLines: 2,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        onChanged: widget.onChanged,
      );
}

/// After submitting: the server's own mismatch flag, and the dispute window.
class _ReceiptDone extends StatelessWidget {
  final GoodsReceiptCubit cubit;

  const _ReceiptDone({required this.cubit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = cubit.state.created!;
    final busy = cubit.state.action.isSubmitting;

    return AppSuccessState(
      title: 'receipt.created'.tr(),
      actionLabel: 'common.done'.tr(),
      onAction: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormMessage(message: cubit.state.action.message),
          if (receipt.qtyMismatchWithDriver)
            AppBanner(message: 'receipt.driver_mismatch'.tr(), tone: AppTone.danger),
          if (receipt.isDisputed)
            AppBanner(
              message: 'receipt.disputed'.tr(),
              tone: AppTone.warning,
              icon: Icons.report_problem_outlined,
            )
          else
            AppButton.outlineDanger(
              label: 'receipt.dispute'.tr(),
              icon: Icons.report_problem_outlined,
              busy: busy,
              onPressed: busy ? null : () => _dispute(context),
            ),
          const SizedBox(height: AppTokens.space3),
          Text(
            'receipt.dispute_hint'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// The server's own bounds, checked before sending so a 400 never comes
  /// back for something the form could have caught: a note outside them
  /// reopens the prompt with the rule as its body.
  Future<void> _dispute(BuildContext context) async {
    // The server's bounds are enforced in the dialog (confirm disabled below
    // the minimum), so a short note never reopens the prompt empty.
    final value = await showAppReasonDialog(
      context,
      title: 'receipt.dispute'.tr(),
      hint: 'receipt.dispute_reason_hint'.tr(),
      required: true,
      destructive: true,
      maxLength: GoodsReceiptCubit.maxDisputeLength,
      minLength: GoodsReceiptCubit.minDisputeLength,
      lengthRule: 'order.note_length'.tr(namedArgs: {
        'min': '${GoodsReceiptCubit.minDisputeLength}',
        'max': '${GoodsReceiptCubit.maxDisputeLength}',
      }),
    );
    if (value == null) return;
    final reason = value.trim();
    await cubit.dispute(reason);
  }
}
