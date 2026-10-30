import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/repositories/contracts_repository.dart';

enum _Tab { shipments, salesReports, stockCounts }

/// «التوريد الأماني» (guide Part 14.2): consignment shipments, sales reports
/// and stock counts, read side by side. The custody ledger has its own page.
class ConsignmentView extends StatefulWidget {
  const ConsignmentView({super.key});

  @override
  State<ConsignmentView> createState() => _ConsignmentViewState();
}

/// One row, whatever the document: code, when, status.
typedef _Row = ({String code, DateTime? date, String status, String detail});

class _ConsignmentViewState extends State<ConsignmentView> {
  _Tab _tab = _Tab.shipments;
  late Future<ApiResult<List<_Row>>> _future = _load();

  Future<ApiResult<List<_Row>>> _load() async {
    final repo = getIt<ContractsRepository>();
    switch (_tab) {
      case _Tab.shipments:
        final r = await repo.consignmentShipments();
        return _map(r, (s) => (
              code: s.code.isEmpty ? '#${s.id}' : s.code,
              date: s.createdAt,
              status: s.status,
              detail: 'consignment.lines'.tr(namedArgs: {'count': '${s.lines.length}'}),
            ));
      case _Tab.salesReports:
        final r = await repo.salesReports();
        return _map(r, (s) => (
              code: '#${s.id}',
              date: s.periodEnd,
              status: s.status,
              detail: 'consignment.gross_sales'.tr(namedArgs: {'amount': s.grossSales.toStringAsFixed(2)}),
            ));
      case _Tab.stockCounts:
        final r = await repo.stockCounts();
        return _map(r, (s) => (
              code: '#${s.id}',
              date: s.countDate,
              status: s.status,
              detail: s.countType.isEmpty ? '' : 'consignment.count_${s.countType}'.tr(),
            ));
    }
  }

  /// Rows on success; otherwise the failure's own message, for the retry.
  String? _error;

  ApiResult<List<_Row>> _map<T>(ApiResult<Paged<T>> result, _Row Function(T) row) {
    if (result case Ok(:final data)) {
      _error = null;
      return Ok([for (final item in data.items) row(item)]);
    }
    _error = result.failureMessage ?? 'errors.generic'.tr();
    return const Ok([]);
  }

  void _select(_Tab tab) => setState(() {
        _tab = tab;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('consignment.title'.tr())),
      body: Column(
        children: [
          AppFilterBar(
            options: [
              for (final tab in _Tab.values)
                AppFilterOption(
                  label: 'consignment.tab_${tab.name}'.tr(),
                  selected: _tab == tab,
                  onTap: () => _select(tab),
                ),
            ],
          ),
          Expanded(
            child: FutureBuilder<ApiResult<List<_Row>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const ListSkeleton(rows: 4);
                final rows = snapshot.data?.dataOrNull ?? const <_Row>[];
                if (_error != null) return AppErrorState(message: _error!, onRetry: () => _select(_tab));
                if (rows.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.warehouse_outlined,
                    title: 'consignment.empty'.tr(),
                    body: 'consignment.empty_hint'.tr(),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _select(_tab),
                  child: ListView(
                    padding: AppTokens.pagePadding,
                    children: [
                      for (final row in rows)
                        AppCard.item(
                          child: Row(
                            children: [
                              const AppIconCircle(Icons.inventory_2_outlined),
                              const SizedBox(width: AppTokens.space3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row.code, style: theme.textTheme.titleSmall, textDirection: TextDirection.ltr),
                                    Text(
                                      [AppDates.date(row.date, locale), row.detail].where((s) => s.isNotEmpty).join(' · '),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              StatusChip(status: row.status),
                            ],
                          ),
                        ),
                    ],
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
