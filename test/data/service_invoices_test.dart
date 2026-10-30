import 'package:digital_trade_portal/core/error/api_failure_ui.dart';
import 'package:digital_trade_portal/core/i18n/money.dart';
import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:digital_trade_portal/data/repositories/orders_repository.dart';
import 'package:digital_trade_portal/features/shared/compliance/service_invoice_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// `GET /service_invoices` as documented for the platform-fee release
/// (2026-10-17): money as 2-decimal strings, the extension progress, and the
/// overdue flags.
const _serviceInvoices = {
  'free_period': {
    'account_activated_at': '2026-10-01 09:12:00',
    'free_until': '2027-01-01 09:12:00',
    'in_free_period': true,
    'months': 3,
    'extension': {
      'invoices': 7,
      'invoices_target': 20,
      'gmv_ex_vat': '38250.00',
      'gmv_target': '100000.00',
      'criterion_met': null,
      'reviewed': false,
      'extended': false,
    },
  },
  'platform_fee_rate': 1.0,
  'new_orders_restricted': true,
  'wallet_enabled': false,
  'commission_on_goods_invoices': false,
  'service_invoices': {
    'data': [
      {
        'id': 12,
        'invoice_no': 'SINV-2026-000012',
        'kind': 'platform_fee',
        'kind_label': 'رسوم المنصة',
        'status': 'issued',
        'grand_total': '382.50',
        'currency_code': 'SAR',
        'issued_at': '2026-11-01 00:05:00',
        'period': '2026-10',
        'due_at': '2026-11-08 00:05:00',
        'is_overdue': true,
      },
      {
        'id': 3,
        'invoice_no': 'SINV-2026-000003',
        'kind': 'subscription',
        'status': 'paid',
        'grand_total': '115.00',
        'issued_at': '2026-09-01 00:00:00',
      },
    ],
    'current_page': 1,
    'last_page': 2,
    'total': 3,
  },
};

void main() {
  setUp(() async => useFakeStorage());

  group('Money.parse', () {
    test('reads 2-decimal strings exactly, without a double', () {
      expect(Money.parse('38250.00').minorUnits, 3825000);
      expect(Money.parse('0.10').minorUnits + Money.parse('0.20').minorUnits, 30);
      expect(Money.parse('100000').minorUnits, 10000000);
      expect(Money.parse('-12.5').minorUnits, -1250);
      expect(Money.parse('1,250.75').minorUnits, 125075);
      expect(Money.parse(42.5).minorUnits, 4250);
      expect(Money.parse(null).minorUnits, 0);
      expect(Money.parse('abc').minorUnits, 0);
    });
  });

  group('service invoices', () {
    test('reads the free-period extension, the fee rate and the overdue flags', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(_serviceInvoices));
      final result = await ComplianceRepository(client).serviceInvoices();

      expect(adapter.requests.single.queryParameters, {'page': 1, 'limit': 20});
      final data = (result as Ok).data;
      expect(data.platformFeeRate, 1.0);
      expect(data.platformFeeRateLabel, '1');
      expect(data.newOrdersRestricted, isTrue);
      expect(data.hasMore, isTrue);
      expect(data.total, 3);

      final ext = data.freePeriod.extension;
      expect(ext.invoices, 7);
      expect(ext.invoicesTarget, 20);
      expect(ext.gmvExVat.minorUnits, 3825000);
      expect(ext.gmvTarget.minorUnits, 10000000);
      expect(ext.criterionMet, isNull);
      expect(ext.pendingExtension, isFalse);
      expect(ext.invoicesProgress, closeTo(0.35, 1e-9));
      expect(ext.gmvProgress, closeTo(0.3825, 1e-9));

      final fee = data.invoices.first;
      expect(fee.kind, 'platform_fee');
      expect(fee.kindLabel, 'رسوم المنصة');
      expect(fee.period, '2026-10');
      expect(fee.total.minorUnits, 38250);
      expect(fee.isOverdue, isTrue);
      // `Y-m-d H:i:s` is Riyadh wall time.
      expect(fee.dueAt, DateTime.utc(2026, 11, 7, 21, 5));
      expect(data.firstOverdue?.id, 12);

      // Older invoices: no period, no due date, not overdue.
      final old = data.invoices.last;
      expect(old.period, isEmpty);
      expect(old.dueAt, isNull);
      expect(old.isOverdue, isFalse);
    });

    test('a met criterion awaits the review until it is reviewed', () async {
      Future<bool> pendingFor(Map<String, Object?> extension) async {
        final (client, _) = clientWith(
          FakeAdapter.json({
            ..._serviceInvoices,
            'free_period': {'in_free_period': true, 'extension': extension},
          }),
        );
        final data = ((await ComplianceRepository(client).serviceInvoices()) as Ok).data;
        return data.freePeriod.extension.pendingExtension;
      }

      const met = {'invoices': 20, 'invoices_target': 20, 'criterion_met': 'invoices'};
      expect(await pendingFor(met), isTrue);
      expect(await pendingFor({...met, 'reviewed': true}), isFalse);
      expect(await pendingFor({...met, 'extended': true}), isFalse);
    });

    test('an older server without the new keys reads as unrestricted', () async {
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'free_period': {'in_free_period': true, 'months': 6},
          'service_invoices': {'data': [], 'current_page': 1, 'last_page': 1},
        }),
      );
      final data = ((await ComplianceRepository(client).serviceInvoices()) as Ok).data;
      expect(data.newOrdersRestricted, isFalse);
      expect(data.freePeriod.extension.hasTargets, isFalse);
    });

    test('the order screens read only the header (limit 1)', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(_serviceInvoices));
      final cubit = OrdersRestrictionCubit(ComplianceRepository(client));
      await cubit.load();
      expect(cubit.state, isTrue);
      expect(adapter.requests.single.queryParameters['limit'], 1);
      await cubit.close();
    });

    test('a failed read never blocks the order', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {'msg': 'server_error'}, status: 500));
      final cubit = OrdersRestrictionCubit(ComplianceRepository(client));
      await cubit.load();
      expect(cubit.state, isFalse);
      await cubit.close();
    });
  });

  group('order submit refused for an overdue service invoice', () {
    test('our own: the code to branch on and the server sentence as sent', () async {
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'msg': 'service_invoice_overdue',
          'message': 'لا يمكن إنشاء أوامر جديدة: فاتورة خدمة المنصة متأخرة أكثر من 7 أيام.',
          'service_invoice_no': 'SINV-2026-000012',
          'due_at': '2026-11-08',
        }, status: 422),
      );
      final result = await OrdersRepository(client).submitDraft(9);

      expect(result.failureCode, ServiceInvoiceCodes.overdue);
      expect(
        result.failureMessage,
        'لا يمكن إنشاء أوامر جديدة: فاتورة خدمة المنصة متأخرة أكثر من 7 أيام.',
      );
      expect((result as Failed).details?['service_invoice_no'], 'SINV-2026-000012');
    });

    test('the supplier: its own code and sentence', () async {
      final (client, _) = clientWith(
        FakeAdapter.json(const {
          'msg': 'service_invoice_overdue_supplier',
          'message':
              'لا يمكن إنشاء أوامر جديدة مع هذا المورد حاليًا: لديه فاتورة خدمة منصة متأخرة.',
        }, status: 422),
      );
      final result = await OrdersRepository(client).submitDraft(9);

      expect(result.failureCode, ServiceInvoiceCodes.overdueSupplier);
      expect(
        result.failureMessage,
        'لا يمكن إنشاء أوامر جديدة مع هذا المورد حاليًا: لديه فاتورة خدمة منصة متأخرة.',
      );
    });
  });
}
