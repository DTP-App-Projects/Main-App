import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../api_paths.dart';
import '../models/bootstrap/organization.dart';
import '../models/common/branch.dart';
import '../models/onboarding/bank_account.dart';
import '../models/onboarding/onboarding_bootstrap.dart';
import '../models/onboarding/org_document.dart';

/// The onboarding wizard's data layer.
///
/// Every write here is an **idempotent upsert** — an optional id in the body
/// turns create into update — so a retry after a dropped response cannot
/// produce a duplicate branch or a second bank account.
class OnboardingRepository {
  final ApiClient _client;

  OnboardingRepository(this._client);

  Future<ApiResult<OnboardingBootstrap>> fetch() => _client.get<OnboardingBootstrap>(
    ApiPaths.onboardingBootstrap,
    parse: (body) => OnboardingBootstrap.fromJson(asMap(body)),
  );

  // ------------------------------------------------------------ organization

  /// The full organization row. `/v2/bootstrap` only carries a summary without
  /// the legal identity, so the edit form reads this instead.
  Future<ApiResult<Organization>> organization() => _client.get<Organization>(
    ApiPaths.organization,
    parse: (body) => Organization.fromJson(asMap(asMap(body)['organization'])),
  );

  /// Required: `legal_name_ar`, `trade_name`, `country_id`, `city_id`.
  Future<ApiResult<Organization>> saveOrganization({
    required String legalNameAr,
    required String tradeName,
    required int countryId,
    required int cityId,
    String? legalNameEn,
    String? commercialRegNo,
    String? taxNo,
    String? vatNo,
    String? notes,
  }) => _client.put<Organization>(
    ApiPaths.onboardingOrganization,
    body: {
      'legal_name_ar': legalNameAr,
      'trade_name': tradeName,
      'country_id': countryId,
      'city_id': cityId,
      'legal_name_en': ?legalNameEn,
      'commercial_reg_no': ?commercialRegNo,
      'tax_no': ?taxNo,
      'vat_no': ?vatNo,
      'notes': ?notes,
    },
    parse: (body) => Organization.fromJson(asMap(asMap(body)['organization'])),
  );

  // ----------------------------------------------------------------- profile

  /// Called once per workspace the organization wants. Holding both profiles
  /// is what makes it `hybrid`.
  Future<ApiResult<OnboardingProfile>> saveProfile({
    required String profileType,
    int? profileId,
    String? supplierNature,
    List<int> sectorIds = const [],
    List<String> channelCodes = const [],
    String? notes,
  }) => _client.put<OnboardingProfile>(
    ApiPaths.onboardingProfile,
    body: {
      'profile_type': profileType,
      'profile_id': ?profileId,
      // Only meaningful on a supplier profile; null is the documented
      // value for a trader.
      'supplier_nature': profileType == 'supplier' ? supplierNature : null,
      'sector_ids': sectorIds,
      // An empty list overwrites the saved channels with nothing, and
      // `profile/submit` then fails for good — so it is never sent.
      if (channelCodes.isNotEmpty) 'channel_codes': channelCodes,
      'notes': ?notes,
    },
    parse: (body) => OnboardingProfile.fromJson(asMap(asMap(body)['profile'])),
  );

  /// Sends one profile for review. Each is reviewed independently, which is
  /// why `approved_workspaces` can hold one side and not the other.
  Future<ApiResult<OnboardingProfile>> submitProfile(String profileType) =>
      _client.post<OnboardingProfile>(
        ApiPaths.onboardingProfileSubmit,
        body: {'profile_type': profileType},
        parse: (body) => OnboardingProfile.fromJson(asMap(asMap(body)['profile'])),
      );

  /// How an existing single-mode organization becomes hybrid.
  Future<ApiResult<void>> requestWorkspace(String workspace) =>
      _client.post<void>(ApiPaths.requestWorkspace, body: {'workspace': workspace});

  /// Sends the whole organization for review once the profiles are filled in.
  Future<ApiResult<Organization>> submitForReview() => _client.post<Organization>(
    ApiPaths.submitForReview,
    parse: (body) => Organization.fromJson(asMap(asMap(body)['organization'])),
  );

  // ---------------------------------------------------------------- branches

  Future<ApiResult<List<Branch>>> branches() => _client.get<List<Branch>>(
    ApiPaths.consoleBranches,
    parse: (body) => asList(asMap(body)['items'], Branch.fromJson),
  );

