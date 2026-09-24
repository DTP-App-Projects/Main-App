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
