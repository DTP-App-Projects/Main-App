import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/bootstrap/bootstrap.dart';
import 'package:digital_trade_portal/data/models/bootstrap/flags.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bootstrap payload shaped the way the live server sends it: `m_p` on the
/// phone, numeric-looking strings already turned into numbers, and a hybrid
/// organization with one profile still pending.
const _payload = {
  'user': {
    'id': 1,
    'name': 'Khaled',
    'legacy_type': 'buyer',
    'workspace_type': 'trader',
    'available_workspaces': ['trader', 'supplier'],
    'primary_organization_id': 3,
    'image': 'https://tacaml.com/uploads/users/1.png',
    'email': 'owner@example.com',
    'phone': 'm_p0501234567',
  },
  'organizations': [
    {
      'id': 3,
      'display_name': 'Tajer Demo',
      'business_mode': 'hybrid',
      'supplier_nature': 'supplier',
      'status': 'active',
      'is_owner': true,
      'default_branch_id': 9,
      'approved_workspaces': ['trader'],
      'journey': {
        'state': 'setup',
        'state_label': 'Setting up',
        'profiles_ready': 1,
        'profiles_pending': 1,
        'hybrid_ready': false,
        'next_best_action': 'Submit the supplier profile',
        'trader': {'status': 'active', 'score': 80, 'missing': []},
        'supplier': {
          'status': 'draft',
          'score': 20,
          'missing': ['bank_account', 'documents'],
        },
        'timeline': [
          {
            'date': '2026-09-19 14:02:11',
            'title': 'Trader profile approved',
            'status': 'active',
            'text': '',
          },
        ],
      },
      'roles': [
        {'code': 'owner', 'name': 'Owner'},
      ],
      'permissions': ['purchase_orders.manage', 'deliveries.manage'],
      'branches': [
        {
          'id': 9,
          'type': 'hq',
          'name_ar': 'الفرع الرئيسي',
          'name_en': '',
          'is_default': true,
          'status': 'active',
          'address_text': 'm_p12 King Fahd Rd',
        },
      ],
      'stats': {
        'products_count': 0,
        'skus_count': 0,
        'relationships_count': 2,
        'open_drafts_count': 1,
        'open_orders_count': 4,
        'bank_accounts_count': 1,
      },
    },
    {
      'id': 5,
      'display_name': 'Second Org',
      'business_mode': 'supplier',
      'status': 'pending_review',
      'is_owner': false,
      'approved_workspaces': <String>[],
      'permissions': ['invoices.view'],
    },
  ],
  'feature_flags': {'single_app_workspaces': true, 'credit_strict_mode': true},
  'platform_flags': {'nafath_enabled': false, 'payment_gateway_enabled': true},
};

void main() {
  final bootstrap = Bootstrap.fromJson(_payload);

  group('user', () {
    test('the phone loses its m_p guard and keeps its leading zero', () {
      expect(bootstrap.user.phone, '0501234567');
    });

    test('workspace_type maps onto the workspace enum', () {
      expect(bootstrap.user.preferredWorkspace, Workspace.trader);
    });
  });

  group('organizations', () {
    final org = bootstrap.organizations.first;

    test('business_mode decides the shell, not users.type', () {
      expect(bootstrap.user.legacyType, 'buyer');
      expect(org.isHybrid, isTrue);
      expect(org.workspaces, [Workspace.trader, Workspace.supplier]);
    });

    test('an approved profile is distinguishable from a pending one', () {
      expect(org.approvedWorkspaces, ['trader']);
      expect(org.journey.supplier.missing, ['bank_account', 'documents']);
      expect(org.journey.isComplete, isFalse);
    });

    test('a branch name falls back across locales the way display_name does', () {
      final branch = org.branches.single;
      expect(branch.displayName('ar'), 'الفرع الرئيسي');
      // `name_en` is empty, so the Arabic name is used rather than a blank.
      expect(branch.displayName('en'), 'الفرع الرئيسي');
      expect(branch.addressText, '12 King Fahd Rd');
    });

    test('a missing journey does not blow up the parse', () {
      final second = bootstrap.organizations.last;
      expect(second.journey.state, '');
      expect(second.needsOnboarding, isTrue);
      expect(second.branches, isEmpty);
    });
  });

  group('organization resolution', () {
    test('an explicit choice wins', () {
      expect(bootstrap.resolveOrganization(5)?.id, 5);
    });

    test('otherwise the user primary organization is used', () {
      expect(bootstrap.resolveOrganization(null)?.id, 3);
    });

    test('an id the user does not belong to falls back rather than failing', () {
      expect(bootstrap.resolveOrganization(999)?.id, 3);
    });
  });

  group('flags', () {
    test('known flags read through, unknown ones are false not a crash', () {
      expect(bootstrap.featureFlags.singleAppWorkspaces, isTrue);
      expect(bootstrap.platformFlags.nafathEnabled, isFalse);
      expect(bootstrap.featureFlags.isEnabled('a_flag_added_next_month'), isFalse);
    });

    test('the live /platform/flags split of flags and defaults folds into one type', () {
      final response = PlatformFlagsResponse.fromJson({
        'flags': {'nafath_enabled': false, 'apple_pay_enabled': true},
        'defaults': {'commission_rate': 2, 'trial_days': 30},
      });
      expect(response.flags.applePayEnabled, isTrue);
      expect(response.commissionRate, 2);
      expect(response.trialDays, 30);
    });

    test('the documented flat shape still parses', () {
      final response = PlatformFlagsResponse.fromJson({
        'flags': {'nafath_enabled': true, 'default_commission_rate': 3},
      });
      expect(response.flags.nafathEnabled, isTrue);
      expect(response.commissionRate, 3);
    });
  });
}
