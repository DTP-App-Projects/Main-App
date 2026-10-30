import 'package:digital_trade_portal/data/repositories/compliance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Incoming relationship requests and their decision (2026-10-06 spec).
void main() {
  setUp(() async => useFakeStorage());

  test('the list asks for one direction, and the badge for the undecided ones', () async {
    final (client, adapter) = clientWith(FakeAdapter.json(const {
      'relationship_requests': [
        {'id': 6, 'request_no': 'REL-2026-000003', 'request_status': 'submitted', 'can_decide': true},
      ],
      'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1},
    }));
    final repo = ComplianceRepository(client);

    final incoming = await repo.relationshipRequests(direction: 'incoming');
    await repo.relationshipRequests(direction: 'incoming', requestStatus: 'submitted');

    expect(adapter.requests.first.queryParameters['direction'], 'incoming');
    expect(adapter.requests.last.queryParameters['request_status'], 'submitted');
    expect(incoming.dataOrNull?.items.single.canDecide, isTrue);
    expect(incoming.dataOrNull?.total, 1);
  });

  test('accepting sends the code and only the grants that changed', () async {
    final (client, adapter) = clientWith(FakeAdapter.json(const {'msg': 'relationship_request_accepted'}));

    await ComplianceRepository(client).decideRelationshipRequest(6, status: 'accepted', otpCode: '123456');
    final body = adapter.requests.single.data as Map;

    expect(body, {'status': 'accepted', 'otp_code': '123456'});
  });
}
