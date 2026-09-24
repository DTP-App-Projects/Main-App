import 'package:digital_trade_portal/data/models/advanced/contract.dart';
import 'package:digital_trade_portal/data/models/advanced/finance.dart';
import 'package:digital_trade_portal/data/repositories/account_repository.dart';
import 'package:digital_trade_portal/data/repositories/contracts_repository.dart';
import 'package:digital_trade_portal/features/shared/advanced/view_models/advanced_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

void main() {
  group('contracts', () {
    test('pending approvals are the ones still waiting on someone', () {
      final contract = Contract.fromJson(const {
        'id': 3,
        'status': 'under_review',
        'approvals': [
          {'id': 1, 'status': 'approved'},
          {'id': 2, 'status': 'pending'},
          {'id': 3, 'status': ''},
        ],
      });

      // An empty status is pending too — the server omits it before anyone
      // has acted.
      expect(contract.pendingApprovals.map((a) => a.id), [2, 3]);
    });

    test('the label falls back through display name, locale pair, then code', () {
      expect(
        Contract.fromJson(const {'id': 1, 'display_name': 'Shelf 2026'}).label('en'),
        'Shelf 2026',
      );
      expect(
        Contract.fromJson(const {'id': 1, 'name_ar': 'عقد الرفوف'}).label('ar'),
        'عقد الرفوف',
      );
      expect(Contract.fromJson(const {'id': 1, 'code': 'CN-9'}).label('en'), 'CN-9');
    });

    test('an approval decision posts to the contract-scoped path', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final repo = ContractsRepository(client);

      await repo.decideContractApproval(
        contractId: 3,
        approvalId: 7,
        status: 'approved',
      );

      expect(adapter.requests.single.path, endsWith('/contracts/3/approvals/7'));
      expect((adapter.requests.single.data as Map)['status'], 'approved');
    });

    test('contract dates go as plain days', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'contract': {'id': 1}}));
      final repo = ContractsRepository(client);

      await repo.saveContract(
        relationshipId: 12,
        contractType: 'consignment',
        startDate: DateTime(2026, 1, 5, 9, 30),
      );

      expect((adapter.requests.single.data as Map)['start_date'], '2026-01-05');
    });
  });

  group('shelf counting', () {
    test('the implied sale is what the numbers add up to', () {
      const line = CountDraft(
        skuId: 1,
        skuName: 'SKU-1',
        previousCount: 20,
        addedCount: 10,
        currentCount: 15,
        damagedCount: 2,
        expiredCount: 1,
      );
      // 20 + 10 - 15 - 2 - 1
      expect(line.impliedSold, 12);
      expect(line.looksWrong, isFalse);
    });

    test('a count that implies a negative sale is flagged, not silently sent', () {
      const line = CountDraft(
        skuId: 1,
        skuName: 'SKU-1',
        previousCount: 5,
        currentCount: 40,
      );
      expect(line.impliedSold, -35);
      expect(line.looksWrong, isTrue);
    });

    test('previous counts are requested as a repeated array param', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      final repo = ContractsRepository(client);

      await repo.previousCount(contractId: 3, branchId: 9, skuIds: [1, 2, 3]);
      final query = adapter.requests.single.queryParameters;

      expect(query['sku_ids[]'], [1, 2, 3]);
      expect(query['contract_id'], 3);
      expect(query['branch_id'], 9);
    });

    test('prefilling fills previous counts without touching the rest', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {
        'data': [
          {'sku_id': 1, 'previous_count': 40},
          {'sku_id': 2, 'previous_count': 12},
        ],
      }));
      final cubit = ShelfCountCubit(
        ContractsRepository(client),
        contractId: 3,
        branchId: 9,
      );

      cubit.addSku(skuId: 1, skuName: 'A');
      cubit.addSku(skuId: 2, skuName: 'B');
      cubit.updateLine(1, (line) => line.copyWith(currentCount: 30));

      await cubit.prefillPreviousCounts();

      expect(cubit.state.lines.first.previousCount, 40);
      // The number the operator already typed is left alone.
      expect(cubit.state.lines.first.currentCount, 30);
      expect(cubit.state.lines.last.previousCount, 12);
    });

    test('the same SKU is not added twice', () {
      final (client, _) = clientWith(FakeAdapter.json(const {'data': []}));
      final cubit = ShelfCountCubit(
        ContractsRepository(client),
        contractId: 3,
        branchId: 9,
      );

      cubit.addSku(skuId: 1, skuName: 'A');
      cubit.addSku(skuId: 1, skuName: 'A');

      expect(cubit.state.lines.length, 1);
    });

    test('photo paths are sent, never files', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'shelf_adjustment': {'id': 1}}));
      final repo = ContractsRepository(client);

      await repo.saveShelfAdjustment(
        contractId: 3,
        adjustmentType: 'damage',
        lines: const [
          ShelfLineInput(skuId: 1, currentCount: 5, beforePhotoPath: 'uploads/a.jpg'),
        ],
      );

      final lines = (adapter.requests.single.data as Map)['lines'] as List;
      expect((lines.single as Map)['before_photo_path'], 'uploads/a.jpg');
      // Fields that were not set are omitted rather than zeroed.
      expect((lines.single as Map).containsKey('after_photo_path'), isFalse);
    });
  });

  group('settlement arithmetic is the server\'s', () {
    test('every figure is read, none recomputed', () {
      final settlement = Settlement.fromJson(const {
        'id': 1,
        'gross_sales': 10000,
        'returns_total': 500,
        'damage_total': 200,
        'expiry_total': 100,
        'shelf_fees': 300,
        'service_fees': 150,
        'net_payable_supplier': 8750,
        'status': 'approved',
      });

      // 10000 - 500 - 200 - 100 - 300 - 150 = 8750, but the client takes the
      // server's number rather than deriving it.
      expect(settlement.netPayableSupplier, 8750);
      expect(settlement.isPaid, isFalse);
    });

    test('a paid_at timestamp counts as paid even if the status lags', () {
      final settlement = Settlement.fromJson(const {
        'id': 1,
        'status': 'approved',
        'paid_at': '2026-09-01 10:00:00',
      });
      expect(settlement.isPaid, isTrue);
    });
  });

  group('ratings', () {
    test('the dimension vocabulary comes from the data, not a hardcoded list', () {
      final aggregate = RatingAggregate.fromJson(const {
        'business_relationship_id': 12,
        'aggregate': {
          'average': 4.2,
          'count': 9,
          'dimensions': {
            'delivery_speed': 4.5,
            'quality': 3.9,
          },
        },
      });

      expect(aggregate.knownDimensions, ['delivery_speed', 'quality']);
      expect(aggregate.average, 4.2);
      expect(aggregate.count, 9);
    });

    test('a list-shaped aggregate parses the same way', () {
      final aggregate = RatingAggregate.fromJson(const {
        'aggregate': {
          'by_dimension': [
            {'dimension': 'quality', 'average': 4.0},
          ],
        },
      });
      expect(aggregate.byDimension['quality'], 4.0);
    });

    test('a score is clamped to the 1-5 the server accepts', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'rating': {'id': 1}}));
      final repo = AccountRepository(client);

      await repo.rate(businessRelationshipId: 12, dimension: 'quality', score: 9);
      expect((adapter.requests.single.data as Map)['score'], 5);
    });
  });

  group('account deletion', () {
    test('a request with no id is not an active one', () {
      expect(DeletionRequest.fromJson(const {}).isActive, isFalse);
      expect(
        DeletionRequest.fromJson(const {'id': 3, 'status': 'pending'}).isActive,
        isTrue,
      );
      expect(
        DeletionRequest.fromJson(const {'id': 3, 'status': 'canceled'}).isActive,
        isFalse,
      );
    });

    test('cancelling is a DELETE on the same path', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      await AccountRepository(client).cancelDeletion();

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, endsWith('/account/deletion_request'));
    });
  });

  group('Nafath', () {
    test('the feature being off is a failure, not a started transaction', () async {
      // The server answers 200 with `nafath_disabled`; the normalizer turns
      // that into a Failed so it cannot look like success.
      final (client, _) = clientWith(FakeAdapter.json(const {
        'msg': 'nafath_disabled',
        'nafath_enabled': false,
      }));
      final cubit = NafathCubit(AccountRepository(client));

      final started = await cubit.start('1234567890');

      expect(started, isFalse);
      expect(cubit.state.transaction, isNull);
      expect(cubit.state.action.message, isNotNull);
      await cubit.close();
    });

    test('a pending transaction is neither approved nor rejected', () {
      final pending = NafathTransaction.fromJson(const {'transaction_id': 'abc'});
      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);

      final approved =
          NafathTransaction.fromJson(const {'transaction_id': 'abc', 'status': 'approved'});
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
    });

    test('the status poll is never de-duplicated', () async {
      final (client, adapter) =
          clientWith(FakeAdapter.json(const {'transaction': {'status': 'pending'}}));
      final repo = AccountRepository(client);

      await Future.wait([repo.nafathStatus('abc'), repo.nafathStatus('abc')]);
      expect(adapter.requests.length, 2);
    });
  });

  group('web bridge', () {
    test('the refresh margin sits inside the link lifetime', () {
      const link = WebBridgeLink(url: 'https://x', target: 'shelf', expiresInSeconds: 300);
      expect(link.isValid, isTrue);
      expect(link.refreshAfter.inSeconds, 240);
    });

    test('an empty url is not usable', () {
      const link = WebBridgeLink(url: '', target: 'x', expiresInSeconds: 60);
      expect(link.isValid, isFalse);
    });
  });

  group('wallet and subscription', () {
    test('the wallet reads whichever balance key the server used', () {
      expect(Wallet.fromJson(const {'balance': 500}).balance, 500);
      expect(Wallet.fromJson(const {'available_balance': 250}).balance, 250);
    });

    test('a top-up sends the proof as a path', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final repo = AccountRepository(client);

      await repo.requestTopup(
        amount: 500,
        method: 'bank_transfer',
        transferProofPath: 'uploads/receipt.pdf',
      );
      final body = adapter.requests.single.data as Map;

      expect(body['transfer_proof_path'], 'uploads/receipt.pdf');
      expect(body.containsKey('gateway_payment_id'), isFalse);
    });

    test('a trial is on when the status says so or a date is set', () {
      expect(
        SubscriptionSummary.fromJson(const {'status': 'trial'}).onTrial,
        isTrue,
      );
      expect(
        SubscriptionSummary.fromJson(
          const {'status': 'active', 'trial_ends_at': '2026-12-01 00:00:00'},
        ).onTrial,
        isTrue,
      );
      expect(
        SubscriptionSummary.fromJson(const {'status': 'active'}).onTrial,
        isFalse,
      );
    });
  });
}
