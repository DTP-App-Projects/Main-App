import 'package:digital_trade_portal/core/network/api_result.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:digital_trade_portal/data/models/onboarding/bank_account.dart';
import 'package:digital_trade_portal/data/models/onboarding/onboarding_bootstrap.dart';
import 'package:digital_trade_portal/data/models/onboarding/org_document.dart';
import 'package:digital_trade_portal/data/repositories/onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

void main() {
  group('OnboardingBootstrap', () {
    test('reads the journey from the top level', () {
      final bootstrap = OnboardingBootstrap.fromJson(const {
        'organization': {'id': 3, 'business_mode': 'hybrid'},
        'journey': {'state': 'setup', 'profiles_ready': 1, 'profiles_pending': 1},
        'profiles': [
          {'id': 11, 'profile_type': 'trader', 'status': 'active'},
        ],
      });

      expect(bootstrap.journey.state, 'setup');
      expect(bootstrap.organization?.isHybrid, isTrue);
      expect(bootstrap.profileFor(Workspace.trader)?.id, 11);
      expect(bootstrap.profileFor(Workspace.supplier), isNull);
    });

    test('falls back to the copy nested under organization', () {
      final bootstrap = OnboardingBootstrap.fromJson(const {
        'organization': {
          'id': 3,
          'journey': {'state': 'review', 'state_label': 'Under review'},
        },
      });

      expect(bootstrap.journey.stateLabel, 'Under review');
    });

    test('profiles keyed by type parse like a list', () {
      // The endpoint's exact `profiles` shape is not published, so both the
      // list and the keyed-map form are accepted rather than guessed at.
      final profiles = OnboardingProfile.listFrom(const {
        'trader': {'id': 1, 'status': 'active'},
        'supplier': {'id': 2, 'status': 'draft', 'supplier_nature': 'manufacturer'},
      });

      expect(profiles.map((p) => p.profileType), containsAll(['trader', 'supplier']));
      expect(profiles.firstWhere((p) => p.isSupplier).supplierNature, 'manufacturer');
    });

    test('sectors parse as bare ids or as rows', () {
      final fromIds = OnboardingProfile.fromJson(const {
        'profile_type': 'trader',
        'sector_ids': [3, 7],
      });
      final fromRows = OnboardingProfile.fromJson(const {
        'profile_type': 'trader',
        'sectors': [
          {'id': 3, 'name': 'Food'},
          {'id': 7, 'name': 'Retail'},
        ],
      });

      expect(fromIds.sectorIds, [3, 7]);
      expect(fromRows.sectorIds, [3, 7]);
    });

    test('a profile under review is locked, not editable', () {
      final profile = OnboardingProfile.fromJson(const {
        'profile_type': 'supplier',
        'status': 'pending_review',
      });
      expect(profile.isUnderReview, isTrue);
      expect(profile.isDraft, isFalse);
    });
  });

  group('Organization legal identity', () {
    test('country and city parse from an id or from a nested row', () {
      final flat = Organization.fromJson(const {'id': 1, 'country_id': 1, 'city_id': 2});
      final nested = Organization.fromJson(const {
        'id': 1,
        'country': {'id': 1, 'name': 'Saudi Arabia'},
        'city': {'id': 2, 'name': 'Riyadh'},
      });

      expect(flat.countryId, 1);
      expect(nested.countryId, 1);
      expect(nested.cityId, 2);
    });

    test('an all-digit registration number survives as a string', () {
      // JSON_NUMERIC_CHECK turns "1010101010" into a number on the wire.
      final org = Organization.fromJson(const {'id': 1, 'commercial_reg_no': 1010101010});
      expect(org.commercialRegNo, '1010101010');
    });

    test('the step is complete only when all four required fields are filled', () {
      const required = {
        'id': 1,
        'legal_name_ar': 'شركة الاختبار',
        'trade_name': 'Test',
        'country_id': 1,
        'city_id': 2,
      };
      expect(Organization.fromJson(required).hasLegalIdentity, isTrue);

      final missingCity = Map<String, dynamic>.from(required)..remove('city_id');
      expect(Organization.fromJson(missingCity).hasLegalIdentity, isFalse);
    });
  });

  group('BankAccount', () {
    test('a numeric IBAN and account number are read as text', () {
      final account = BankAccount.fromJson(const {
        'id': 4,
        'bank_name': 'Al Rajhi',
        'account_number': 12345,
        'iban': 1234567890123456,
      });

      expect(account.accountNumber, '12345');
      expect(account.iban, '1234567890123456');
    });

    test('the masked IBAN keeps the ends and hides the middle', () {
      final account = BankAccount.fromJson(const {'id': 1, 'iban': 'SA0380000000608010167519'});
      expect(account.maskedIban, startsWith('SA03'));
      expect(account.maskedIban, endsWith('7519'));
    });
  });

  group('OrgDocument', () {
    test('an expiry in the past is flagged', () {
      final expired = OrgDocument.fromJson({
        'id': 1,
        'document_type': 'commercial_registration',
        'expires_at': '2020-01-01 00:00:00',
      });
      expect(expired.isExpired, isTrue);
    });

    test('an empty date string means unset, not the epoch', () {
      final document = OrgDocument.fromJson(const {'id': 1, 'expires_at': ''});
      expect(document.expiresAt, isNull);
      expect(document.isExpired, isFalse);
    });
  });

  group('UploadRules', () {
    test('accepts the documented extensions and rejects the rest', () {
      expect(UploadRules.isAllowedExtension('/tmp/cr.pdf'), isTrue);
      expect(UploadRules.isAllowedExtension(r'C:\docs\CR.PNG'), isTrue);
      expect(UploadRules.isAllowedExtension('/tmp/clip.mp4'), isFalse);
      expect(UploadRules.isAllowedExtension('/tmp/noextension'), isFalse);
    });
  });

  group('OnboardingRepository upserts', () {
    test('a create omits the id, an edit carries it', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'branch': {'id': 9}}));
      final repo = OnboardingRepository(client);

      await repo.saveBranch(
        branchType: 'hq',
        nameAr: 'الفرع الرئيسي',
        countryId: 1,
        cityId: 2,
        addressText: 'Riyadh',
      );
      await repo.saveBranch(
        branchId: 9,
        branchType: 'hq',
        nameAr: 'الفرع الرئيسي',
        countryId: 1,
        cityId: 2,
        addressText: 'Riyadh',
      );

      final create = adapter.requests.first.data as Map;
      final edit = adapter.requests.last.data as Map;

      // The optional id is what turns create into update — this is why a
      // retry after a dropped response cannot duplicate a branch.
      expect(create.containsKey('branch_id'), isFalse);
      expect(edit['branch_id'], 9);
    });

    test('supplier_nature is sent as null for a trader profile', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'profile': {'id': 1}}));
      final repo = OnboardingRepository(client);

      await repo.saveProfile(profileType: 'trader', supplierNature: 'manufacturer');
      final body = adapter.requests.single.data as Map;

      expect(body['profile_type'], 'trader');
      expect(body['supplier_nature'], isNull);
    });

    test('document dates are sent as plain days, not timestamps', () async {
      final (client, adapter) = clientWith(FakeAdapter.json({'document': {'id': 1}}));
      final repo = OnboardingRepository(client);

      await repo.saveDocument(
        documentType: 'commercial_registration',
        issuedAt: DateTime(2026, 1, 5, 13, 30),
        expiresAt: DateTime(2027, 12, 31),
      );

      final form = adapter.requests.single.data;
      final fields = {for (final f in (form as dynamic).fields) f.key: f.value};
      expect(fields['issued_at'], '2026-01-05');
      expect(fields['expires_at'], '2027-12-31');
      expect(fields.containsKey('document_id'), isFalse);
    });

    test('a workspace request posts the workspace it was asked for', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final repo = OnboardingRepository(client);

      final result = await repo.requestWorkspace('supplier');

      expect(result, isA<NoContent<void>>());
      expect((adapter.requests.single.data as Map)['workspace'], 'supplier');
    });
  });
}
