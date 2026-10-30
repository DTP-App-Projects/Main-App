import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/error/error_messages.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/network/coerce.dart';
import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/workspace/workspace.dart';
import '../../../../../data/models/auth/auth_user.dart';
import '../../../../../data/models/common/country.dart';
import '../../../../../data/models/compliance/terms.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../core/ui/form_status.dart';

/// Sign-up follows the website's four steps: business mode, owner,
/// organization, then terms and submit. Which one you are on is state like
/// anything else, so it lives here rather than in a view's `setState`.
enum RegisterStep {
  mode,
  owner,
  organization,
  terms;

  /// The step that holds a server field, so a rejected submit can jump back
  /// to the field it names.
  static RegisterStep forField(String field) => switch (field) {
        'business_mode' || 'activity_type' => mode,
        'first_name' || 'last_name' || 'email' || 'password' => owner,
        'organization_name' || 'country_id' || 'city_id' || 'address' || 'phone' || 'whatsapp' =>
          organization,
        _ => terms,
      };
}

@immutable
class RegisterOwnerState {
  final RegisterStep step;
  final SubmitState submit;
  final List<Country> countries;
  final bool loadingCountries;
  final String? countriesError;

  /// `trader` | `supplier` | `hybrid`, chosen on screen one. It decides which
  /// workspace(s) the new organization gets.
  final String businessMode;

  /// Required since the compliance release. Picked on the mode step from the
  /// options that mode allows; `marketer` is a trader-mode activity.
  final String? activityType;

  /// The platform terms shown with the mandatory checkbox.
  final SignupTerms? terms;
  final bool loadingTerms;
  final String? termsError;
  final bool termsAccepted;

  /// The full set the server asked for in `409 terms_version_outdated`:
  /// platform terms plus the joining agreement for the chosen activity.
  /// Empty until the server has named it.
  final List<RequiredTermsVersion> requiredTerms;

  /// Set when the account was created and now waits for its email code —
  /// the view leaves for the Confirm email screen. No session exists yet.
  final EmailVerificationChallenge? verification;

  const RegisterOwnerState({
    this.verification,
    this.requiredTerms = const [],
    this.terms,
    this.loadingTerms = false,
    this.termsError,
    this.termsAccepted = false,
    this.step = RegisterStep.mode,
    this.submit = const SubmitState(),
    this.countries = const [],
    this.loadingCountries = false,
    this.countriesError,
    this.businessMode = 'trader',
    this.activityType = 'retailer',
  });

  RegisterOwnerState copyWith({
    RegisterStep? step,
    SubmitState? submit,
    List<Country>? countries,
    bool? loadingCountries,
    String? countriesError,
    String? businessMode,
    bool clearCountriesError = false,
    String? activityType,
    bool clearActivityType = false,
    SignupTerms? terms,
    bool? loadingTerms,
    String? termsError,
    bool clearTermsError = false,
    bool? termsAccepted,
    List<RequiredTermsVersion>? requiredTerms,
    EmailVerificationChallenge? verification,
  }) => RegisterOwnerState(
    verification: verification ?? this.verification,
    requiredTerms: requiredTerms ?? this.requiredTerms,
    activityType: clearActivityType ? null : (activityType ?? this.activityType),
    terms: terms ?? this.terms,
    loadingTerms: loadingTerms ?? this.loadingTerms,
    termsError: clearTermsError ? null : (termsError ?? this.termsError),
    termsAccepted: termsAccepted ?? this.termsAccepted,
    step: step ?? this.step,
    submit: submit ?? this.submit,
    countries: countries ?? this.countries,
    loadingCountries: loadingCountries ?? this.loadingCountries,
    countriesError: clearCountriesError ? null : (countriesError ?? this.countriesError),
    businessMode: businessMode ?? this.businessMode,
  );
}

/// `POST /api/v2/onboarding/register_owner` — the B2B sign-up. One call
/// creates the user and the organization and returns the session.
class RegisterOwnerCubit extends Cubit<RegisterOwnerState> {
  final AuthRepository _auth;
  final SessionCubit _session;
  final PushService _push;

  RegisterOwnerCubit(this._auth, this._session, this._push) : super(const RegisterOwnerState());

  /// Like the website, a mode change selects that mode's first activity, so
  /// the step always has a valid pair to continue with.
  void chooseMode(String mode) {
    if (mode == state.businessMode) return;
    final options = ActivityType.forMode(mode);
    final String? activity = options.isEmpty ? null : options.first;
    emit(state.copyWith(
      businessMode: mode,
      activityType: activity,
      clearActivityType: activity == null,
      requiredTerms: const [],
      termsAccepted: false,
    ));
  }

