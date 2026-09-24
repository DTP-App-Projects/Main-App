import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/invoice.dart';
import '../../../../data/repositories/receivables_repository.dart';

/// Submit a post-invoice return: pick the lines, say why, send it. The
/// supplier approves or rejects, and a credit note follows.
class ReturnFormView extends StatelessWidget {
  final int invoiceId;

  const ReturnFormView({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ReturnFormCubit(getIt<ReceivablesRepository>(), invoiceId)..load(),
        child: const _ReturnFormBody(),
      );
}

class ReturnFormState {
  final bool loading;
  final Invoice? invoice;
  final String? errorMessage;
  final bool offline;

  /// Quantity to return, per invoice line id. A line the user has not touched
  /// is simply absent.
  final Map<int, double> quantities;

  final String reasonType;
  final SubmitState action;
  final bool submitted;

  const ReturnFormState({
    this.loading = true,
    this.invoice,
    this.errorMessage,
    this.offline = false,
    this.quantities = const {},
    this.reasonType = 'damage',
    this.action = const SubmitState(),
    this.submitted = false,
  });

  bool get hasLines => quantities.values.any((qty) => qty > 0);

  ReturnFormState copyWith({
    bool? loading,
    Invoice? invoice,
    String? errorMessage,
    bool? offline,
    Map<int, double>? quantities,
    String? reasonType,
    SubmitState? action,
    bool? submitted,
    bool clearError = false,
  }) =>
      ReturnFormState(
        loading: loading ?? this.loading,
        invoice: invoice ?? this.invoice,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        quantities: quantities ?? this.quantities,
        reasonType: reasonType ?? this.reasonType,
        action: action ?? this.action,
        submitted: submitted ?? this.submitted,
      );
}

class ReturnFormCubit extends Cubit<ReturnFormState> {
  final ReceivablesRepository _repo;
  final int invoiceId;

  ReturnFormCubit(this._repo, this.invoiceId) : super(const ReturnFormState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.invoice(invoiceId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, invoice: data));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  void setQty(int invoiceLineId, double qty) => emit(state.copyWith(
        quantities: {...state.quantities, invoiceLineId: qty},
      ));

  void setReasonType(String value) => emit(state.copyWith(reasonType: value));

  /// Not auto-retried: a second return against the same invoice is a real
  /// document, not a duplicate to shrug off.
  Future<bool> submit(String notes) async {
    final invoice = state.invoice;
    if (invoice == null || state.action.isSubmitting || !state.hasLines) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final lines = <ReturnLineInput>[
      for (final line in invoice.lines)
        if ((state.quantities[line.id] ?? 0) > 0)
          ReturnLineInput(
            invoiceLineId: line.id,
            skuId: line.skuId,
            qty: state.quantities[line.id]!,
          ),
    ];

    final result = await _repo.submitReturn(
      invoiceId: invoiceId,
      reasonType: state.reasonType,
      lines: lines,
      reasonNotes: notes.trim().isEmpty ? null : notes.trim(),
      currencyCode: invoice.currencyCode.isEmpty ? null : invoice.currencyCode,
    );

    if (result case Ok()) {
      emit(state.copyWith(
        submitted: true,
        action: const SubmitState(status: FormStatus.success),
      ));
      return true;
    }
    emit(state.copyWith(action: result.failureState));
    return false;
  }
}

class _ReturnFormBody extends StatefulWidget {
  const _ReturnFormBody();

  @override
  State<_ReturnFormBody> createState() => _ReturnFormBodyState();
}

class _ReturnFormBodyState extends State<_ReturnFormBody> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ReturnFormCubit>();
    final state = cubit.state;
    final invoice = state.invoice;
    final theme = Theme.of(context);
    final showForm = invoice != null && !state.submitted;

    return Scaffold(
      appBar: AppBar(title: Text('returns.title'.tr())),
      bottomNavigationBar: !showForm
          ? null
          : AppBottomBar(
              // Why the button is off, said right above it.
              leading: state.hasLines
                  ? null
                  : Text(
                      'returns.pick_a_line'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
              child: SubmitButton(
                busy: state.action.isSubmitting,
                label: 'returns.submit'.tr(),
                onPressed: state.hasLines ? () => cubit.submit(_notes.text) : null,
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading && invoice == null) return const FormSkeleton(fields: 4);
          if (invoice == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            final message = state.errorMessage;
            return AppErrorState(
              message: (message == null || message.isEmpty) ? 'errors.generic'.tr() : message,
              onRetry: cubit.load,
            );
          }
          if (state.submitted) {
            return AppSuccessState(
              title: 'returns.submitted'.tr(),
              body: 'returns.submitted_hint'.tr(),
              actionLabel: 'common.close'.tr(),
              onAction: () => Navigator.of(context).pop(),
            );
          }

          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              FormMessage(message: state.action.message),
              AppBanner(message: 'returns.hint'.tr(), tone: AppTone.info),

              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: CodePicker(
                  label: 'returns.reason_type'.tr(),
                  value: state.reasonType,
                  codes: PostInvoiceReturn.reasonTypes,
                  labelOf: (code) => 'returns.reason_$code'.tr(),
                  error: state.action.fieldError('reason_type'),
                  onChanged: (value) => cubit.setReasonType(value ?? 'other'),
                ),
              ),

              AppSectionLabel('order.lines'.tr()),
              for (final line in invoice.lines)
                AppCard.item(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.space4,
                    AppTokens.space4,
                    AppTokens.space4,
                    AppTokens.space1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(line.skuName, style: theme.textTheme.titleSmall),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          AppBadge(
                            '${'returns.invoiced_qty'.tr()}: ${_fmt(line.qty)}',
                            tone: AppTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space3),
                      _ReturnQtyField(
                        max: line.qty,
                        onChanged: (qty) => cubit.setQty(line.id, qty),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppTokens.space2),
              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: AppField(
                  controller: _notes,
                  label: 'returns.notes'.tr(),
                  hint: 'common.optional'.tr(),
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  serverError: state.action.fieldError('reason_notes'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

class _ReturnQtyField extends StatefulWidget {
  final double max;
  final ValueChanged<double> onChanged;

  const _ReturnQtyField({required this.max, required this.onChanged});

  @override
  State<_ReturnQtyField> createState() => _ReturnQtyFieldState();
}

class _ReturnQtyFieldState extends State<_ReturnQtyField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final qty = double.tryParse(text.trim()) ?? 0;
    // Returning more than was invoiced is the one thing the form can rule out
    // before the server does.
    setState(() => _error = qty > widget.max ? 'returns.qty_too_high'.tr() : null);
    widget.onChanged(_error == null ? qty : 0);
  }

  @override
  Widget build(BuildContext context) => AppQtyField(
        controller: _controller,
        label: 'returns.return_qty'.tr(),
        // The ceiling sits right in the field: "/ 5".
        unit: '/ ${_fmt(widget.max)}',
        error: _error,
        onChanged: _onChanged,
      );

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}
