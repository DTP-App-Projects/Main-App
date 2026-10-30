import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/supplier_summary.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';

/// A relationship's `supply_status` and what the supplier can do about it:
/// restore supply once the trader has settled, or freeze the evidence.
class RelationshipSupplyPanel extends StatelessWidget {
  final int relationshipId;

  const RelationshipSupplyPanel({super.key, required this.relationshipId});

  @override
  Widget build(BuildContext context) {
    final repo = getIt<ComplianceRepository>();
    return BlocProvider(
      create: (_) => DetailCubit<BusinessRelationship>(() => repo.relationship(relationshipId))..load(),
      child: BlocBuilder<DetailCubit<BusinessRelationship>, DetailState<BusinessRelationship>>(
        builder: (context, state) {
          final cubit = context.read<DetailCubit<BusinessRelationship>>();
          final r = state.data;
          if (r == null) return const SizedBox.shrink();
          final busy = state.action.isSubmitting;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DetailRow(label: 'rr.supply_status'.tr(), value: SupplyStatusPill(status: r.supplyStatus)),
                    if (r.requestNo.isNotEmpty)
                      DetailRow(label: 'rr.title'.tr(), value: Text(r.requestNo, textDirection: TextDirection.ltr)),
                    if (!r.isSupplyActive) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text('compliance.supply_hint_${r.supplyStatus}'.tr(), style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppTokens.space3),
                      FormMessage(message: state.action.message, success: state.action.isSuccess),
                      AppButton.primary(
                        label: 'late.restore_supply'.tr(),
                        height: 48,
                        busy: busy,
                        onPressed: busy
                            ? null
                            : () => cubit.run(() => repo.restoreSupply(relationshipId), successMessage: 'late.restored'.tr()),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space3),
                    // After a restore the restore button is gone; its answer
                    // sits above the remaining action instead.
                    if (r.isSupplyActive) FormMessage(message: state.action.message, success: state.action.isSuccess),
                    DisputePackButton(scopeType: 'relationship', scopeId: relationshipId),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),
            ],
          );
        },
      ),
    );
  }
}
