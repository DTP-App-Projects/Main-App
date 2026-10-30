import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/lookups/lookup_item.dart';
import '../../../../data/models/trade/order_entry.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../../../../data/repositories/lookups_repository.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../shared/compliance/service_invoice_gate.dart';
import '../../../shared/compliance/views/order_compliance_section.dart';
import '../view_models/new_order_cubit.dart';
import 'order_submitted.dart';

/// «أمر شراء جديد» — the website's guided page (`/b2b/order_entry`), as one
/// scrolling screen: ① buying mode & delivery branch, ② supplier, ③ contract,
/// ④ items & quantities, then one submit. «فقط الموردون والعقود والمنتجات
/// المؤهلة فعلًا تظهر» — and every block says why.
class NewOrderView extends StatelessWidget {
  final int? supplierOrganizationId;

  const NewOrderView({super.key, this.supplierOrganizationId});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => NewOrderCubit(
          getIt<LookupsRepository>(),
          getIt<OrdersRepository>(),
          getIt<CatalogRepository>(),
          preselectedSupplierId: supplierOrganizationId,
        )..load(),
      ),
      BlocProvider(create: (_) => OrdersRestrictionCubit(getIt<ComplianceRepository>())..load()),
    ],
    child: const _NewOrderBody(),
  );
}

class _NewOrderBody extends StatefulWidget {
  const _NewOrderBody();

  @override
  State<_NewOrderBody> createState() => _NewOrderBodyState();
}

