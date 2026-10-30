import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/lookups/lookup_item.dart';
import '../../../data/models/trade/pricing.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../view_models/supplier_cubits.dart';

/// Price lists. A list's **scope** decides who it applies to, and every scope
/// except `default` points at something — a relationship, a contract, an
/// organization, a campaign.
class PriceListsView extends StatelessWidget {
  const PriceListsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PriceListsCubit(getIt<SupplierRepository>())..load(),
        child: const _PriceListsBody(),
      );
}

class _PriceListsBody extends StatelessWidget {
  const _PriceListsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PriceListsCubit>();
    final locale = context.locale.toString();

    return Scaffold(
      appBar: AppBar(title: Text('pricing.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openListEditor(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text('pricing.add_list'.tr()),
      ),
      body: PagedListView<PriceList>(
        state: cubit.state,
        onRefresh: cubit.refresh,
        onLoadMore: cubit.loadMore,
        emptyIcon: Icons.sell_outlined,
        emptyTitle: 'pricing.empty'.tr(),
        emptyBody: 'pricing.empty_hint'.tr(),
        emptyActionLabel: 'pricing.add_list'.tr(),
        onEmptyAction: () => _openListEditor(context, null),
        itemBuilder: (list) => AppCard.item(
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
                children: [
                  const AppIconCircle(Icons.sell_outlined, size: 40),
                  const SizedBox(width: AppTokens.space3),
                  Expanded(
                    child: Text(
                      list.displayName(locale),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  StatusChip(status: list.status),
                ],
              ),
              const SizedBox(height: AppTokens.space2),
              DetailRow(
                label: 'pricing.scope'.tr(),
                value: Text('pricing.scope_${list.scopeType}'.tr()),
              ),
              if (list.currencyCode.isNotEmpty)
                DetailRow(
                  label: 'bank.currency'.tr(),
                  value: Text(list.currencyCode, textDirection: TextDirection.ltr),
                ),
              Row(
                children: [
                  Flexible(
                    child: AppButton.text(
                      label: 'pricing.edit_list'.tr(),
                      icon: Icons.edit_outlined,
                      onPressed: () => _openListEditor(context, list),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: AppButton.text(
                      label: 'pricing.add_item'.tr(),
                      icon: Icons.add_rounded,
                      onPressed: () => _openItemEditor(context, list),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openListEditor(BuildContext context, PriceList? list) {
    final cubit = context.read<PriceListsCubit>();
    return showAppSheet<void>(
      context: context,
      title: list == null ? 'pricing.add_list'.tr() : 'pricing.edit_list'.tr(),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _PriceListForm(list: list),
      ),
    );
  }

  Future<void> _openItemEditor(BuildContext context, PriceList list) {
    final cubit = context.read<PriceListsCubit>();
    return showAppSheet<void>(
      context: context,
      title: 'pricing.add_item'.tr(),
      subtitle: list.displayName(context.locale.toString()),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _PriceItemForm(list: list),
      ),
    );
  }
}

class _PriceListForm extends StatefulWidget {
  final PriceList? list;

  const _PriceListForm({required this.list});

  @override
  State<_PriceListForm> createState() => _PriceListFormState();
}

class _PriceListFormState extends State<_PriceListForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameAr = TextEditingController(text: widget.list?.nameAr ?? '');
  late final _nameEn = TextEditingController(text: widget.list?.nameEn ?? '');
  late final _currency = TextEditingController(
    text: widget.list?.currencyCode.isNotEmpty == true ? widget.list!.currencyCode : 'SAR',
  );

  late String _scope = widget.list?.scopeType.isNotEmpty == true
      ? widget.list!.scopeType
      : 'default';
  LookupItem? _scopeTarget;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // One of the two names is required, and the server rejects a scoped list
    // with no target — both checked here so neither 400 comes back.
    if (_nameAr.text.trim().isEmpty && _nameEn.text.trim().isEmpty) {
      setState(() => _error = 'errors.price_list_name_required'.tr());
      return;
    }
    final scopeId = _scopeTarget?.id ?? widget.list?.scopeId;
    if (PriceList.scopeNeedsId(_scope) && scopeId == null) {
      setState(() => _error = 'errors.scope_id_required_for_selected_scope'.tr());
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<PriceListsCubit>().save(
          priceListId: widget.list?.id,
          scopeType: _scope,
          scopeId: PriceList.scopeNeedsId(_scope) ? scopeId : null,
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim(),
          currencyCode: _currency.text.trim(),
          status: 'active',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  /// The lookup a scope points at. `campaign` has none, so the id is typed.
  String? get _scopeLookup => switch (_scope) {
        'relationship' => Lookup.relationships,
        'contract' => Lookup.contracts,
        'organization' => Lookup.suppliers,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.space4,
              AppTokens.space4,
              AppTokens.space4,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppField(controller: _nameAr, label: 'branch.name_ar'.tr()),
                AppField(
                  controller: _nameEn,
                  label: 'branch.name_en'.tr(),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          AppCard(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.space4,
              AppTokens.space4,
              AppTokens.space4,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CodePicker(
                  label: 'pricing.scope'.tr(),
                  value: _scope,
                  codes: PriceList.scopes,
                  labelOf: (code) => 'pricing.scope_$code'.tr(),
                  onChanged: (value) => setState(() {
                    _scope = value ?? 'default';
                    _scopeTarget = null;
                  }),
                ),
                if (_scopeLookup != null)
                  LookupField(
                    label: 'pricing.scope_target'.tr(),
                    lookup: _scopeLookup!,
                    value: _scopeTarget,
                    onChanged: (item) => setState(() => _scopeTarget = item),
                  )
                else if (PriceList.scopeNeedsId(_scope))
                  AppBanner(message: 'pricing.scope_manual_id'.tr(), tone: AppTone.warning),
                AppField(
                  controller: _currency,
                  label: 'bank.currency'.tr(),
                  maxLength: 3,
                  icon: Icons.payments_outlined,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space5),
          FormMessage(message: _error),
          SubmitButton(busy: _busy, label: 'common.save'.tr(), onPressed: _save),
        ],
      ),
    );
  }
}

class _PriceItemForm extends StatefulWidget {
  final PriceList list;

  const _PriceItemForm({required this.list});

  @override
  State<_PriceItemForm> createState() => _PriceItemFormState();
}

class _PriceItemFormState extends State<_PriceItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _minQty = TextEditingController(text: '1');
  final _maxQty = TextEditingController();
  final _unitPrice = TextEditingController();
  final _discountValue = TextEditingController();

  LookupItem? _sku;
  LookupItem? _paymentTerm;
  String? _discountType;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_minQty, _maxQty, _unitPrice, _discountValue]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sku == null) {
      setState(() => _error = 'validation.required'.tr());
      return;
    }

    final minQty = double.tryParse(_minQty.text.trim()) ?? 0;
    final maxQty = double.tryParse(_maxQty.text.trim());
    // The server refuses an inverted band; saying so here saves a round trip.
    if (maxQty != null && maxQty < minQty) {
      setState(() => _error = 'errors.max_qty_must_be_greater_than_or_equal_min_qty'.tr());
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<PriceListsCubit>().addItem(
          priceListId: widget.list.id,
          skuId: _sku!.id,
          minQty: minQty,
          maxQty: maxQty,
          unitPrice: double.tryParse(_unitPrice.text.trim()) ?? 0,
          paymentTermId: _paymentTerm?.id,
          discountType: _discountType,
          discountValue: double.tryParse(_discountValue.text.trim()),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.list.currencyCode.isEmpty ? null : widget.list.currencyCode;
    const cardPadding = EdgeInsetsDirectional.fromSTEB(
      AppTokens.space4,
      AppTokens.space4,
      AppTokens.space4,
      0,
    );

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LookupField(
                  label: 'order.pick_sku'.tr(),
                  lookup: Lookup.skus,
                  value: _sku,
                  required: true,
                  onChanged: (item) => setState(() => _sku = item),
                ),
                LookupField(
                  label: 'order.payment_term'.tr(),
                  lookup: Lookup.paymentTerms,
                  value: _paymentTerm,
                  onChanged: (item) => setState(() => _paymentTerm = item),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          AppCard(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _minQty,
                        label: 'pricing.min_qty'.tr(),
                        required: true,
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: AppValidators.required,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppField(
                        controller: _maxQty,
                        label: 'pricing.max_qty'.tr(),
                        hint: 'common.optional'.tr(),
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                AppField(
                  controller: _unitPrice,
                  label: 'pricing.unit_price'.tr(),
                  required: true,
                  suffixText: currency,
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: AppValidators.required,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          AppCard(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CodePicker(
                  label: 'pricing.discount_type'.tr(),
                  value: _discountType,
                  codes: PriceItem.discountTypes,
                  labelOf: (code) => 'pricing.discount_$code'.tr(),
                  required: false,
                  onChanged: (value) => setState(() => _discountType = value),
                ),
                if (_discountType != null)
                  AppField(
                    controller: _discountValue,
                    label: 'pricing.discount_value'.tr(),
                    suffixText: _discountType == 'percent' ? '%' : currency,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space5),
          FormMessage(message: _error),
          SubmitButton(busy: _busy, label: 'common.save'.tr(), onPressed: _save),
        ],
      ),
    );
  }
}
