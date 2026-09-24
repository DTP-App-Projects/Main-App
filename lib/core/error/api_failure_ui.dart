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
        invalid: (_) => 'errors.validation_error'.tr(),
        failed: (code, status, _) => ErrorMessages.forCode(code, status: status),
        wrongWorkspace: () => ErrorMessages.forCode('unexpected_error'),
        offline: () => ErrorMessages.forCode('offline'),
        rateLimited: (_) => ErrorMessages.forCode('rate_limited'),
        sessionExpired: () => ErrorMessages.forCode('unexpected_error'),
      );

  /// True only for [Offline], so a screen can show the offline state rather
  /// than a generic error with a retry that will fail the same way.
  bool get isOffline => this is Offline<T>;

  /// A form-level failure, with the server's `bag` mapped onto field slots.
  SubmitState get failureState => when(
        ok: (_) => const SubmitState(status: FormStatus.success),
        noContent: () => const SubmitState(status: FormStatus.success),
        invalid: (bag) => SubmitState(
          status: FormStatus.failure,
          message: 'errors.validation_error'.tr(),
          bag: bag,
        ),
        failed: (code, status, _) => SubmitState(
          status: FormStatus.failure,
          message: ErrorMessages.forCode(code, status: status),
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