class _NewOrderBodyState extends State<_NewOrderBody> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<NewOrderCubit>();
    final order = await cubit.submit(notes: _notes.text);
    if (order == null || !mounted) return;
    await announceSubmittedOrder(context, order, cubit.state.creditReview);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NewOrderCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final ready = !state.loading && state.errorMessage == null;
    // An overdue service invoice: the server would refuse the submit.
    final restricted = context.watch<OrdersRestrictionCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text('new_order.title'.tr())),
      // «الإجمالي التقديري» sits next to the button it commits to.
      bottomNavigationBar: !ready || state.relationship == null
          ? null
          : AppBottomBar(
              leading: Row(
                children: [
                  Expanded(
                    child: Text(
                      'new_order.estimated_total'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  MoneyText(
                    state.estimatedTotal,
                    currency: state.currencyCode.isEmpty ? 'SAR' : state.currencyCode,
                    style: AppType.ledger(t.textPrimary),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormMessage(
                    message:
                        state.action.message ?? (restricted ? 'fees.orders_blocked'.tr() : null),
                  ),
                  SubmitButton(
                    busy: state.action.isSubmitting,
                    label: 'new_order.submit'.tr(),
                    onPressed: state.canSubmit && !restricted ? _submit : null,
                  ),
                ],
              ),
            ),
      body: Builder(
        builder: (context) {
          if (state.loading) return const FormSkeleton(fields: 5);
          if (state.errorMessage != null) {
            if (state.offline) return AppOfflineState(onRetry: cubit.load);
            return AppErrorState(
              message: state.errorMessage!.isEmpty ? 'errors.generic'.tr() : state.errorMessage!,
              onRetry: cubit.load,
            );
          }
          final mode = state.mode;
          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              if (restricted && state.actionCode != ServiceInvoiceCodes.overdue)
                const ServiceInvoiceOverdueBanner(),
              _Counters(state: state),
              ..._modeSection(context, state),
              if (mode != null) ..._supplierSection(context, state, mode),
              if (mode != null && state.relationship != null) ...[
                ..._contractSection(context, state, mode),
                ..._itemsSection(context, state),
              ],
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------- ① mode & delivery branch

  List<Widget> _modeSection(BuildContext context, NewOrderState state) {
    final cubit = context.read<NewOrderCubit>();
    final locale = context.locale.toString();
    // «كل القطاعات» is the empty choice.
    final sectorItems = [
      LookupItem(
        id: 0,
        nameAr: 'كل القطاعات',
        nameEn: 'All sectors',
        code: '',
        status: '',
        raw: const {},
      ),
      ...state.sectors,
    ];

    return [
      _SectionTitle(number: 1, title: 'new_order.mode_title'.tr()),
      for (final mode in PurchaseMode.values)
        Builder(
          builder: (context) {
            final count = state.eligibleFor(mode).length;
            final block = state.modeBlock(mode);
            return _ChoiceRow(
              icon: switch (mode) {
                PurchaseMode.cash => Icons.payments_outlined,
                PurchaseMode.credit => Icons.schedule_rounded,
                PurchaseMode.installment => Icons.calendar_month_outlined,
              },
              title: 'new_order.mode_${mode.name}'.tr(),
              subtitle: block == null
                  ? 'new_order.mode_${mode.name}_hint'.tr()
                  : 'new_order.block_${block.name}'.tr(),
              trailing: block == null
                  ? AppBadge(
                      'new_order.available'.tr(namedArgs: {'count': '$count'}),
                      tone: AppTone.brand,
                    )
                  : AppBadge('new_order.unavailable'.tr(), tone: AppTone.neutral),
              selected: state.mode == mode,
              // An unavailable mode stays readable but cannot be picked.
              onTap: block == null ? () => cubit.chooseMode(mode) : null,
            );
          },
        ),
      const SizedBox(height: AppTokens.space2),
      AppCard(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.cardPadding,
          AppTokens.cardPadding,
          AppTokens.cardPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.sectors.isNotEmpty)
              IdPicker<LookupItem>(
                label: 'new_order.sector'.tr(),
                value: state.sectorId ?? 0,
                items: sectorItems,
                idOf: (s) => s.id,
                labelOf: (s) => s.label(locale),
                required: false,
                onChanged: (id) => cubit.chooseSector(id == 0 ? null : id),
              ),
            IdPicker<LookupItem>(
              label: 'order.delivery_branch'.tr(),
              value: state.branchId,
              items: state.branches,
              idOf: (b) => b.id,
              labelOf: (b) => b.raw['is_default'] == true
                  ? '${b.label(locale)} · ${'new_order.default_branch'.tr()}'
                  : b.label(locale),
              onChanged: cubit.chooseBranch,
            ),
          ],
        ),
      ),
      if (state.branches.isEmpty)
        AppBanner(message: 'new_order.no_branch'.tr(), tone: AppTone.warning),
    ];
  }

  // ---------------------------------------------------------- ② supplier

  List<Widget> _supplierSection(BuildContext context, NewOrderState state, PurchaseMode mode) {
    final cubit = context.read<NewOrderCubit>();
    final locale = context.locale.toString();
    final eligible = state.eligibleFor(mode);
    // The approved ones in this sector that do not qualify, with the reason.
    final blocked = [
      for (final r in state.approvedRelationships)
        if (state.inSector(r) && !eligible.contains(r)) r,
    ];

    String sectorsOf(LookupItem r) {
      final sectors = state.supplierSectors[state.supplierIdOf(r)] ?? const [];
      return sectors.map((s) => s.name).where((n) => n.isNotEmpty).join('، ');
    }

    String subtitle(LookupItem r) {
      final contracts = 'new_order.contracts_count'.tr(
        namedArgs: {'count': '${state.contractsFor(r, mode).length}'},
      );
      final sectors = sectorsOf(r);
      return sectors.isEmpty ? contracts : '$sectors · $contracts';
    }

    return [
      _SectionTitle(
        number: 2,
        title: 'new_order.supplier_title'.tr(),
        trailing: eligible.isEmpty
            ? null
            : Text(
                'new_order.eligible_of'.tr(
                  namedArgs: {
                    'n': '${eligible.length}',
                    'total': '${eligible.length + blocked.length}',
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
      if (eligible.isEmpty)
        AppEmptyState(
          icon: Icons.storefront_outlined,
          title: 'new_order.no_supplier_for_mode'.tr(),
          body: 'new_order.no_supplier_hint'.tr(),
          actionLabel: 'supplier.title'.tr(),
          onAction: () => context.push(AppRoutes.traderSuppliers),
        ),
      for (final r in eligible)
        _ChoiceRow(
          icon: Icons.storefront_outlined,
          title: r.label(locale),
          subtitle: subtitle(r),
          trailing: AppBadge(
            state.relationship?.id == r.id ? 'new_order.selected'.tr() : 'new_order.ready'.tr(),
            tone: AppTone.brand,
          ),
          selected: state.relationship?.id == r.id,
          onTap: () => cubit.chooseSupplier(r),
        ),
      for (final r in blocked)
        _ChoiceRow(
          icon: Icons.storefront_outlined,
          title: r.label(locale),
          subtitle: 'new_order.block_${state.blockFor(r, mode)?.name ?? 'noRelationship'}'.tr(),
          trailing: AppBadge('new_order.not_ready'.tr(), tone: AppTone.neutral),
          selected: false,
          onTap: null,
        ),
      if (state.relationship != null) _SelectionNotes(state: state),
    ];
  }

  // ---------------------------------------------------------- ③ contract

  List<Widget> _contractSection(BuildContext context, NewOrderState state, PurchaseMode mode) {
    final cubit = context.read<NewOrderCubit>();
    final locale = context.locale.toString();
    final contracts = state.contractsFor(state.relationship!, mode);

    return [
      _SectionTitle(number: 3, title: 'new_order.contract_title'.tr()),
      for (final c in contracts)
        _ChoiceRow(
          icon: Icons.description_outlined,
          title: c.label(locale),
          subtitle: 'contract.type_${c.raw['contract_type'] ?? ''}'.tr(),
          trailing: StatusChip(status: c.status),
          selected: state.contractId == c.id,
          onTap: () => cubit.chooseContract(c.id),
        ),
      if (!state.contractRequired)
        _ChoiceRow(
          icon: Icons.payments_outlined,
          title: mode == PurchaseMode.cash
              ? 'new_order.without_contract'.tr()
              : 'new_order.under_framework'.tr(),
          subtitle: contracts.isEmpty
              ? (mode == PurchaseMode.cash
                    ? 'new_order.no_matching_contract'.tr()
                    : 'new_order.under_framework_hint'.tr())
              : 'new_order.without_contract_hint'.tr(),
          selected: state.contractId == null,
          onTap: () => cubit.chooseContract(null),
        ),
      if (state.contractRequired && contracts.isEmpty)
        AppBanner(message: 'new_order.block_noCreditContract'.tr(), tone: AppTone.warning),
    ];
  }

  // ------------------------------------------------- ④ items & quantities

  List<Widget> _itemsSection(BuildContext context, NewOrderState state) {
    final cubit = context.read<NewOrderCubit>();
    final locale = context.locale.toString();
    if (state.contractRequired && state.contractId == null) return const [];

    return [
      _SectionTitle(number: 4, title: 'new_order.items_title'.tr()),
      AppCard(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.cardPadding,
          AppTokens.cardPadding,
          AppTokens.cardPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IdPicker<LookupItem>(
              label: 'order.payment_term'.tr(),
              value: state.paymentTermId,
              items: state.termsFor(state.mode!),
              idOf: (t) => t.id,
              labelOf: (t) => t.label(locale),
              required: false,
              onChanged: cubit.choosePaymentTerm,
            ),
            AppField(
              controller: _notes,
              label: 'order.notes'.tr(),
              hint: 'common.optional'.tr(),
              textInputAction: TextInputAction.done,
              serverError: state.action.fieldError('notes'),
            ),
          ],
        ),
      ),
      // A refused submit: where to go next, and every rule that names no line.
      if (state.actionCode.isNotEmpty) ...[
        const SizedBox(height: AppTokens.space3),
        GuidedRefusal(code: state.actionCode),
      ],
      if (state.ruleErrors.isNotEmpty)
        AppBanner(
          tone: AppTone.danger,
          icon: Icons.rule_rounded,
          title: 'order.submit_blocked'.tr(),
          message: [
            for (final e in state.ruleErrors) '• ${e.message.isNotEmpty ? e.message : e.code}',
          ].join('\n'),
        ),
      const SizedBox(height: AppTokens.space3),
      if (state.itemsLoading && state.items.isEmpty)
        const Skeleton(height: 120)
      else if (state.items.isEmpty)
        AppCard(
          child: Column(
            children: [
              const AppIconCircle(Icons.inventory_2_outlined, tone: AppTone.neutral),
              const SizedBox(height: AppTokens.space3),
              Text(
                'new_order.no_items'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        )
      else
        for (final item in state.items)
          _ItemCard(
            key: ValueKey(item.skuId),
            item: item,
            qty: state.quantities[item.skuId] ?? 0,
            error: state.lineErrors[item.skuId],
          ),
    ];
  }
}

/// «موردون مؤهلون · عقود متاحة · منتجات قابلة للطلب».
class _Counters extends StatelessWidget {
  final NewOrderState state;

  const _Counters({required this.state});

  @override
  Widget build(BuildContext context) {
    final mode = state.mode;
    final relationship = state.relationship;
    final suppliers = mode == null ? 0 : state.eligibleFor(mode).length;
    final contracts = mode == null || relationship == null
        ? 0
        : state.contractsFor(relationship, mode).length;
    final products = state.items.where((i) => i.orderable).length;
    return Row(
      children: [
        Expanded(
          child: AppStatTile(label: 'new_order.count_suppliers'.tr(), value: '$suppliers'),
        ),
        const SizedBox(width: AppTokens.space2),
        Expanded(
          child: AppStatTile(
            label: 'new_order.count_contracts'.tr(),
            value: '$contracts',
            tone: AppTone.neutral,
          ),
        ),
        const SizedBox(width: AppTokens.space2),
        Expanded(
          child: AppStatTile(
            label: 'new_order.count_products'.tr(),
            value: '$products',
            tone: AppTone.neutral,
          ),
        ),
      ],
    );
  }
}

/// «توجد ملاحظات على هذا الاختيار»: what governs the order and where its
/// prices come from — the website's diagnostics, in one line each.
class _SelectionNotes extends StatelessWidget {
  final NewOrderState state;

  const _SelectionNotes({required this.state});

  @override
  Widget build(BuildContext context) {
    final relationship = state.relationship!;
    final framework = state.frameworkOf(relationship);
    final hasPricingContract = state.contractId != null;
    final notes = [
      if (framework != null)
        'new_order.note_framework'.tr(
          namedArgs: {'code': framework.code.isNotEmpty ? framework.code : '#${framework.id}'},
        ),
      if (!hasPricingContract) 'new_order.note_no_pricing_contract'.tr(),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    return AppBanner(
      tone: AppTone.info,
      icon: Icons.info_outline_rounded,
      title: 'new_order.notes_title'.tr(),
      message: notes.join('\n'),
    );
  }
}

/// One SKU: rules, stock, price and where it comes from, and the quantity.
class _ItemCard extends StatefulWidget {
  final OrderEntryItem item;
  final double qty;
  final String? error;

  const _ItemCard({super.key, required this.item, required this.qty, required this.error});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final _controller = TextEditingController(text: _format(widget.qty));

  static String _format(double v) =>
      v <= 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(3));

  @override
  void didUpdateWidget(_ItemCard old) {
    super.didUpdateWidget(old);
    // The stepper (or a reload) changed it: show it, unless it is what the
    // user is typing already.
    final typed = double.tryParse(_controller.text.trim()) ?? 0;
    if ((typed - widget.qty).abs() > 1e-9) _controller.text = _format(widget.qty);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _sourceLabel(String source) {
    if (source.isEmpty) return '';
    final key = 'new_order.price_source_$source';
    final translated = key.tr();
    return translated == key ? source : translated;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewOrderCubit>();
    final item = widget.item;
    final sku = item.sku;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final currency = item.currencyCode.isEmpty ? 'SAR' : item.currencyCode;
    final small = theme.textTheme.bodySmall?.copyWith(color: t.textSecondary);
    final source = _sourceLabel(item.priceSource);

    return Opacity(
      opacity: item.orderable ? 1 : 0.6,
      child: AppCard.item(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName(locale), style: theme.textTheme.titleSmall),
                      if (sku.skuCode.isNotEmpty)
                        Text(sku.skuCode, style: small, textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      item.finalPrice,
                      currency: currency,
                      style: AppType.ledger(t.textPrimary),
                    ),
                    if (source.isNotEmpty) Text(source, style: small),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space2),
            Wrap(
              spacing: AppTokens.space2,
              runSpacing: AppTokens.space1,
              children: [
                if (sku.minOrderQty > 0 || sku.orderStepQty > 0)
                  AppBadge(
                    'new_order.rules'.tr(
                      namedArgs: {
                        'min': _format(sku.minOrderQty).isEmpty ? '—' : _format(sku.minOrderQty),
                        'step': _format(sku.orderStepQty).isEmpty ? '—' : _format(sku.orderStepQty),
                      },
                    ),
                    tone: AppTone.neutral,
                    icon: Icons.straighten_rounded,
                  ),
                if (item.availableQty != null)
                  AppBadge(
                    'new_order.available_qty'.tr(
                      namedArgs: {
                        'qty': _format(item.availableQty!).isEmpty
                            ? '0'
                            : _format(item.availableQty!),
                      },
                    ),
                    tone: (item.availableQty ?? 0) > 0 ? AppTone.brand : AppTone.warning,
                    icon: Icons.inventory_2_outlined,
                  ),
                if (!item.orderable)
                  AppBadge(
                    'new_order.no_price'.tr(),
                    tone: AppTone.danger,
                    icon: Icons.block_rounded,
                  ),
              ],
            ),
            if (item.orderable) ...[
              const SizedBox(height: AppTokens.space3),
              Row(
                children: [
                  AppCircleButton(
                    icon: Icons.remove_rounded,
                    onPressed: () => cubit.nudge(item, -1),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: 'order.qty'.tr(),
                        isDense: true,
                        suffixText: sku.unitLabel(locale),
                      ),
                      onChanged: (value) =>
                          cubit.setQuantity(item.skuId, double.tryParse(value.trim()) ?? 0),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  AppCircleButton(
                    icon: Icons.add_rounded,
                    // At the available stock there is nothing more to add.
                    onPressed: item.maxQty != null && widget.qty >= item.maxQty!
                        ? null
                        : () => cubit.nudge(item, 1),
                  ),
                ],
              ),
              if (widget.qty > 0) ...[
                const SizedBox(height: AppTokens.space2),
                Row(
                  children: [
                    Expanded(child: Text('new_order.line_total'.tr(), style: small)),
                    MoneyText(widget.qty * item.finalPrice, currency: currency),
                  ],
                ),
              ],
            ],
            if (widget.error != null) ...[
              const SizedBox(height: AppTokens.space2),
              Text(widget.error!, style: theme.textTheme.bodySmall?.copyWith(color: t.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A numbered section heading — «١ نمط الشراء وفرع التسليم».
class _SectionTitle extends StatelessWidget {
  final int number;
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.number, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppTokens.space5, bottom: AppTokens.space3),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.primaryTint, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.primary),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A selectable row: icon disc, title, hint, an optional badge, and the
/// selection mark. Disabled (no [onTap]) rows are dimmed but stay readable.
class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Opacity(
      opacity: onTap == null && !selected ? 0.6 : 1,
      child: AppCard.item(
        onTap: onTap,
        child: Row(
          children: [
            AppIconCircle(icon, tone: selected ? AppTone.brand : AppTone.neutral),
            const SizedBox(width: AppTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppTokens.space2), trailing!],
            const SizedBox(width: AppTokens.space2),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? t.primary : t.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}
