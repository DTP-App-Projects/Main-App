import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/error/error_messages.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/session/session_store.dart';
import '../../../../../core/ui/form_status.dart';
import '../../../../../data/repositories/auth_repository.dart';

enum ResetStep { request, verify, choose, done }

/// The server throttles the code request at `6,1`. A minute between taps keeps
/// a user well inside that without the app having to explain a 429.
const _resendCooldown = Duration(seconds: 60);

@immutable
class PasswordResetState {
  final ResetStep step;
  final SubmitState submit;
  final String email;

  /// Seconds left before the code can be requested again; `0` means now.
  final int resendIn;

  const PasswordResetState({
    this.step = ResetStep.request,
    this.submit = const SubmitState(),
    this.email = '',
    this.resendIn = 0,
  });

  bool get canResend => resendIn == 0 && !submit.isSubmitting;

  PasswordResetState copyWith({
    ResetStep? step,
    SubmitState? submit,
    String? email,
    int? resendIn,
  }) => PasswordResetState(
    step: step ?? this.step,
    submit: submit ?? this.submit,
    email: email ?? this.email,
    resendIn: resendIn ?? this.resendIn,
  );
}

/// Three calls, in order: `forgot` → `verify_code` → `reset`.
///
/// The catch is step two: it hands back the user's **real** `jwt`, and step
/// three is authenticated with it. That token is held in memory only — see
/// [SessionStore.useEphemeralJwt]. Persisting it, which is what this used to
/// do, meant abandoning the flow at "choose a new password" left a live
/// session on disk for the next cold start to restore, with the old password
/// still working.
class PasswordResetCubit extends Cubit<PasswordResetState> {
  final AuthRepository _auth;
  final SessionStore _store;

  Timer? _cooldown;

  PasswordResetCubit(this._auth, this._store) : super(const PasswordResetState());

  Future<void> requestCode(String email) async {
    if (state.submit.isSubmitting) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _auth.forgotPassword(email.trim());
    _handle(
      result,
      onSuccess: () {
        emit(
          state.copyWith(step: ResetStep.verify, email: email.trim(), submit: const SubmitState()),
        );
        _startCooldown();
      },
    );
  }

  /// Asks for a fresh code for the address already captured, without sending
  /// the user back a step to retype it.
  Future<void> resendCode() async {
    if (!state.canResend || state.email.isEmpty) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _auth.forgotPassword(state.email);
    _handle(
      result,
      onSuccess: () {
        emit(state.copyWith(submit: const SubmitState(status: FormStatus.success, message: null)));
        _startCooldown();
      },
    );
  }

  Future<void> verifyCode(String code) async {
    if (state.submit.isSubmitting) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _auth.verifyResetCode(code.trim());

    if (result case Ok(:final data)) {
      if (!data.hasSession) {
        // A 200 with no `jwt` is not a verified code, whatever it says.
        _failWith('invalid_code');
        return;
      }
      // In memory only: nobody is signed in until they have finished choosing
      // a password.
      _store.useEphemeralJwt(data.jwt);
      emit(state.copyWith(step: ResetStep.choose, submit: const SubmitState()));
      return;
    }
    _handle(result, onSuccess: () {});
  }

  Future<void> setPassword(String password) async {
    if (state.submit.isSubmitting) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _auth.resetPassword(password);
    if (result is Ok || result is NoContent) {
      // Hand the borrowed token back. The user signs in fresh with the
      // password they just chose.
      _store.clearEphemeralJwt();
      emit(
        state.copyWith(
          step: ResetStep.done,
          submit: const SubmitState(status: FormStatus.success),
        ),
      );
      return;
    }
    _handle(result, onSuccess: () {});
  }

  void _handle<T>(ApiResult<T> result, {required void Function() onSuccess}) {
    if (result is Ok<T> || result is NoContent<T>) {
      onSuccess();
      return;
    }
    // Step three runs on the token borrowed from step two; if that is already
    // gone the flow has to restart from the code.
    if (result is SessionExpired<T>) {
      _store.clearEphemeralJwt();
      _failWith('invalid_code', step: ResetStep.verify);
      return;
    }
    emit(state.copyWith(submit: result.failureState));
  }

  void _failWith(String code, {int status = 0, ResetStep? step}) => emit(
    state.copyWith(
      step: step ?? state.step,
      submit: SubmitState(
        status: FormStatus.failure,
        message: ErrorMessages.forCode(code, status: status),
      ),
    ),
  );

  void _startCooldown() {
    _cooldown?.cancel();
    emit(state.copyWith(resendIn: _resendCooldown.inSeconds));
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.resendIn - 1;
      if (left <= 0) timer.cancel();
      if (!isClosed) emit(state.copyWith(resendIn: left < 0 ? 0 : left));
    });
  }

  void clearMessage() =>
      emit(state.copyWith(submit: state.submit.copyWith(clearMessage: true, bag: const {})));

  @override
  Future<void> close() {
    _cooldown?.cancel();
    // Leaving the flow half-finished must not leave the borrowed token
    // usable — this is the abandon path the old code had no answer for.
    _store.clearEphemeralJwt();
    return super.close();
  }
}
