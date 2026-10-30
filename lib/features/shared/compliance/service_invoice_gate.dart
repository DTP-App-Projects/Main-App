import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../data/repositories/compliance_repository.dart';

/// The two `422` codes a new order gets while a platform service invoice is
/// overdue. The server's `message` is shown as sent; these only pick the
/// guidance around it.
abstract final class ServiceInvoiceCodes {
  /// The caller's own organization is overdue.
  static const overdue = 'service_invoice_overdue';

  /// The other party (the supplier) is overdue.
  static const overdueSupplier = 'service_invoice_overdue_supplier';
}

/// The order screens' pre-check: `true` while this organization has an
/// overdue service invoice (`new_orders_restricted`), so the submit is
/// disabled before the server refuses it. One read when the screen opens;
/// the server's `422` stays the source of truth, and a failed read never
/// blocks anything.
class OrdersRestrictionCubit extends Cubit<bool> {
  final ComplianceRepository _repo;

  OrdersRestrictionCubit(this._repo) : super(false);

  Future<void> load() async {
    // `limit: 1` — only the header is wanted, not the invoice rows.
    final result = await _repo.serviceInvoices(limit: 1);
    if (isClosed) return;
    if (result case Ok(:final data)) emit(data.newOrdersRestricted);
  }
}

/// The red «لديك فاتورة خدمة متأخرة» banner. By default its button opens the
/// service invoices screen; that screen passes its own (scroll to the row).
class ServiceInvoiceOverdueBanner extends StatelessWidget {
  final String? actionLabel;
  final VoidCallback? onAction;

  const ServiceInvoiceOverdueBanner({super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => AppBanner(
    key: const Key('service_invoice_overdue_banner'),
    tone: AppTone.danger,
    icon: Icons.receipt_long_outlined,
    title: 'fees.overdue_title'.tr(),
    message: 'fees.overdue_banner'.tr(),
    action: Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppButton.text(
        label: actionLabel ?? 'fees.open_service_invoices'.tr(),
        height: 36,
        onPressed: onAction ?? () => context.push(AppRoutes.serviceInvoices),
      ),
    ),
  );
}
