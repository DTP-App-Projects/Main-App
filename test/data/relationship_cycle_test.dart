import 'package:digital_trade_portal/core/ui/form_status.dart';
import 'package:digital_trade_portal/data/models/compliance/relationship_request.dart';
import 'package:digital_trade_portal/data/models/compliance/trade_compliance.dart';
import 'package:digital_trade_portal/data/models/trade/supplier_summary.dart';
import 'package:digital_trade_portal/data/repositories/catalog_repository.dart';
import 'package:digital_trade_portal/data/repositories/supplier_repository.dart';
import 'package:digital_trade_portal/features/supplier/view_models/supplier_cubits.dart';
import 'package:digital_trade_portal/features/supplier/view_models/traders_directory_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Batch 1 of the guide audit: starting the cycle correctly (guide Part 6)
/// and the legal fixes around it.
void main() {
  setUp(() async => useFakeStorage());

  group('relationship request (guide 6.2)', () {
    test('a credit request carries model, term, limit and debt documentation', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'relationship': {'id': 6}}));

      await CatalogRepository(client).requestRelationship(
        counterpartyOrganizationId: 23,
        requestedModel: 'credit',
        creditTermDays: 30,
        creditLimit: 5000,
        debtDocumentation: 'acknowledgment_only',
        notes: '  urgent  ',
      );
      final body = adapter.requests.single.data as Map;

      // The exact fields the website's form posts (verified 2026-10-06).
      expect(body['counterparty_organization_id'], 23);
      expect(body['as'], 'trader');
      expect(body['requested_model'], 'credit');
      expect(body['requested_credit_term_days'], 30);
      expect(body['requested_credit_limit'], 5000);
      expect(body['debt_documentation'], 'acknowledgment_only');
      expect(body['notes'], 'urgent');
    });

    test('a cash request sends no credit fields', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'relationship': {'id': 6}}));

      await CatalogRepository(client).requestRelationship(
        counterpartyOrganizationId: 23,
        requestedModel: 'direct',
        creditTermDays: 30,
        creditLimit: 5000,
        debtDocumentation: 'both',
      );
      final body = adapter.requests.single.data as Map;

      expect(body['requested_model'], 'direct');
      expect(body.containsKey('requested_credit_term_days'), isFalse);
      expect(body.containsKey('requested_credit_limit'), isFalse);
      expect(body.containsKey('debt_documentation'), isFalse);
      expect(body.containsKey('notes'), isFalse, reason: 'empty notes stay out');
    });
  });

  group('traders directory (guide 6.1)', () {
    test('rows read the relationship the way the supplier list does', () {
      final none = TraderSummary.fromJson(const {
        'id': 6, 'display_name': 'club city', 'relationship_id': 0, 'relationship_status': 'none',
      });
      final pending = TraderSummary.fromJson(const {'id': 21, 'label': 'App', 'relationship_status': 'pending_review'});
      final declined = TraderSummary.fromJson(const {'id': 25, 'label': 'K', 'relationship_status': 'closed'});

      expect(none.relationshipId, isNull, reason: '0 means none on this payload');
      expect(none.canRequest, isTrue);
      expect(pending.isRequestPending, isTrue);
      expect(pending.canRequest, isFalse);
      expect(declined.canRequest, isTrue, reason: 'a declined request can be sent again');
    });

    test('the supplier requests as the selling side', () async {
      final (client, adapter) = clientWith(FakeAdapter((options) async {
        if (options.method == 'POST') return jsonBody(const {'relationship': {'id': 7}});
        return jsonBody(const {
          'items': [
            {'id': 6, 'display_name': 'club city', 'relationship_status': 'none'},
          ],
        });
      }));
      final cubit = TradersDirectoryCubit(SupplierRepository(client), CatalogRepository(client));
      await cubit.load();

      final ok = await cubit.requestRelationship(
        cubit.state.traders.single,
        const RelationshipRequestDraft(model: 'consignment'),
      );
      final post = adapter.requests.firstWhere((r) => r.method == 'POST').data as Map;

      expect(ok, isTrue);
      expect(post['as'], 'supplier');
      expect(post['counterparty_organization_id'], 6);
      expect(post['requested_model'], 'consignment');
      expect(adapter.requests.last.path, contains('lookups/traders'), reason: 'the row re-reads');
      await cubit.close();
    });
  });

  group('legal fixes', () {
    test('supplier acceptance needs its code whatever the transition is called', () {
      const spec = PurchaseOrderCompliance(otpRequiredFor: ['accepted']);
      const legacy = PurchaseOrderCompliance(otpRequiredFor: ['approved']);
      const none = PurchaseOrderCompliance();

      expect(spec.needsOtp('approved'), isTrue, reason: 'the legacy name of the same act');
      expect(spec.needsOtp('accepted'), isTrue);
      expect(legacy.needsOtp('accepted'), isTrue);
      expect(spec.needsOtp('rejected'), isFalse);
      expect(none.needsOtp('approved'), isFalse);
    });

    test('a refusal asking for a code opens the code sheet; a wrong code does not', () {
      expect(PurchaseOrderCompliance.isCodeRequired('otp_required'), isTrue);
      expect(PurchaseOrderCompliance.isCodeRequired('acceptance_otp_required'), isTrue);
      expect(PurchaseOrderCompliance.isCodeRequired('otp_invalid'), isFalse);
      expect(PurchaseOrderCompliance.isCodeRequired('otp_expired'), isFalse);
      expect(PurchaseOrderCompliance.isCodeRequired('validation_error'), isFalse);
    });

    Future<(CreditCubit, FakeAdapter)> creditAt(double limit) async {
      final (client, adapter) = clientWith(FakeAdapter((options) async {
        if (options.method == 'PUT') return jsonBody(const {'credit_profile': {'id': 1, 'credit_limit': 1000}});
        return jsonBody({
          'relationship_id': 6,
          'credit_profile': {'id': 1, 'grade': 'B', 'credit_limit': limit},
        });
      }));
      final cubit = CreditCubit(SupplierRepository(client), 6);
      await cubit.load();
      return (cubit, adapter);
    }

    test('raising the credit limit here is refused: it needs an addendum', () async {
      final (cubit, adapter) = await creditAt(5000);

      final ok = await cubit.save(grade: 'B', creditLimit: 8000);

      expect(ok, isFalse);
      expect(cubit.state.action.status, FormStatus.failure);
      expect(cubit.state.action.fieldError('credit_limit'), isNotNull);
      expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty, reason: 'nothing is sent');
      await cubit.close();
    });

    test('lowering it applies at once', () async {
      final (cubit, adapter) = await creditAt(5000);

      final ok = await cubit.save(grade: 'B', creditLimit: 1000);

      expect(ok, isTrue);
      expect((adapter.requests.firstWhere((r) => r.method == 'PUT').data as Map)['credit_limit'], 1000);
      await cubit.close();
    });
  });
}
