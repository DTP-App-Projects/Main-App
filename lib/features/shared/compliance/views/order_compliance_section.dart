import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../data/models/trade/purchase_order.dart';
import '../compliance_widgets.dart';
import '../service_invoice_gate.dart';
import 'evidence_views.dart';

/// The compliance half of an order: supply model, hold, the document chain,
/// and the evidence actions. Sits under the order's header card.
class OrderComplianceSection extends StatelessWidget {
  final PurchaseOrder order;

  /// The last failed action's stable code, for the guided refusals.
  final String actionCode;

  /// Reloads the order after a consignment-terms change.
  final Future<void> Function() onChanged;

  const OrderComplianceSection({
    super.key,
    required this.order,
    required this.actionCode,
    required this.onChanged,
  });

  static const _beforeAcceptance = {'draft', 'submitted', 'under_review', 'pending'};

  @override
  Widget build(BuildContext context) {
    final c = order.compliance;
    final isTrader = order.viewerRole == 'trader';
    final isConsignment = c.supplyModel == 'consignment';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuidedRefusal(code: actionCode),
        if (c.supplyModel.isNotEmpty || c.isHeld) ...[
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: AppTokens.space2,
            runSpacing: AppTokens.space2,
            children: [
              if (c.supplyModelLabel.isNotEmpty) AppBadge(c.supplyModelLabel, tone: AppTone.neutral),
              if (c.specStatusLabel.isNotEmpty) AppBadge(c.specStatusLabel, tone: AppTone.info),
              if (c.isHeld) const HeldBadge(),
            ],
          ),
        ],
        if (c.isHeld) ...[
          const SizedBox(height: AppTokens.space2),
          AppBanner(message: 'compliance.held_hint'.tr(), tone: AppTone.warning),
        ],
        ChainStrip(
          frameworkAgreement: c.frameworkAgreement,
          quotation: c.quotation,
          purchaseOrderCode: order.code,
          creditAcknowledgment: c.creditAcknowledgment,
          showAck: c.supplyModel == 'credit',
        ),
        AppSectionLabel('compliance.documents'.tr()),
        Wrap(
          spacing: AppTokens.space2,
          runSpacing: AppTokens.space2,
          children: [
            if (isConsignment && _beforeAcceptance.contains(order.status))
              AppButton.outline(
                label: 'consignment.terms_title'.tr(),
                icon: Icons.tune_rounded,
                expand: false,
                height: 44,
                onPressed: () async {
                  if (await showConsignmentTermsSheet(context, order.id)) await onChanged();
                },
              ),
            if (isTrader)
              AppButton.outline(
                label: 'rn.new'.tr(),
                icon: Icons.assignment_return_outlined,
                expand: false,
                height: 44,
                onPressed: () => context.push(AppRoutes.returnNoteNewFor(order.id)),
              ),
            DisputePackButton(scopeType: 'purchase_order', scopeId: order.id),
          ],
        ),
      ],
    );
  }
}

/// The refusals the spec wants explained, not just reported. The server's
/// own sentence is already on screen; this adds where to go next.
/// Matched on the stable code only, never on the text. Also under the draft:
/// the first order between two parties needs the framework agreement signed.
class GuidedRefusal extends StatelessWidget {
  final String code;

  const GuidedRefusal({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) return const SizedBox.shrink();
    // Our own overdue service invoice: pay it, then submit the kept draft
    // again. The supplier-side code needs nothing more than its sentence.
    if (code == ServiceInvoiceCodes.overdue) return const ServiceInvoiceOverdueBanner();
    if (code.contains('framework_agreement')) {
      return AppBanner(
        tone: AppTone.warning,
        title: 'compliance.need_fa_title'.tr(),
        message: 'compliance.need_fa_body'.tr(),
        action: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            label: 'compliance.open_fa'.tr(),
            height: 36,
            onPressed: () => context.push(AppRoutes.agreementsFor(AgreementKind.framework)),
          ),
        ),
      );
    }
    if (code.contains('supply_suspended') || code.contains('supply_status')) {
      return AppBanner(
        tone: AppTone.warning,
        title: 'compliance.supply_suspended_title'.tr(),
        message: 'compliance.supply_suspended_body'.tr(),
      );
    }
    if (code.contains('credit_limit')) {
      return AppBanner(
        tone: AppTone.warning,
        title: 'compliance.credit_limit_title'.tr(),
        message: 'compliance.credit_limit_body'.tr(),
      );
    }
    return const SizedBox.shrink();
  }
}
