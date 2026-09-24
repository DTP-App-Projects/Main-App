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

// ---------------------------------------------------------------------------
// Organization legal identity
// ---------------------------------------------------------------------------

@immutable
class OrganizationFormState {
  final bool loadingCountries;
  final List<Country> countries;
  final String? loadError;
  final SubmitState submit;

  const OrganizationFormState({
    this.loadingCountries = true,
    this.countries = const [],
    this.loadError,
    this.submit = const SubmitState(),
  });

  OrganizationFormState copyWith({
    bool? loadingCountries,
    List<Country>? countries,
    String? loadError,
    SubmitState? submit,
    bool clearLoadError = false,
  }) =>
      OrganizationFormState(
        loadingCountries: loadingCountries ?? this.loadingCountries,
        countries: countries ?? this.countries,
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

  /// The country/city pair is required by the save, so the pickers load first.
  Future<void> loadCountries() async {
    emit(state.copyWith(loadingCountries: true, clearLoadError: true));
    final result = await _auth.countries();
    emit(state.copyWith(
      loadingCountries: false,
      countries: result.dataOrNull ?? const [],
      loadError: result.failureMessage,
    ));
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

  /// What was saved for this workspace last time, so the form opens filled.
  final OnboardingProfile? existing;

  const ProfileFormState({
    this.loadingSectors = true,
    this.sectors = const [],
    this.loadError,
    this.submit = const SubmitState(),
    this.existing,
  });

  ProfileFormState copyWith({
    bool? loadingSectors,
    List<BusinessSector>? sectors,
    String? loadError,
    SubmitState? submit,
    OnboardingProfile? existing,
    bool clearLoadError = false,
  }) =>
      ProfileFormState(
        loadingSectors: loadingSectors ?? this.loadingSectors,
        sectors: sectors ?? this.sectors,
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

  /// Loads the sector picker, and the profile this screen edits.
  ///
  /// [known] is the row the wizard already holds. When it is supplied this is
  /// **one** request instead of two: re-reading the whole onboarding bootstrap
  /// to find a profile the caller was looking at a moment ago is the kind of
  /// cost that adds up against a sixty-a-minute budget. A deep link arrives
  /// without it, so the fetch stays as the fallback.
  Future<void> load(String profileType, {OnboardingProfile? known}) async {
    emit(state.copyWith(loadingSectors: true, clearLoadError: true));

    final sectors = await _repo.sectors();
    if (isClosed) return;

    var existing = known;
    if (existing == null) {
      final bootstrap = await _repo.fetch();
      if (isClosed) return;
      for (final profile in bootstrap.dataOrNull?.profiles ?? const <OnboardingProfile>[]) {
        if (profile.profileType == profileType) existing = profile;
      }
    }

    emit(state.copyWith(
      loadingSectors: false,
      sectors: sectors.dataOrNull ?? const [],
      loadError: sectors.failureMessage,
      existing: existing,
    ));
  }

  Future<bool> save({
    required String profileType,
    int? profileId,
    String? supplierNature,
    List<int> sectorIds = const [],
    String? notes,
  }) async {
    if (state.submit.isSubmitting) return false;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.saveProfile(
      profileType: profileType,
      profileId: profileId,
      supplierNature: supplierNature,
      sectorIds: sectorIds,
      notes: notes?.trim(),
    );

    if (isClosed) return false;
    emit(state.copyWith(submit: result.failureState));
    return result is Ok<OnboardingProfile> || result is NoContent<OnboardingProfile>;
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

  @override
  Future<ApiResult<List<Branch>>> fetchAll() => _repo.branches();

  /// Branches need the same country/city pair the organization does.
  Future<void> loadCountries() async {
    final result = await _auth.countries();
    countries = result.dataOrNull ?? const [];
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
  }) =>
      submit(() => _repo.saveBranch(
            branchId: branchId,
            branchType: branchType,
            nameAr: nameAr.trim(),
            countryId: countryId,
            cityId: cityId,
            addressText: addressText.trim(),
            nameEn: nameEn?.trim(),
            contactName: contactName?.trim(),
            contactPhone: contactPhone?.trim(),
          ));
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
  }) =>
      submit(() => _repo.saveBankAccount(
            bankAccountId: bankAccountId,
            bankName: bankName.trim(),
            accountName: accountName.trim(),
            accountNumber: accountNumber?.trim(),
            iban: iban?.trim(),
            swiftCode: swiftCode?.trim(),
            currencyCode: currencyCode?.trim(),
          ));
}

class DocumentsCubit extends CollectionCubit<OrgDocument> {
  final OnboardingRepository _repo;

  /// 0..1 while a file is uploading, so a slow connection does not look frozen.
  double uploadProgress = 0;

  DocumentsCubit(this._repo);

  @override
  Future<ApiResult<List<OrgDocument>>> fetchAll() => _repo.documents();

  Future<bool> save({
    int? documentId,
    required String documentType,
    String? filePath,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? notes,
  }) {
    uploadProgress = 0;
    return submit(() => _repo.saveDocument(
          documentId: documentId,
          documentType: documentType,
          filePath: filePath,
          issuedAt: issuedAt,
          expiresAt: expiresAt,
          notes: notes?.trim(),
          onProgress: (sent, total) {
            if (total > 0) uploadProgress = sent / total;
          },
        ));
  }
}
