import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/advanced/shelf.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/repositories/contracts_repository.dart';
import '../view_models/advanced_cubits.dart';

/// A state view never shows an empty message.
String _messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

/// The shelf panel: which contracts this organization keeps stock on.
class ShelfPanelView extends StatelessWidget {
  const ShelfPanelView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShelfPanelCubit(getIt<ContractsRepository>())..load(),
        child: const _ShelfPanelBody(),
      );
}

class _ShelfPanelBody extends StatelessWidget {
  const _ShelfPanelBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShelfPanelCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('shelf.title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading) return const ListSkeleton(rows: 5);
          if (state.offline) return AppOfflineState(onRetry: cubit.load);
          if (state.errorMessage != null) {
            return AppErrorState(message: _messageOr(state.errorMessage), onRetry: cubit.load);
          }
          if (state.contracts.isEmpty) {
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: AppEmptyState(
                icon: Icons.shelves,
                title: 'shelf.empty'.tr(),
                body: 'shelf.empty_hint'.tr(),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: AppTokens.pagePadding,
              children: [
                for (final contract in state.contracts)
                  Semantics(
                    button: true,
                    child: AppCard.item(
                      onTap: () => context.push(AppRoutes.shelfCountFor(contract.id)),
                      child: Row(
                        children: [
                          const AppIconCircle(Icons.shelves, size: 40),
                          const SizedBox(width: AppTokens.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contract.displayName.isEmpty
                                      ? '#${contract.id}'
                                      : contract.displayName,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'shelf.visits'.tr(
                                    namedArgs: {'count': '${contract.visitsCount}'},
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          StatusChip(status: contract.status),
                          const SizedBox(width: AppTokens.space1),
                          DirectionalChevron(size: 20, color: t.iconMuted),
                        ],
                      ),
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

/// The shelf count.
///
/// It opens by asking the server what the last visit left behind, because
/// "what was on the shelf last time" is not something anyone should have to
/// remember. Photos are uploaded first and only their **paths** are sent.
class ShelfCountView extends StatelessWidget {
  final int contractId;
  final int branchId;

  const ShelfCountView({super.key, required this.contractId, this.branchId = 0});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShelfCountCubit(
          getIt<ContractsRepository>(),
          contractId: contractId,
          branchId: branchId,
        ),
        child: const _ShelfCountBody(),
      );
}

class _ShelfCountBody extends StatefulWidget {
  const _ShelfCountBody();

  @override
  State<_ShelfCountBody> createState() => _ShelfCountBodyState();
}

class _ShelfCountBodyState extends State<_ShelfCountBody> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addSku(BuildContext context) async {
    final cubit = context.read<ShelfCountCubit>();
    final picked = await showLookupPicker(
      context: context,
      title: 'order.pick_sku'.tr(),
      lookup: Lookup.skus,
      query: {'inventory_context': 'shelf'},
    );
    if (picked == null || !context.mounted) return;

    cubit.addSku(skuId: picked.id, skuName: picked.label(context.locale.toString()));
    // One call fills `previous_count` for every row on the form.
    await cubit.prefillPreviousCounts();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShelfCountCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);

    if (state.submitted) {
      return Scaffold(
        appBar: AppBar(title: Text('shelf.count_title'.tr())),
        body: AppSuccessState(
          title: 'shelf.submitted'.tr(),
          body: 'shelf.submitted_hint'.tr(),
          actionLabel: 'common.close'.tr(),
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    // The warning sits under the first row whose numbers do not add up.
    final firstWrong = state.lines.indexWhere((line) => line.looksWrong);

    return Scaffold(
      appBar: AppBar(
        title: Text('shelf.count_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'shelf.prefill'.tr(),
            icon: state.prefilling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history_rounded),
            onPressed: state.prefilling ? null : cubit.prefillPreviousCounts,
          ),
          const SizedBox(width: AppTokens.space2),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The submit's answer, in the bar right above the button.
            FormMessage(message: state.action.message),
            SubmitButton(
              busy: state.action.isSubmitting,
              label: 'shelf.submit'.tr(),
              onPressed: state.hasLines ? () => cubit.submit(notes: _notes.text) : null,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: AppTokens.pagePadding,
        children: [
          AppBanner(message: 'shelf.count_hint'.tr(), tone: AppTone.info, icon: Icons.history_rounded),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CodePicker(
                  label: 'shelf.adjustment_type'.tr(),
                  value: state.adjustmentType,
                  codes: ShelfAdjustment.adjustmentTypes,
                  labelOf: (code) => 'shelf.type_$code'.tr(),
                  onChanged: (value) => cubit.setAdjustmentType(value ?? 'manual'),
                ),
                CodePicker(
                  label: 'shelf.visit_type'.tr(),
                  value: state.visitType,
                  codes: ShelfAdjustment.visitTypes,
                  labelOf: (code) => 'shelf.visit_$code'.tr(),
                  onChanged: (value) => cubit.setVisitType(value ?? 'supplier_self'),
                ),
              ],
            ),
          ),

          AppSectionLabel(
            'catalog.skus'.tr(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.space1,
              AppTokens.space4,
              0,
              AppTokens.space2,
            ),
            trailing: AppButton.text(
              icon: Icons.add_rounded,
              label: 'shelf.add_sku'.tr(),
              onPressed: () => _addSku(context),
            ),
          ),

          if (state.lines.isEmpty)
            AppCard(
              child: Row(
                children: [
                  const AppIconCircle(Icons.qr_code_2_rounded, tone: AppTone.neutral),
                  const SizedBox(width: AppTokens.space3),
                  Expanded(
                    child: Text('shelf.no_lines'.tr(), style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < state.lines.length; i++) ...[
              _CountCard(key: ValueKey(state.lines[i].skuId), line: state.lines[i]),
              if (i == firstWrong)
                AppBanner(message: 'shelf.negative_sold'.tr(), tone: AppTone.warning),
            ],

          const SizedBox(height: AppTokens.space4),
          AppField(
            controller: _notes,
            label: 'profile.notes'.tr(),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final CountDraft line;

  const _CountCard({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final cubit = context.read<ShelfCountCubit>();
    final wrong = line.looksWrong;

    return AppCard(
      margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppTokens.space4,
        AppTokens.space2,
        AppTokens.space2,
        AppTokens.space4,
      ),
      borderColor: wrong ? t.dangerBorder : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.skuName, style: theme.textTheme.titleSmall),
                    Text(
                      '${'shelf.previous_count'.tr()}: ${_fmt(line.previousCount)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'shelf.remove_sku'.tr(),
                color: t.iconMuted,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => cubit.removeSku(line.skuId),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppTokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CountField(
                        label: 'shelf.current_count'.tr(),
                        initial: line.currentCount,
                        onChanged: (value) => cubit.updateLine(
                          line.skuId,
                          (draft) => draft.copyWith(currentCount: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: _CountField(
                        label: 'shelf.added_count'.tr(),
                        initial: line.addedCount,
                        onChanged: (value) => cubit.updateLine(
                          line.skuId,
                          (draft) => draft.copyWith(addedCount: value),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CountField(
                        label: 'shelf.damaged_count'.tr(),
                        initial: line.damagedCount,
                        onChanged: (value) => cubit.updateLine(
                          line.skuId,
                          (draft) => draft.copyWith(damagedCount: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: _CountField(
                        label: 'shelf.expired_count'.tr(),
                        initial: line.expiredCount,
                        onChanged: (value) => cubit.updateLine(
                          line.skuId,
                          (draft) => draft.copyWith(expiredCount: value),
                        ),
                      ),
                    ),
                  ],
                ),
                // Live arithmetic, so a typo is caught on the shelf rather than
                // in the settlement a month later.
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppTokens.space3,
                    vertical: AppTokens.space2 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: wrong ? t.dangerTint : t.primaryTint,
                    borderRadius: AppTokens.mdRadius,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        wrong ? Icons.error_outline_rounded : Icons.shopping_bag_outlined,
                        size: 20,
                        color: wrong ? t.danger : t.primary,
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: Text(
                          'shelf.implied_sold'.tr(namedArgs: {'qty': _fmt(line.impliedSold)}),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: wrong ? t.dangerText : t.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Photos are optional evidence, so they stay folded until needed.
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              maintainState: true,
              tilePadding: const EdgeInsetsDirectional.only(end: AppTokens.space2),
              childrenPadding: const EdgeInsetsDirectional.only(end: AppTokens.space2),
              leading: Icon(Icons.photo_camera_outlined, size: 20, color: t.iconMuted),
              title: Text('shelf.photos'.tr(), style: theme.textTheme.labelMedium),
              children: [
                ProofFileField(
                  label: 'shelf.before_photo'.tr(),
                  module: 'shelf_adjustments',
                  fieldKey: 'before_photo_path',
                  onUploaded: (path) => cubit.updateLine(
                    line.skuId,
                    (draft) => draft.copyWith(beforePhotoPath: path),
                  ),
                ),
                ProofFileField(
                  label: 'shelf.after_photo'.tr(),
                  module: 'shelf_adjustments',
                  fieldKey: 'after_photo_path',
                  onUploaded: (path) => cubit.updateLine(
                    line.skuId,
                    (draft) => draft.copyWith(afterPhotoPath: path),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

class _CountField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;

  const _CountField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_CountField> createState() => _CountFieldState();
}

class _CountFieldState extends State<_CountField> {
  late final _controller = TextEditingController(
    text: widget.initial == 0 ? '' : widget.initial.toStringAsFixed(0),
  );

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
}

/// The shelf documents that are read-only in the app for now: consignment
/// shipments, sales reports and stock counts all share one list shape.
class ShelfAdjustmentsView extends StatelessWidget {
  const ShelfAdjustmentsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ShelfAdjustmentsCubit(getIt<ContractsRepository>())..load(),
        child: const _AdjustmentsBody(),
      );
}

class _AdjustmentsBody extends StatelessWidget {
  const _AdjustmentsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShelfAdjustmentsCubit>();

    return Scaffold(
      appBar: AppBar(title: Text('shelf.adjustments'.tr())),
      body: PagedListView<ShelfAdjustment>(
        state: cubit.state,
        onRefresh: cubit.refresh,
        onLoadMore: cubit.loadMore,
        emptyIcon: Icons.shelves,
        emptyTitle: 'shelf.no_adjustments'.tr(),
        itemBuilder: (adjustment) => _AdjustmentRow(adjustment: adjustment),
      ),
    );
  }
}

/// An adjustment as a read-only card. There is no detail screen for these
/// yet, so the row is not a button and carries no chevron.
class _AdjustmentRow extends StatelessWidget {
  final ShelfAdjustment adjustment;

  const _AdjustmentRow({required this.adjustment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return AppCard.item(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '#${adjustment.id}',
                  style: AppType.code(t.textPrimary),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: adjustment.status),
            ],
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            'shelf.type_${adjustment.adjustmentType}'.tr(),
            style: theme.textTheme.bodyMedium,
          ),
          if (adjustment.notes.isNotEmpty || adjustment.createdAt != null) ...[
            const SizedBox(height: AppTokens.space1),
            Row(
              children: [
                Expanded(
                  child: Text(
                    adjustment.notes,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (adjustment.createdAt != null) ...[
                  const SizedBox(width: AppTokens.space2),
                  DateText(adjustment.createdAt, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
