import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../data/models/trade/purchase_order.dart';

/// The website's answer to a submit — «تم إنشاء أمر الشراء بنجاح. الرقم #…»
/// — then the order replaces the screen it was built on (Back must not offer
/// to submit it again). A failed / manual credit review still creates the
/// order, on hold: that is said before leaving, in the server's words when
/// it sent them.
Future<void> announceSubmittedOrder(
  BuildContext context,
  PurchaseOrder order,
  CreditReview? creditReview,
) async {
  final review =
      order.status == 'under_review' ||
      order.status == 'pending_review' ||
      order.creditCheckStatus == 'review' ||
      order.creditCheckStatus == 'pending';
  if (creditReview != null && creditReview.isHold) {
    await showAppConfirm(
      context,
      title: 'order.credit_hold_title'.tr(namedArgs: {'code': order.code}),
      body: creditReview.message.isNotEmpty ? creditReview.message : 'order.credit_hold_body'.tr(),
      confirmLabel: 'order.open_order'.tr(),
      cancelLabel: 'common.close'.tr(),
    );
    if (!context.mounted) return;
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          review
              ? 'order.created_review'.tr(namedArgs: {'code': order.code})
              : 'order.created'.tr(namedArgs: {'code': order.code}),
        ),
      ),
    );
  }
  context.pushReplacement(AppRoutes.orderDetailFor(order.id));
}
