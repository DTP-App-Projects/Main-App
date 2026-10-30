import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/api_failure_ui.dart';
import '../../../../../core/network/api_result.dart';
import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/form_status.dart';
import '../../../../../data/models/auth/auth_user.dart';
import '../../../../../data/repositories/auth_repository.dart';

/// A new code can be asked for once a minute.
const _resendCooldown = Duration(seconds: 60);

@immutable
class VerifyEmailState {
  final String email;
  final SubmitState submit;

  /// Seconds before Resend works again; `0` means now.
  final int resendIn;

  /// A one-off note for a toast ("We sent a new code…"), consumed by the view.
  final String? notice;

  /// Bumped each time the code field must be emptied (a wrong code).
  final int clearTick;

  /// The account is already confirmed (`not_pending`): the view goes to login.
  final bool alreadyConfirmed;

  final bool resending;

  const VerifyEmailState({
    required this.email,
    this.submit = const SubmitState(),
    this.resendIn = 0,
    this.notice,
    this.clearTick = 0,
    this.alreadyConfirmed = false,
    this.resending = false,
  });

  bool get canResend => resendIn == 0 && !resending && !submit.isSubmitting;

  VerifyEmailState copyWith({
    SubmitState? submit,
    int? resendIn,
    String? notice,
    bool clearNotice = false,
    int? clearTick,
    bool? alreadyConfirmed,
    bool? resending,
  }) =>
      VerifyEmailState(
        email: email,
        submit: submit ?? this.submit,
        resendIn: resendIn ?? this.resendIn,
        notice: clearNotice ? null : (notice ?? this.notice),
        clearTick: clearTick ?? this.clearTick,
        alreadyConfirmed: alreadyConfirmed ?? this.alreadyConfirmed,
        resending: resending ?? this.resending,
      );
}

/// Confirms a new account's email with the mailed 6-digit code.
///
/// `POST /auth/email/verify` answers exactly like a successful login, so a
/// right code ends in [SessionCubit.onAuthenticated] — the router then takes
/// the user wherever a login would. Nothing here is persisted: an app killed
/// on this screen gets a fresh code at the next login (`403
/// email_verification_required`), and the password is never kept.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  final AuthRepository _auth;
  final SessionCubit _session;
  final PushService _push;
  Timer? _cooldown;

  VerifyEmailCubit(this._auth, this._session, this._push, EmailVerificationChallenge challenge)
      : super(VerifyEmailState(email: challenge.email)) {
    if (challenge.codeSent) {
      _startCooldown(_resendCooldown);
    } else {
      // The account exists but the mail did not go out: say so, and leave
      // Resend enabled straight away.
      emit(state.copyWith(
        submit: SubmitState(
          status: FormStatus.failure,
          message: challenge.message.isNotEmpty
              ? challenge.message
              : 'auth.verify_email_not_sent'.tr(),
        ),
      ));
    }
  }

  /// Arabic-Indic (٠-٩) and Persian (۰-۹) digits become ASCII; spaces go.
  @visibleForTesting
  static String normalizeCode(String raw) {
    final out = StringBuffer();
    for (final rune in raw.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune >= 0x30 && rune <= 0x39) {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  Future<void> verify(String raw) async {
    final code = normalizeCode(raw);
    if (state.submit.isSubmitting || code.length != 6) return;
    emit(state.copyWith(submit: const SubmitState(status: FormStatus.submitting)));

    final result = await _auth.verifyEmail(
      email: state.email,
      code: code,
      fcmToken: _push.token ?? 'pending',
    );
    if (isClosed) return;

    switch (result) {
      case Ok<AuthUser>(:final data) when data.hasSession:
        emit(state.copyWith(submit: const SubmitState(status: FormStatus.success)));
        _cooldown?.cancel();
        // Same as after a login: save the session; the router picks the screen.
        await _session.onAuthenticated(data);

      case Failed<AuthUser>(:final code) when code == 'not_pending':
        emit(state.copyWith(
          submit: const SubmitState(),
          alreadyConfirmed: true,
        ));

      case Failed<AuthUser>(:final code) when code == 'invalid_code':
        _wrongCode();

      case RateLimited<AuthUser>():
        emit(state.copyWith(
          submit: SubmitState(
            status: FormStatus.failure,
            message: 'auth.verify_email_too_many'.tr(),
          ),
        ));

      // A 200 without a `jwt` is not a confirmed account, whatever it says.
      case Ok<AuthUser>():
      case NoContent<AuthUser>():
        _wrongCode();

      default:
        emit(state.copyWith(submit: result.failureState));
    }
  }

  void _wrongCode() => emit(state.copyWith(
        submit: SubmitState(
          status: FormStatus.failure,
          message: 'auth.verify_email_invalid'.tr(),
        ),
        clearTick: state.clearTick + 1,
      ));

  Future<void> resend() async {
    if (!state.canResend) return;
    emit(state.copyWith(resending: true, submit: const SubmitState()));

    final result = await _auth.resendEmailCode(state.email);
    if (isClosed) return;

    switch (result) {
      case Ok<EmailVerificationChallenge>(:final data) when data.codeSent:
        emit(state.copyWith(
          resending: false,
          notice: data.message.isNotEmpty ? data.message : 'auth.verify_email_sent'.tr(),
        ));
        _startCooldown(_resendCooldown);

      case Ok<EmailVerificationChallenge>(:final data):
        emit(state.copyWith(
          resending: false,
          submit: SubmitState(
            status: FormStatus.failure,
            message: data.message.isNotEmpty ? data.message : 'auth.verify_email_not_sent'.tr(),
          ),
        ));

      // `resend_too_soon` says how long; the limiter's plain 429 may not —
      // either way the countdown restarts rather than an error showing.
      case RateLimited<EmailVerificationChallenge>(:final retryAfter):
        emit(state.copyWith(resending: false));
        _startCooldown(retryAfter);

      case Failed<EmailVerificationChallenge>(:final code) when code == 'not_pending':
        emit(state.copyWith(resending: false, alreadyConfirmed: true));

      default:
        emit(state.copyWith(resending: false, submit: result.failureState));
    }
  }

  void clearMessage() {
    if (state.submit.message == null && state.submit.bag.isEmpty) return;
    emit(state.copyWith(submit: const SubmitState()));
  }

  void clearNotice() => emit(state.copyWith(clearNotice: true));

  void _startCooldown(Duration duration) {
    _cooldown?.cancel();
    emit(state.copyWith(resendIn: duration.inSeconds));
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final left = state.resendIn - 1;
      if (left <= 0) timer.cancel();
      emit(state.copyWith(resendIn: left < 0 ? 0 : left));
    });
  }

  @override
  Future<void> close() {
    _cooldown?.cancel();
    return super.close();
  }
}
