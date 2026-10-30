import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/ui/collection_cubit.dart';
import '../../../../../core/ui/form_status.dart';
import '../../../../../data/models/bootstrap/organization.dart';
import '../../../../../data/models/common/branch.dart';
import '../../../../../data/models/common/country.dart';
import '../../../../../data/models/onboarding/bank_account.dart';
import '../../../../../data/models/onboarding/onboarding_bootstrap.dart';
import '../../../../../data/models/onboarding/org_document.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import 'saved_channels.dart';

// ---------------------------------------------------------------------------
// Organization legal identity
// ---------------------------------------------------------------------------

@immutable
class OrganizationFormState {
  final bool loadingCountries;
  final List<Country> countries;
  final String? loadError;
  final SubmitState submit;

  /// What was saved before, so the form opens filled.
  final Organization? existing;

  const OrganizationFormState({
    this.loadingCountries = true,
    this.countries = const [],
    this.loadError,
    this.submit = const SubmitState(),
    this.existing,
  });

  OrganizationFormState copyWith({
    bool? loadingCountries,
    List<Country>? countries,
    String? loadError,
    SubmitState? submit,
    Organization? existing,
    bool clearLoadError = false,
  }) => OrganizationFormState(
    loadingCountries: loadingCountries ?? this.loadingCountries,
    countries: countries ?? this.countries,
    existing: existing ?? this.existing,
    // Was a bare `loadError: loadError`, so every unrelated copyWith —
    // including the one that starts a submit — silently dropped it.
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    submit: submit ?? this.submit,
  );
}

class OrganizationFormCubit extends Cubit<OrganizationFormState> {
  final OnboardingRepository _repo;
  final AuthRepository _auth;

  OrganizationFormCubit(this._repo, this._auth) : super(const OrganizationFormState());

  /// The country/city pair is required by the save, so the pickers load first,
  /// alongside the saved organization that prefills the form.
  Future<void> loadCountries() async {
    emit(state.copyWith(loadingCountries: true, clearLoadError: true));
    final countriesCall = _auth.countries();
    final organizationCall = _repo.organization();
    final result = await countriesCall;
    final organization = await organizationCall;
    if (isClosed) return;
    emit(
      state.copyWith(
        loadingCountries: false,
        countries: result.dataOrNull ?? const [],
        // A failed organization read is not fatal: the form just opens blank.
        existing: organization.dataOrNull,
        loadError: result.failureMessage,
      ),
    );
  }

  Future<Organization?> save({
    required String legalNameAr,
    required String tradeName,
    required int countryId,
    required int cityId,
    String? legalNameEn,
    String? commercialRegNo,
    String? taxNo,
    String? vatNo,
    String? notes,
  }) async {
    if (state.submit.isSubmitting) return null;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.saveOrganization(
      legalNameAr: legalNameAr.trim(),
      tradeName: tradeName.trim(),
      countryId: countryId,
      cityId: cityId,
      legalNameEn: legalNameEn?.trim(),
      commercialRegNo: commercialRegNo?.trim(),
      taxNo: taxNo?.trim(),
      vatNo: vatNo?.trim(),
      notes: notes?.trim(),
    );

    if (isClosed) return null;
    emit(state.copyWith(submit: result.failureState));
    return result.dataOrNull;
  }
}

// ---------------------------------------------------------------------------
// Trader / supplier profile
// ---------------------------------------------------------------------------

@immutable
class ProfileFormState {
  final bool loadingSectors;
  final List<BusinessSector> sectors;
  final String? loadError;
  final SubmitState submit;

  /// `channel_options` — the target business channels, `{code, label}`.
  final List<CodeOption> channels;

  /// What was saved for this workspace last time, so the form opens filled.
  final OnboardingProfile? existing;

  const ProfileFormState({
    this.loadingSectors = true,
    this.sectors = const [],
    this.channels = const [],
    this.loadError,
    this.submit = const SubmitState(),
    this.existing,
  });

  ProfileFormState copyWith({
    bool? loadingSectors,
    List<BusinessSector>? sectors,
    List<CodeOption>? channels,
    String? loadError,
    SubmitState? submit,
    OnboardingProfile? existing,
    bool clearLoadError = false,
  }) => ProfileFormState(
    loadingSectors: loadingSectors ?? this.loadingSectors,
    sectors: sectors ?? this.sectors,
    channels: channels ?? this.channels,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    submit: submit ?? this.submit,
    existing: existing ?? this.existing,
  );
}

/// One profile per workspace. Saving is separate from submitting: a draft can
/// be edited for as long as the user likes, and **submitting is what starts an
/// independent review** for that one side.
class ProfileFormCubit extends Cubit<ProfileFormState> {
  final OnboardingRepository _repo;

  ProfileFormCubit(this._repo) : super(const ProfileFormState());

  /// Loads the sector and channel pickers, and the profile this screen edits.
  ///
  /// One request: the onboarding bootstrap carries `sector_options`,
  /// `channel_options` and the profile itself, as the web form uses them.
  /// The sectors lookup is only a fallback for a bootstrap without options.
  /// [known] is the row the wizard holds, used if the bootstrap lacks it.
  Future<void> load(String profileType, {OnboardingProfile? known}) async {
    emit(state.copyWith(loadingSectors: true, clearLoadError: true));

    final bootstrap = await _repo.fetch();
    if (isClosed) return;
    final data = bootstrap.dataOrNull;

    var sectors = data?.sectorOptions ?? const <BusinessSector>[];
    String? error = bootstrap.failureMessage;
    if (sectors.isEmpty) {
      final lookup = await _repo.sectors();
      if (isClosed) return;
      sectors = lookup.dataOrNull ?? const [];
      error = sectors.isEmpty ? (lookup.failureMessage ?? error) : null;
    }

    var existing = known;
    for (final profile in data?.profiles ?? const <OnboardingProfile>[]) {
      if (profile.profileType == profileType) existing = profile;
    }

    emit(
      state.copyWith(
        loadingSectors: false,
        sectors: sectors,
        channels: data?.channelOptions ?? const [],
        loadError: error,
        existing: existing,
      ),
    );
  }

