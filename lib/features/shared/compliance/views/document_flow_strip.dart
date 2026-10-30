import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/deeplink/deep_link.dart';
import '../../../../core/deeplink/deep_link_router.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../data/models/trade/document_flow.dart';

/// «PO → شحنة → استلام → فاتورة → مدفوعات»: the documents around this one,
/// from `GET /document_flow/...`. Each opens the screen a push for it would
/// (same [DeepLinkRouter] table); a type with no screen is shown, not linked.
/// Nothing renders when the server sent no related documents.
class DocumentFlowStrip extends StatelessWidget {
  final DocumentFlow flow;

  /// The side the viewer is on for this document — picks the supplier's or
  /// the trader's screen for the same document.
  final Workspace? side;

  const DocumentFlowStrip({super.key, required this.flow, this.side});

  static String typeLabel(String type) {
    final key = 'flow.type_$type';
    final translated = key.tr();
    return translated == key ? type : translated;
  }

  @override
  Widget build(BuildContext context) {
    if (flow.related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('flow.title'.tr(), trailing: AppCountBadge(flow.related.length)),
        AppMenuGroup(children: [for (final doc in flow.related) _row(context, doc)]),
      ],
    );
  }

  Widget _row(BuildContext context, FlowDocument doc) {
    final path = DeepLinkRouter.pathFor(
      DeepLink(
        clickAction: doc.entityType,
        entityType: doc.entityType,
        entityId: doc.id,
        side: side,
      ),
    );
    return AppMenuRow(
      icon: _icon(doc.entityType),
      title: typeLabel(doc.entityType),
      subtitle: doc.code.isEmpty ? '#${doc.id}' : doc.code,
      trailing: doc.status.isEmpty ? null : StatusChip(status: doc.status),
      onTap: path == null ? null : () => context.push(path),
    );
  }

  static IconData _icon(String type) => switch (type) {
    'purchase_order' => Icons.receipt_long_outlined,
    'delivery_note' => Icons.local_shipping_outlined,
    'goods_receipt' => Icons.fact_check_outlined,
    'invoice' => Icons.request_quote_outlined,
    'payment_notice' || 'collection_receipt' => Icons.payments_outlined,
    'return_note' || 'credit_note' => Icons.assignment_return_outlined,
    _ => Icons.description_outlined,
  };
}
