import 'package:digital_trade_portal/core/ui/ui.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:digital_trade_portal/data/models/onboarding/onboarding_bootstrap.dart';
import 'package:digital_trade_portal/data/repositories/organization_repository.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/views/widgets/auth_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// The final batch of the guide audit.
void main() {
  setUp(() async => useFakeStorage());

  group('sign-up password (guide 1, step 2)', () {
    test('a new password needs 8 characters; sign-in keeps the server\'s 6', () {
      expect(AppValidators.newPassword('abc1234'), isNotNull);
      expect(AppValidators.newPassword('abcd1234'), isNull);
      expect(AppValidators.password('abc123'), isNull);
    });

    test('the strength meter grows with length and variety', () {
      expect(PasswordStrengthMeter.score(''), 0);
      expect(PasswordStrengthMeter.score('abc'), 1);
      expect(PasswordStrengthMeter.score('abcdefgh'), 1);
      expect(PasswordStrengthMeter.score('Abcdefg1'), greaterThanOrEqualTo(2));
      expect(PasswordStrengthMeter.score('Abcdefgh1234!@'), 4);
    });
  });

  group('approval and rejection', () {
    test("approval comes from each profile's status, not approved_workspaces", () {
      final hybrid = Organization.fromJson(const {
        'id': 3,
        'business_mode': 'hybrid',
        'approved_workspaces': ['trader', 'supplier'],
        'journey': {
          'trader': {'status': 'active'},
          'supplier': {'status': 'pending_review'},
        },
      });
      final noJourney = Organization.fromJson(const {'id': 3, 'approved_workspaces': ['trader']});

      expect(hybrid.approvedProfileWorkspaces, {'trader'}, reason: 'the supplier side is still in review');
      expect(noJourney.approvedProfileWorkspaces, {'trader'}, reason: 'falls back to the list');
    });

    test('a rejected profile shows its reason until it is sent again', () {
      final rejected = OnboardingProfile.fromJson(const {
        'id': 1, 'profile_type': 'trader', 'status': 'rejected', 'rejection_reason': 'CR expired',
      });
      final resubmitted = OnboardingProfile.fromJson(const {
        'id': 1, 'profile_type': 'trader', 'status': 'pending_review', 'rejection_reason': 'CR expired',
      });

      expect(rejected.isRejected, isTrue);
      expect(rejected.rejectionReason, 'CR expired');
      expect(resubmitted.isRejected, isFalse);
    });

    test('a suspended or blocked organization is restricted', () {
      expect(Organization.fromJson(const {'id': 3, 'status': 'suspended'}).isRestricted, isTrue);
      expect(Organization.fromJson(const {'id': 3, 'status': 'active'}).isRestricted, isFalse);
    });
  });

  group('team (guide 2.6)', () {
    test('an update re-sends the whole row, the membership id included', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {
        'employee': {'id': 27, 'membership_id': 27, 'name': 'Staff', 'role_ids': [5], 'status': 'suspended'},
        'temporary_password': '',
      }));

      final result = await OrganizationRepository(client).saveEmployee(
        membershipId: 27,
        name: 'Staff',
        email: 'staff@example.com',
        roleIds: const [5],
        defaultBranchId: 14,
        status: 'suspended',
      );
      final body = adapter.requests.single.data as Map;

      expect(body['membership_id'], 27);
      expect(body['default_branch_id'], 14, reason: 'an omitted field is cleared by the server');
      expect(body['role_ids'], [5]);
      expect(result.dataOrNull?.employee.status, 'suspended');
    });

    test('a new employee comes back with a temporary password', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {
        'employee': {'id': 30, 'membership_id': 30, 'name': 'New', 'phone': 512340001},
        'temporary_password': 'dJ1LmMAts7',
      }));

      final result = await OrganizationRepository(client).saveEmployee(name: 'New', email: 'n@example.com');

      expect(result.dataOrNull?.temporaryPassword, 'dJ1LmMAts7');
      expect(result.dataOrNull?.employee.phone, '512340001');
    });
  });
}