  /// The activity decides which joining agreement applies, so a change
  /// drops any list the server named for the previous one.
  void chooseActivity(String? activity) => emit(state.copyWith(
        activityType: activity,
        clearActivityType: activity == null,
        requiredTerms: const [],
        termsAccepted: false,
      ));

  void setTermsAccepted(bool value) => emit(state.copyWith(termsAccepted: value));

  /// `GET /api/terms` — public, so it loads before there is a session.
  Future<void> loadTerms() async {
    if (state.loadingTerms) return;
    emit(state.copyWith(loadingTerms: true, clearTermsError: true));
    final result = await _auth.signupTerms();
    emit(state.copyWith(
      loadingTerms: false,
      terms: result.dataOrNull,
      termsError: result.failureMessage,
    ));
  }

  /// The view validates the current step's fields before calling this.
  void next() {
    if (state.step == RegisterStep.mode && state.activityType == null) return;
    final steps = RegisterStep.values;
    if (state.step.index < steps.length - 1) {
      emit(state.copyWith(step: steps[state.step.index + 1]));
    }
  }

  /// Returns false when there is no step to go back to, so the view can let
  /// the pop through instead of swallowing it.
  bool back() {
    if (state.step == RegisterStep.mode) return false;
    emit(state.copyWith(step: RegisterStep.values[state.step.index - 1]));
    return true;
  }

  void clearMessage() =>
      emit(state.copyWith(submit: state.submit.copyWith(clearMessage: true, bag: const {})));

  /// The country/city pickers have no other source — `GET /api/countries` is
  /// public, so this runs before there is a session.
  Future<void> loadCountries() async {
    if (state.loadingCountries || state.countries.isNotEmpty) return;
    emit(state.copyWith(loadingCountries: true, clearCountriesError: true));

    final result = await _auth.countries();
    emit(
      state.copyWith(
        loadingCountries: false,
        countries: result.dataOrNull ?? const [],
        countriesError: result.failureMessage,
      ),
    );
  }

  Future<void> submit({
    required String firstName,
    required String lastName,
    required String organizationName,
    required String email,
    required String password,
    required int countryId,
    required int cityId,
    String? phone,
    String? whatsapp,
    String? address,
  }) async {
    if (state.submit.isSubmitting || !state.termsAccepted) return;
    final activity = state.activityType;
    if (activity == null) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));
    final termsId = state.terms?.termsVersionId;
    final termsIds = state.requiredTerms.isNotEmpty
        ? state.requiredTerms.map((v) => v.id).toList()
        : [?termsId];

    final result = await _auth.registerOwner(
      businessMode: state.businessMode,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      organizationName: organizationName.trim(),
      email: email.trim(),
      password: password,
      fcmToken: _push.token ?? 'pending',
      countryId: countryId,
      cityId: cityId,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
      activityType: activity,
      acceptedTermsVersionIds: termsIds,
    );

    if (result case Ok(:final data)) {
      // `verify_email=1`: the account exists, the session waits for the code.
      final verification = data.verification;
      if (verification != null) {
        emit(state.copyWith(
          submit: const SubmitState(status: FormStatus.success),
          verification: verification,
        ));
        return;
      }
      // An older server that still answers with a session.
      if (!data.user.hasSession) {
        emit(state.copyWith(submit: SubmitState(
          status: FormStatus.failure,
          message: ErrorMessages.forCode('unexpected_error'),
        )));
        return;
      }
      emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
      await _session.onAuthenticated(data.user, organizationId: data.organizationId);
      return;
    }
    // A newer version went live while the form was open: show it, and make
    // the user tick the box again for the text they are now agreeing to.
    //
    // The same 409 names every version the new organization must accept —
    // the joining agreement for its activity included — which `/api/terms`
    // alone cannot tell us before there is an organization.
    if (result.failureCode == 'terms_version_outdated') {
      final details = switch (result) {
        Failed(:final details) => details,
        _ => null,
      };
      emit(state.copyWith(
        termsAccepted: false,
        submit: result.failureState,
        requiredTerms: asList(details?['terms_versions'], RequiredTermsVersion.fromJson),
      ));
      await loadTerms();
      return;
    }
    // A rejected field sits on an earlier step: go back to the first one
    // that holds an error, where its message is shown under the field.
    final failure = result.failureState;
    final steps = failure.bag.keys.map(RegisterStep.forField).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    emit(state.copyWith(
      submit: failure,
      step: steps.isEmpty ? null : steps.first,
    ));
  }
}
