import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/trade/supplier_summary.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../shared/compliance/views/relationship_request_sheet.dart';
import '../view_models/traders_directory_cubit.dart';

/// «دليل التجار» — where a supplier starts a relationship (guide Part 6.1).
class TradersDirectoryView extends StatelessWidget {
  const TradersDirectoryView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => TradersDirectoryCubit(getIt<SupplierRepository>(), getIt<CatalogRepository>())..load(),
        child: const _DirectoryBody(),
      );
}

class _DirectoryBody extends StatefulWidget {
  const _DirectoryBody();

  @override
  State<_DirectoryBody> createState() => _DirectoryBodyState();
}

class _DirectoryBodyState extends State<_DirectoryBody> {
  /// A keystroke is never a request.
  static const _debounce = Duration(milliseconds: 400);

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
    _timer = Timer(_debounce, () => context.read<TradersDirectoryCubit>().setSearch(value));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TradersDirectoryCubit>();
    final state = cubit.state;

    return Scaffold(
      appBar: AppBar(title: Text('traders.title'.tr())),
      body: Column(
        children: [
          AppSearchField(
            controller: _search,
            onChanged: _onChanged,
            onSubmitted: cubit.setSearch,
            hint: 'traders.search_hint'.tr(),
          ),
          if ((state.action.message ?? '').isNotEmpty)
            AppBanner(
              message: state.action.message!,
              tone: AppTone.danger,
              margin: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.gutter,
                0,
                AppTokens.gutter,
                AppTokens.space2,
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.loading && state.traders.isEmpty) return const ListSkeleton(rows: 5);
                if (state.offline && state.traders.isEmpty) return AppOfflineState(onRetry: cubit.load);
                if (state.errorMessage != null && state.traders.isEmpty) {
                  return AppErrorState(
                    message: state.errorMessage!.isEmpty ? 'errors.generic'.tr() : state.errorMessage!,
                    onRetry: cubit.load,
                  );
                }
                if (state.traders.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'traders.empty'.tr(),
                    body: state.search.isEmpty ? null : 'lookup.empty_search'.tr(),
                  );
                }
                return RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView.builder(
                    padding: AppTokens.pagePadding,
                    itemCount: state.traders.length,
                    itemBuilder: (context, index) => _TraderCard(trader: state.traders[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TraderCard extends StatelessWidget {
  final TraderSummary trader;

  const _TraderCard({required this.trader});

  Future<void> _request(BuildContext context) async {
    final cubit = context.read<TradersDirectoryCubit>();
    final draft = await showRelationshipRequestSheet(context, counterpartyName: trader.displayName);
    if (draft == null || !context.mounted) return;
    final ok = await cubit.requestRelationship(trader, draft);
    if (!ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('supplier.request_sent_toast_trader'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requesting = context.select<TradersDirectoryCubit, bool>(
      (c) => c.state.requestingId == trader.id,
    );

    // The same three readings the supplier list shows a trader.
    final Widget badge;
    if (trader.isRequestPending) {
      badge = AppBadge('supplier.request_sent'.tr(), tone: AppTone.info, icon: Icons.hourglass_top_rounded);
    } else if (trader.canRequestAgain) {
      badge = AppBadge('supplier.request_declined'.tr(), tone: AppTone.warning, icon: Icons.replay_rounded);
    } else {
      badge = StatusChip(status: trader.relationshipStatus);
    }

    return AppCard.item(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppInitialAvatar(name: trader.displayName),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Text(
                  trader.displayName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              badge,
            ],
          ),
          if (trader.canRequest) ...[
            const SizedBox(height: AppTokens.space3),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton.outline(
                label: trader.canRequestAgain
                    ? 'supplier.request_again'.tr()
                    : 'supplier.request_relationship'.tr(),
                icon: Icons.handshake_outlined,
                height: 40,
                busy: requesting,
                onPressed: requesting ? null : () => _request(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
