import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/lookups/lookup_item.dart';
import '../../../data/models/trade/purchase_order.dart';
import '../../../data/repositories/lookups_repository.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../../data/repositories/shipments_repository.dart';
import '../view_models/delivery_note_form_cubit.dart';

/// «إنشاء إذن تسليم» — the supplier ships from an approved order.
class DeliveryNoteFormView extends StatelessWidget {
  final int orderId;

  const DeliveryNoteFormView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DeliveryNoteFormCubit(
          getIt<OrdersRepository>(),
          getIt<ShipmentsRepository>(),
          getIt<LookupsRepository>(),
          orderId,
        )..load(),
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
    for (final controller in _qty.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PurchaseOrderLine line, double value) =>
      _qty.putIfAbsent(line.id, () => TextEditingController(text: _format(value)));

  static String _format(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);

  Future<void> _submit() async {
    final cubit = context.read<DeliveryNoteFormCubit>();
    final note = await cubit.submit(notes: _notes.text);
    if (note == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('dn.created'.tr())));
    // Replace: Back should not offer to ship the same quantities twice.
    context.pushReplacement(AppRoutes.outboundDetailFor(note.id));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DeliveryNoteFormCubit>();
    final state = cubit.state;
    final order = state.order;
    final theme = Theme.of(context);
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('dn.new_title'.tr())),
      bottomNavigationBar: order == null
          ? null
          : AppBottomBar(
              leading: (state.submit.message ?? '').isEmpty ? null : FormMessage(message: state.submit.message),
              child: SubmitButton(
                busy: state.submit.isSubmitting,
                label: 'dn.create'.tr(),
                onPressed: state.hasSomethingToShip && state.supplierBranchId != null ? _submit : null,
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading) return const FormSkeleton(fields: 4);
          if (order == null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(
              message: (state.errorMessage ?? '').isEmpty ? 'errors.generic'.tr() : state.errorMessage!,
              onRetry: cubit.load,
            );
          }
          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DetailRow(
                      label: 'dn.order'.tr(),
                      value: Text(order.code, textDirection: TextDirection.ltr),
                    ),
                    DetailRow(label: 'order.trader'.tr(), value: Text(order.trader?.name ?? '—')),
                    DetailRow(label: 'dn.to_branch'.tr(), value: Text('dn.order_branch'.tr())),
                  ],
                ),
              ),
              AppSectionLabel('dn.from_section'.tr()),
              AppCard(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  AppTokens.cardPadding,
                  0,
                ),
                child: IdPicker<LookupItem>(
                  label: 'dn.from_branch'.tr(),
                  value: state.supplierBranchId,
                  items: state.supplierBranches,
                  idOf: (b) => b.id,
                  labelOf: (b) => b.label(locale),
                  error: state.submit.fieldError('supplier_branch_id'),
                  onChanged: cubit.chooseBranch,
                ),
              ),
              AppSectionLabel('dn.lines'.tr()),
              for (final line in order.lines)
                AppCard.item(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        line.skuName.isEmpty ? line.skuCode : line.skuName,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTokens.space1),
                      Text(
                        'dn.line_counts'.tr(namedArgs: {
                          'ordered': _format(line.qty),
                          'shipped': _format(line.shippedQty),
                          'open': _format(DeliveryNoteFormState.remaining(line)),
                        }),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppTokens.space2),
                      if (DeliveryNoteFormState.remaining(line) > 0)
                        AppQtyField(
                          controller: _controllerFor(line, state.shipQty[line.id] ?? 0),
                          label: 'dn.ship_qty'.tr(),
                          decimal: true,
                          onChanged: (value) => cubit.setQty(line, double.tryParse(value.trim()) ?? 0),
                        )
                      else
                        AppBadge('dn.fully_shipped'.tr(), tone: AppTone.brand, icon: Icons.check_rounded),
                    ],
                  ),
                ),
              AppSectionLabel('dn.proof_section'.tr()),
              ProofFileField(
                label: 'dn.proof'.tr(),
                module: 'delivery_notes',
                fieldKey: 'proof_file',
                onUploaded: cubit.setProof,
                error: state.submit.fieldError('proof_file'),
              ),
              AppField(
                controller: _notes,
                label: 'dn.notes'.tr(),
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
