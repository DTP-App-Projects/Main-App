import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../data/models/common/country.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../../../../../core/ui/form_status.dart';

/// Sign-up is two screens, and which one you are on is state like anything
/// else. It used to live in the view's `setState` while the mode it depends on
/// lived here, which split one decision across two owners.
enum RegisterStep { mode, details }

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

  const RegisterOwnerState({
    this.step = RegisterStep.mode,
    this.submit = const SubmitState(),
    this.countries = const [],
    this.loadingCountries = false,
    this.countriesError,
    this.businessMode = 'trader',
  });

  RegisterOwnerState copyWith({
    RegisterStep? step,
    SubmitState? submit,
    List<Country>? countries,
    bool? loadingCountries,
    String? countriesError,
    String? businessMode,
    bool clearCountriesError = false,
  }) => RegisterOwnerState(
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

  void chooseMode(String mode) => emit(state.copyWith(businessMode: mode));

  void toDetails() => emit(state.copyWith(step: RegisterStep.details));

  /// Returns false when there is no step to go back to, so the view can let
  /// the pop through instead of swallowing it.
  bool back() {
    if (state.step == RegisterStep.mode) return false;
    emit(state.copyWith(step: RegisterStep.mode));
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
    if (state.submit.isSubmitting) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

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
    );

    if (result case Ok(:final data)) {
      emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
      await _session.onAuthenticated(data.user, organizationId: data.organizationId);
      return;
    }
    emit(state.copyWith(submit: result.failureState));
  }
}
