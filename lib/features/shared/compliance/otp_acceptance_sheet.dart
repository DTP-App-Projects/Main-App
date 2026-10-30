import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/i18n/app_dates.dart';
import '../../../core/network/api_result.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/compliance/acceptance.dart';
import '../../../data/repositories/compliance_repository.dart';

/// The level-2 acceptance, used by every document that needs one:
///
/// 1. `POST /acceptance_challenges {document_type, document_id}` sends a code;
/// 2. the user types it;
/// 3. [submit] posts it as `otp_code` to the document's own action endpoint.
///
/// Resolves to `true` only when [submit] succeeded. A rejection — wrong code,
/// not the authorized signatory, a business rule — stays on the sheet with the
/// server's message so the user can correct it or back out.
Future<bool> showOtpAcceptance(
  BuildContext context, {
  required String documentType,
  required int documentId,
  required String title,
  String? subtitle,
  String? confirmLabel,
  required Future<ApiResult<Object?>> Function(String otpCode) submit,
}) async {
  final accepted = await showAppSheet<bool>(
    context: context,
    title: title,
    subtitle: subtitle,
    builder: (_) => OtpAcceptancePanel(
      documentType: documentType,
      documentId: documentId,
      confirmLabel: confirmLabel,
      submit: submit,
      repository: getIt<ComplianceRepository>(),
    ),
  );
  return accepted ?? false;
}

/// The sheet's body, public so it can be pumped on its own in tests.
class OtpAcceptancePanel extends StatefulWidget {
  final String documentType;
  final int documentId;
  final String? confirmLabel;
  final Future<ApiResult<Object?>> Function(String otpCode) submit;
  final ComplianceRepository repository;

  /// One new code a minute: the server allows 6 challenges a minute, and
  /// each new code replaces the previous one.
  final Duration resendCooldown;

  const OtpAcceptancePanel({
    super.key,
    required this.documentType,
    required this.documentId,
    required this.submit,
    required this.repository,
    this.confirmLabel,
    this.resendCooldown = const Duration(seconds: 60),
  });

  @override
  State<OtpAcceptancePanel> createState() => _OtpAcceptancePanelState();
}

class _OtpAcceptancePanelState extends State<OtpAcceptancePanel> {
  final _code = TextEditingController();

  AcceptanceChallenge? _challenge;
  bool _sending = false;
  bool _submitting = false;
  String? _error;

  /// The server said this user cannot decide here (not the signatory, no
  /// permission, already decided, not a party): the message stays, the
  /// inputs go. The caller reloads the document when the sheet closes.
  bool _blocked = false;

  /// Codes are six digits.
  static const _codeLength = 6;

  static const _blockingCodes = {
    'signatory_required',
    'authorized_signatory_required',
    'permission_denied',
    'relationship_request_not_pending',
    'relationship_request_own_side',
    'not_a_party',
  };

  /// A dead code: ask for a new one at once.
  static const _deadCodes = {'otp_expired', 'otp_too_many_attempts', 'otp_not_requested'};
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await widget.repository.requestChallenge(
      documentType: widget.documentType,
      documentId: widget.documentId,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result case Ok(:final data)) {
        _challenge = data;
      } else {
        _error = result.failureMessage;
      }
    });
    if (result is Ok) {
      // «أرسلنا الرمز إلى …», the moment it happens.
      final destination = result.dataOrNull?.destination ?? '';
      if (destination.isNotEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text('acceptance.code_sent'.tr(namedArgs: {'destination': destination})),
        ));
      }
      _startCooldown(widget.resendCooldown);
    } else if (result is RateLimited<AcceptanceChallenge>) {
      _startCooldown(result.retryAfter);
    } else {
      // `otp_send_failed` / `otp_no_channel`: the button stays usable.
      if (_blockingCodes.contains(result.failureCode)) setState(() => _blocked = true);
      setState(() => _resendIn = 0);
    }
  }

  void _startCooldown(Duration wait) {
    _timer?.cancel();
    setState(() => _resendIn = wait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) timer.cancel();
    });
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (code.length != _codeLength) {
      setState(() => _error = 'acceptance.code_required'.tr());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.submit(code);
    if (!mounted) return;
    if (result is Ok || result is NoContent) {
      Navigator.of(context).pop(true);
      return;
    }
    final failure = result.failureCode;
    setState(() {
      _submitting = false;
      _error = result.failureMessage;
      if (failure == 'otp_invalid' || _deadCodes.contains(failure)) _code.clear();
      if (_deadCodes.contains(failure)) {
        // «اضغط إرسال رمز التحقق مرة أخرى» — enabled straight away.
        _timer?.cancel();
        _resendIn = 0;
        _challenge = null;
      }
      if (_blockingCodes.contains(failure)) _blocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final challenge = _challenge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_sending && challenge == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.space4),
            child: Skeleton(height: 18),
          )
        else if (challenge != null)
          Text(
            'acceptance.code_sent'.tr(namedArgs: {
              'destination': challenge.destination.isEmpty ? '—' : challenge.destination,
            }),
            style: theme.textTheme.bodyMedium,
          ),
        if (challenge?.expiresAt != null) ...[
          const SizedBox(height: AppTokens.space1),
          Text(
            'acceptance.expires_at'.tr(namedArgs: {
              'time': AppDates.riyadh(challenge!.expiresAt, locale),
            }),
            style: theme.textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: AppTokens.space4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _code,
            autofocus: true,
            enabled: !_submitting && !_blocked,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: InputDecoration(hintText: 'acceptance.code_hint'.tr()),
            onSubmitted: (_) => _confirm(),
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton.text(
            label: _resendIn > 0
                ? 'acceptance.resend_in'.tr(namedArgs: {'seconds': '$_resendIn'})
                : 'acceptance.resend'.tr(),
            onPressed: (_resendIn > 0 || _sending || _submitting || _blocked) ? null : _send,
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        FormMessage(message: _error),
        // The legal sentence sits directly above the button that performs the
        // binding act (spec §4) — never move it below or into a tooltip, and
        // never call this act «توقيع إلكتروني معتمد» or «مصدّق».
        Container(
          padding: const EdgeInsets.all(AppTokens.space3),
          margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
          decoration: BoxDecoration(color: t.neutralTint, borderRadius: AppTokens.mdRadius),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: t.textSecondary),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: Text(
                  'acceptance.otp_legal'.tr(),
                  key: const Key('otp_legal_sentence'),
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
        SubmitButton(
          busy: _submitting,
          label: widget.confirmLabel ?? 'acceptance.confirm'.tr(),
          icon: Icons.lock_outline_rounded,
          // Disabled until a code was requested and six digits are in.
          onPressed: (_submitting || _blocked || challenge == null || _code.text.trim().length != _codeLength)
              ? null
              : _confirm,
        ),
      ],
    );
  }
}