  /// Upsert — omit [branchId] to create.
  ///
  /// The map pin travels with it (live, 2026-10-11): both coordinates or
  /// neither — one alone is `400 validation_error`. Both `null` clears the
  /// pin, while omitting the keys keeps it, so the form always sends them
  /// (pass [keepLocation] only from callers that never showed the map).
  Future<ApiResult<Branch>> saveBranch({
    int? branchId,
    required String branchType,
    required String nameAr,
    required int countryId,
    required int cityId,
    required String addressText,
    String? nameEn,
    String? contactName,
    String? contactPhone,
    double? latitude,
    double? longitude,
    bool keepLocation = false,
  }) => _client.post<Branch>(
    ApiPaths.onboardingBranches,
    body: {
      'branch_id': ?branchId,
      'branch_type': branchType,
      'name_ar': nameAr,
      'country_id': countryId,
      'city_id': cityId,
      'address_text': addressText,
      'name_en': ?nameEn,
      'contact_name': ?contactName,
      'contact_phone': ?contactPhone,
      if (!keepLocation) ...BranchPin.body(latitude, longitude),
    },
    parse: (body) => Branch.fromJson(asMap(asMap(body)['branch'])),
  );

  /// The default flag, which only the organization branch endpoint keeps.
  /// It takes the pin too, with the same both-or-neither rule.
  Future<ApiResult<Branch>> setBranchLocation({
    required int branchId,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) => _client.patch<Branch>(
    ApiPaths.organizationBranch(branchId),
    body: {'latitude': ?latitude, 'longitude': ?longitude, 'is_default': ?isDefault},
    parse: (body) => Branch.fromJson(asMap(asMap(body)['branch'])),
  );

  // ----------------------------------------------------------- bank accounts

  Future<ApiResult<List<BankAccount>>> bankAccounts() => _client.get<List<BankAccount>>(
    ApiPaths.consoleBankAccounts,
    parse: (body) => asList(asMap(body)['items'], BankAccount.fromJson),
  );

  /// Upsert — omit [bankAccountId] to create.
  Future<ApiResult<BankAccount>> saveBankAccount({
    int? bankAccountId,
    required String bankName,
    required String accountName,
    String? accountNumber,
    String? iban,
    String? swiftCode,
    String? currencyCode,
    String? rawDetails,
  }) => _client.post<BankAccount>(
    ApiPaths.onboardingBankAccounts,
    body: {
      'bank_account_id': ?bankAccountId,
      'bank_name': bankName,
      'account_name': accountName,
      'account_number': ?accountNumber,
      'iban': ?iban,
      'swift_code': ?swiftCode,
      'currency_code': ?currencyCode,
      'raw_details': ?rawDetails,
    },
    parse: (body) => BankAccount.fromJson(asMap(asMap(body)['bank_account'])),
  );

  // --------------------------------------------------------------- documents

  Future<ApiResult<List<OrgDocument>>> documents() => _client.get<List<OrgDocument>>(
    ApiPaths.consoleDocuments,
    parse: (body) => asList(asMap(body)['items'], OrgDocument.fromJson),
  );

  /// Direct multipart upsert — **not** the two-step `/v2/uploads` pattern the
  /// rest of v2 uses for file fields.
  ///
  /// [filePath] is validated against [UploadRules] before this is called, so a
  /// 10 MB video never costs the user a round trip.
  Future<ApiResult<OrgDocument>> saveDocument({
    int? documentId,
    required String documentType,
    String? filePath,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? notes,
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      'document_id': ?documentId,
      'document_type': documentType,
      if (issuedAt != null) 'issued_at': _day(issuedAt),
      if (expiresAt != null) 'expires_at': _day(expiresAt),
      'notes': ?notes,
      if (filePath != null) 'document_file': await MultipartFile.fromFile(filePath),
    });

    return _client.multipart<OrgDocument>(
      ApiPaths.onboardingDocuments,
      form: form,
      onSendProgress: onProgress,
      parse: (body) => OrgDocument.fromJson(asMap(asMap(body)['document'])),
    );
  }

  // ----------------------------------------------------------------- lookups

  Future<ApiResult<List<BusinessSector>>> sectors() => _client.get<List<BusinessSector>>(
    ApiPaths.lookupBusinessSectors,
    parse: (body) => asList(asMap(body)['items'], BusinessSector.fromJson),
  );

  /// The server compares `expires_at >= issued_at` on dates, not timestamps.
  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
