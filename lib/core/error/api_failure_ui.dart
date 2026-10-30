import 'package:easy_localization/easy_localization.dart';

import '../network/api_result.dart';
import '../ui/form_status.dart';
import 'error_messages.dart';

/// Turning a non-`Ok` [ApiResult] into something a user can read is the same
/// eight-way decision on every screen. It lives here once.
extension ApiResultUi<T> on ApiResult<T> {
  /// Localized copy for a failure. Returns `null` for the success cases, so a
  /// caller that has already handled them gets a compile-time-shaped hint
  /// rather than a bogus error message.
  String? get failureMessage => when(
        ok: (_) => null,
        noContent: () => null,
        invalid: (_) => _invalidSummary ?? 'errors.validation_error'.tr(),
        failed: (code, status, _) => _failedMessage(code, status),
        wrongWorkspace: () => ErrorMessages.forCode('unexpected_error'),
        offline: () => ErrorMessages.forCode('offline'),
        rateLimited: (_) => ErrorMessages.forCode('rate_limited'),
        sessionExpired: () => ErrorMessages.forCode('unexpected_error'),
      );

  /// The server's `text`, else the first bag message — never a generic
  /// "check all fields" when the server said what is wrong.
  String? get _invalidSummary {
    final self = this;
    return self is Invalid<T> ? self.summary : null;
  }

  /// A `permission_denied` names the permission it lacked; when the app has
  /// copy for that one («ليست لديك صلاحية إدارة العلاقات»), it says so.
  String _failedMessage(String code, int status) {
    final self = this;
    if (code == 'permission_denied' && self is Failed<T> && (self.permission ?? '').isNotEmpty) {
      final key = 'errors.permission_${self.permission!.replaceAll('.', '_')}';
      final specific = key.tr();
      if (specific != key) return specific;
    }
    return ErrorMessages.forCode(code, status: status, serverMessage: _serverMessage);
  }

  String? get _serverMessage {
    final self = this;
    return self is Failed<T> ? self.message : null;
  }

  /// The stable code of a [Failed], for branching. Empty for anything else.
  String get failureCode {
    final self = this;
    return self is Failed<T> ? self.code : '';
  }

  /// True only for [Offline], so a screen can show the offline state rather
  /// than a generic error with a retry that will fail the same way.
  bool get isOffline => this is Offline<T>;

  /// A form-level failure, with the server's `bag` mapped onto field slots.
  SubmitState get failureState => when(
        ok: (_) => const SubmitState(status: FormStatus.success),
        noContent: () => const SubmitState(status: FormStatus.success),
        invalid: (bag) => SubmitState(
          status: FormStatus.failure,
          message: _invalidSummary ?? 'errors.validation_error'.tr(),
          bag: bag,
        ),
        failed: (code, status, _) => SubmitState(
          status: FormStatus.failure,
          message: _failedMessage(code, status),
        ),
        wrongWorkspace: () => SubmitState(
          status: FormStatus.failure,
          message: ErrorMessages.forCode('unexpected_error'),
        ),
        offline: () => SubmitState(
          status: FormStatus.failure,
          message: ErrorMessages.forCode('offline'),
        ),
        rateLimited: (_) => SubmitState(
          status: FormStatus.failure,
          message: ErrorMessages.forCode('rate_limited'),
        ),
        sessionExpired: () => SubmitState(
          status: FormStatus.failure,
          message: ErrorMessages.forCode('unexpected_error'),
        ),
      );
}
