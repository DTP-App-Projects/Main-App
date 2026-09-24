import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/trade/catalog.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../view_models/supplier_cubits.dart';

/// The supplier's own catalogue. Tapping a product opens its SKU rules.
class SupplierCatalogView extends StatelessWidget {
  const SupplierCatalogView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SupplierProductsCubit(getIt<CatalogRepository>())..load(),
        child: const _SupplierCatalogBody(),
      );
}

class _SupplierCatalogBody extends StatefulWidget {
  const _SupplierCatalogBody();

  @override
  State<_SupplierCatalogBody> createState() => _SupplierCatalogBodyState();
}

class _SupplierCatalogBodyState extends State<_SupplierCatalogBody> {
  final _search = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 400),
      () => context.read<SupplierProductsCubit>().setSearch(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SupplierProductsCubit>();
    final locale = context.locale.toString();
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('supplier_catalog.title'.tr())),
      body: Column(
        children: [
          AppSearchField(
            controller: _search,
            onChanged: _onChanged,
            onSubmitted: context.read<SupplierProductsCubit>().setSearch,
            hint: 'catalog.search_hint'.tr(),
          ),
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: AppTokens.gutter),
            child: _RulesWarning(margin: EdgeInsetsDirectional.zero),
          ),
          Expanded(
            child: PagedListView<Product>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.inventory_2_outlined,
              emptyTitle: 'catalog.empty'.tr(),
              itemBuilder: (product) => AppCard.item(
                onTap: () => context.push(AppRoutes.skuRulesFor(product.id)),
                child: Row(
                  children: [
                    const AppIconCircle(Icons.inventory_2_outlined, size: 40),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.displayName(locale),
                            style: theme.textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'catalog.sku_count'.tr(namedArgs: {'count': '${product.skusCount}'}),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    DirectionalChevron(size: 20, color: t.iconMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The SKU rules screen.
///
/// **These settings are what reject the trader's order lines.** The copy says
/// so, because a supplier who sets `order_step_qty = 6` and then hears "the
/// app rejected my order" deserves to know why.
class SkuRulesView extends StatelessWidget {
  final int productId;

  const SkuRulesView({super.key, required this.productId});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SkuRulesCubit(
          getIt<CatalogRepository>(),
          getIt<SupplierRepository>(),
          productId,
        )..load(),
        child: const _SkuRulesBody(),
      );
}

class _SkuRulesBody extends StatelessWidget {
  const _SkuRulesBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SkuRulesCubit>();
    final state = cubit.state;
    final product = state.product;
    final locale = context.locale.toString();
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(product?.displayName(locale) ?? 'catalog.skus'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading && product == null) return const DetailSkeleton();
          if (product == null) {
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
                FormMessage(message: state.action.message),
                const _RulesWarning(),
                if (product.skus.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        const AppIconCircle(Icons.qr_code_2_rounded, tone: AppTone.neutral),
                        const SizedBox(height: AppTokens.space3),
                        Text(
                          'catalog.no_skus'.tr(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  for (final sku in product.skus)
                    _SkuRulesCard(sku: sku, locale: locale),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkuRulesCard extends StatefulWidget {
  final Sku sku;
  final String locale;

  const _SkuRulesCard({required this.sku, required this.locale});

  @override
  State<_SkuRulesCard> createState() => _SkuRulesCardState();
}

class _SkuRulesCardState extends State<_SkuRulesCard> {
  late final _minQty = TextEditingController(text: _fmt(widget.sku.minOrderQty));
  late final _stepQty = TextEditingController(text: _fmt(widget.sku.orderStepQty));
  late final _packQty = TextEditingController(text: _fmt(widget.sku.packQuantity));
  late final _barcode = TextEditingController(text: widget.sku.barcode);

  late String? _status = widget.sku.status.isEmpty ? 'active' : widget.sku.status;
  late bool _barcodeRequired = widget.sku.barcodeRequired;
  bool _expanded = false;

  @override
  void dispose() {
    for (final controller in [_minQty, _stepQty, _packQty, _barcode]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context.read<SkuRulesCubit>().save(
          skuId: widget.sku.id,
          minOrderQty: double.tryParse(_minQty.text.trim()),
          orderStepQty: double.tryParse(_stepQty.text.trim()),
          packQuantity: double.tryParse(_packQty.text.trim()),
          skuStatus: _status,
          barcode: _barcode.text.trim(),
          barcodeRequired: _barcodeRequired,
        );
    if (saved && mounted) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final submit = context.watch<SkuRulesCubit>().state.action;

    return AppCard.item(
      // Editing lifts the card a little so the open one stands out.
      shadow: _expanded,
      borderColor: _expanded ? t.primary : null,
      padding: EdgeInsetsDirectional.fromSTEB(
        AppTokens.space4,
        AppTokens.space4,
        AppTokens.space4,
        _expanded ? AppTokens.space4 : AppTokens.space1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconCircle(Icons.qr_code_2_rounded, size: 40),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Text(
                  widget.sku.displayName(widget.locale),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: widget.sku.status),
            ],
          ),
          if (!_expanded) ...[
            const SizedBox(height: AppTokens.space2),
            DetailRow(
              label: 'catalog.min_order_qty'.tr(),
              value: Text(_fmt(widget.sku.minOrderQty), textDirection: TextDirection.ltr),
            ),
            DetailRow(
              label: 'catalog.order_step'.tr(),
              value: Text(_fmt(widget.sku.orderStepQty), textDirection: TextDirection.ltr),
            ),
            DetailRow(
              label: 'catalog.pack_quantity'.tr(),
              value: Text(_fmt(widget.sku.packQuantity), textDirection: TextDirection.ltr),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton.text(
                label: 'supplier_catalog.edit_rules'.tr(),
                icon: Icons.edit_outlined,
                onPressed: () => setState(() => _expanded = true),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppTokens.space4),
            Divider(height: 1, color: t.divider),
            const SizedBox(height: AppTokens.space4),
            AppField(
              controller: _minQty,
              label: 'catalog.min_order_qty'.tr(),
              helper: 'supplier_catalog.min_hint'.tr(),
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              serverError: submit.fieldError('min_order_qty'),
            ),
            AppField(
              controller: _stepQty,
              label: 'catalog.order_step'.tr(),
              helper: 'supplier_catalog.step_hint'.tr(),
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              serverError: submit.fieldError('order_step_qty'),
            ),
            AppField(
              controller: _packQty,
              label: 'catalog.pack_quantity'.tr(),
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              serverError: submit.fieldError('pack_quantity'),
            ),
            AppField(
              controller: _barcode,
              label: 'supplier_catalog.barcode'.tr(),
              helper: 'supplier_catalog.barcode_hint'.tr(),
              icon: Icons.qr_code_scanner_rounded,
              textDirection: TextDirection.ltr,
              serverError: submit.fieldError('barcode'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('supplier_catalog.barcode_required'.tr(), style: theme.textTheme.titleSmall),
              value: _barcodeRequired,
              onChanged: (value) => setState(() => _barcodeRequired = value),
            ),
            const SizedBox(height: AppTokens.space3),
            CodePicker(
              label: 'supplier_catalog.sku_status'.tr(),
              value: _status,
              codes: SupplierRepository.skuStatuses,
              labelOf: (code) => 'supplier_catalog.status_$code'.tr(),
              error: submit.fieldError('sku_status'),
              onChanged: (value) => setState(() => _status = value),
            ),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: 'common.cancel'.tr(),
                    height: 48,
                    onPressed: () => setState(() => _expanded = false),
                  ),
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: AppButton.primary(
                    label: 'common.save'.tr(),
                    height: 48,
                    busy: submit.isSubmitting,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

/// Why these rules matter, as one compact info banner.
class _RulesWarning extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const _RulesWarning({this.margin = const EdgeInsetsDirectional.only(bottom: AppTokens.space4)});

  @override
  Widget build(BuildContext context) => AppBanner(
        message: 'supplier_catalog.rules_warning'.tr(),
        tone: AppTone.info,
        margin: margin,
      );
}