  Future<bool> save({
    required String profileType,
    int? profileId,
    String? supplierNature,
    List<int> sectorIds = const [],
    List<String> channelCodes = const [],
    String? notes,
  }) async {
    if (state.submit.isSubmitting) return false;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    // Both lists, always — saving the channels is what `profile/submit`
    // checks, and the web form posts them together for the same reason.
    final result = await _repo.saveProfile(
      profileType: profileType,
      profileId: profileId,
      supplierNature: supplierNature,
      sectorIds: sectorIds,
      channelCodes: channelCodes,
      notes: notes?.trim(),
    );

    if (isClosed) return false;
    final ok = result is Ok<OnboardingProfile> || result is NoContent<OnboardingProfile>;
    if (ok && channelCodes.isNotEmpty) {
      final savedId = result.dataOrNull?.id ?? profileId;
      if (savedId != null && savedId > 0) await SavedChannels.mark(savedId);
    }
    if (isClosed) return false;
    emit(state.copyWith(submit: result.failureState, existing: result.dataOrNull));
    return ok;
  }

  Future<bool> submitForReview(String profileType) async {
    if (state.submit.isSubmitting) return false;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.submitProfile(profileType);
    if (isClosed) return false;
    emit(state.copyWith(submit: result.failureState));
    return result is Ok<OnboardingProfile> || result is NoContent<OnboardingProfile>;
  }
}

// ---------------------------------------------------------------------------
// Branches · bank accounts · documents
// ---------------------------------------------------------------------------

class BranchesCubit extends CollectionCubit<Branch> {
  final OnboardingRepository _repo;
  final AuthRepository _auth;

  List<Country> countries = const [];

  BranchesCubit(this._repo, this._auth);

  /// The listing carries each pin and `has_location` (live, 2026-10-11).
  @override
  Future<ApiResult<List<Branch>>> fetchAll() => _repo.branches();

  /// Branches need the same country/city pair the organization does.
  Future<void> loadCountries() async {
    final result = await _auth.countries();
    if (isClosed) return;
    countries = result.dataOrNull ?? const [];
    // Re-emit: when the countries land after the branch list, an open form
    // otherwise kept empty country and city pickers.
    emit(state.copyWith());
  }

  Future<bool> save({
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
    bool? isDefault,
  }) => submit(() async {
    final saved = await _repo.saveBranch(
      branchId: branchId,
      branchType: branchType,
      nameAr: nameAr.trim(),
      countryId: countryId,
      cityId: cityId,
      addressText: addressText.trim(),
      nameEn: nameEn?.trim(),
      contactName: contactName?.trim(),
      contactPhone: contactPhone?.trim(),
      latitude: latitude,
      longitude: longitude,
    );
    // Then the default flag, which only the organization branch
    // endpoint keeps.
    if (saved case Ok(:final data) when isDefault != null) {
      final located = await _repo.setBranchLocation(branchId: data.id, isDefault: isDefault);
      if (located is! Ok<Branch> && located is! NoContent<Branch>) return located;
    }
    return saved;
  });
}

class BankAccountsCubit extends CollectionCubit<BankAccount> {
  final OnboardingRepository _repo;

  BankAccountsCubit(this._repo);

  @override
  Future<ApiResult<List<BankAccount>>> fetchAll() => _repo.bankAccounts();

  Future<bool> save({
    int? bankAccountId,
    required String bankName,
    required String accountName,
    String? accountNumber,
    String? iban,
    String? swiftCode,
    String? currencyCode,
    String? rawDetails,
  }) => submit(
    () => _repo.saveBankAccount(
      bankAccountId: bankAccountId,
      bankName: bankName.trim(),
      accountName: accountName.trim(),
      accountNumber: accountNumber?.trim(),
      iban: iban?.trim(),
      swiftCode: swiftCode?.trim(),
      currencyCode: currencyCode?.trim(),
      rawDetails: (rawDetails ?? '').trim().isEmpty ? null : rawDetails!.trim(),
    ),
  );
}

class DocumentsCubit extends CollectionCubit<OrgDocument> {
  final OnboardingRepository _repo;

  /// 0..1 while a file is uploading, so a slow connection does not look frozen.
  double uploadProgress = 0;

  /// `document_type_options` — the codes the server accepts, with labels.
  List<CodeOption> types = const [];

  DocumentsCubit(this._repo);

  @override
  Future<ApiResult<List<OrgDocument>>> fetchAll() => _repo.documents();

  /// The type picker reads the server's own codes (`commercial_record`, …);
  /// a free-text or guessed code is refused by the upload.
  Future<void> loadTypes() async {
    final result = await _repo.fetch();
    if (isClosed) return;
    types = result.dataOrNull?.documentTypeOptions ?? const [];
    // Re-emits so the list relabels its rows with the server's labels.
    emit(state.copyWith());
  }

  Future<bool> save({
    int? documentId,
    required String documentType,
    String? filePath,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? notes,
  }) {
    uploadProgress = 0;
    return submit(
      () => _repo.saveDocument(
        documentId: documentId,
        documentType: documentType,
        filePath: filePath,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        notes: notes?.trim(),
        onProgress: (sent, total) {
          if (total > 0) uploadProgress = sent / total;
        },
      ),
    );
  }
}
