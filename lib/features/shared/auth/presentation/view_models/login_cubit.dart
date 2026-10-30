import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/error/error_messages.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/form_status.dart';
import '../../../../../data/models/auth/auth_user.dart';
import '../../../../../data/repositories/auth_repository.dart';

class LoginCubit extends Cubit<SubmitState> {
  final AuthRepository _auth;
  final SessionCubit _session;
  final PushService _push;

  LoginCubit(this._auth, this._session, this._push) : super(const SubmitState());

  /// Set when the password was right but the email is not confirmed yet —
  /// the server has already mailed a fresh code. The view takes it (once)
  /// and opens the Confirm email screen.
  EmailVerificationChallenge? _verification;

  EmailVerificationChallenge? takeVerification() {
    final challenge = _verification;
    _verification = null;
    return challenge;
  }

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(const SubmitState(status: FormStatus.submitting));

    final result = await _auth.login(
      email: email.trim(),
      password: password,
      // Login and register both require a device token. If FCM has not
      // answered yet, a placeholder keeps the user out of a dead end — the
      // real token is registered again as soon as bootstrap resolves.
      fcmToken: _push.token ?? 'pending',
    );

    switch (result) {
      // `email_verify_pending`: the code screen, never a session — checked
      // before the session case because the answer may still carry a jwt.
      case Ok<AuthUser>(:final data) when data.emailVerifyPending:
        _verification = EmailVerificationChallenge(
          email: data.email.isEmpty ? email.trim() : data.email,
        );
        emit(const SubmitState(status: FormStatus.success));

      case Ok<AuthUser>(:final data) when data.hasSession:
        emit(const SubmitState(status: FormStatus.success));
        await _session.onAuthenticated(data);

      // A 200 with no `jwt`, or with no body at all: not a session, whatever
      // the status line said.
      case Ok<AuthUser>():
      case NoContent<AuthUser>():
        emit(
          SubmitState(
            status: FormStatus.failure,
            message: ErrorMessages.forCode('unexpected_error'),
          ),
        );

      // `403 email_verification_required` — checked before anything generic:
      // it is neither an expired session nor an error to show.
      case Failed<AuthUser>(:final code, :final details)
          when EmailVerificationChallenge.isCode(code) ||
              EmailVerificationChallenge.matches(details ?? const {}):
        final challenge = EmailVerificationChallenge.fromJson(details ?? const {});
        _verification = EmailVerificationChallenge(
          email: challenge.email.isEmpty ? email.trim() : challenge.email,
          codeSent: challenge.codeSent,
          expiresInSeconds: challenge.expiresInSeconds,
          message: challenge.message,
        );
        emit(const SubmitState(status: FormStatus.success));

      // Covers `401 invalid_email` / `invalid_password` and the suspended
      // account, which the server returns as a 200 with `status: failed`.
      default:
        emit(result.failureState);
    }
  }

  /// Called as soon as the user edits either field.
  ///
  /// A rejected credential's message used to sit on screen while they retyped,
  /// which reads as though the new attempt had already failed too.
  void clearMessage() {
    if (state.message == null && state.bag.isEmpty) return;
    emit(state.copyWith(clearMessage: true, bag: const {}));
  }
}
