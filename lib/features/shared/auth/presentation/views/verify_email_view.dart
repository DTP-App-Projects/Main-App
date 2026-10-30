import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/roots/app_router.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/models/auth/auth_user.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../view_models/verify_email_cubit.dart';
import 'widgets/auth_widgets.dart';

/// "Confirm your email" — reached after sign-up (`register_owner` with
/// `verify_email=1`) or from a login of an unconfirmed account (`403
/// email_verification_required`). Either way a code is already in the mail.
///
/// Back leads to login, never to the sign-up form: the account exists, and
/// sending the form again only mails another code (the typed data is ignored).
class VerifyEmailView extends StatelessWidget {
  final EmailVerificationChallenge challenge;

  const VerifyEmailView({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => VerifyEmailCubit(
      getIt<AuthRepository>(),
      getIt<SessionCubit>(),
      getIt<PushService>(),
      challenge,
    ),
    child: const _VerifyEmailBody(),
  );
}

class _VerifyEmailBody extends StatefulWidget {
  const _VerifyEmailBody();

  @override
  State<_VerifyEmailBody> createState() => _VerifyEmailBodyState();
}

class _VerifyEmailBodyState extends State<_VerifyEmailBody> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<VerifyEmailCubit>().verify(_code.text);
  }

  void _toLogin() => context.go(AppRoutes.login);

  int _clearTick = 0;

  void _onState(BuildContext context, VerifyEmailState state) {
    final cubit = context.read<VerifyEmailCubit>();
    // A wrong code empties the boxes for the next try.
    if (state.clearTick != _clearTick) {
      _clearTick = state.clearTick;
      _code.clear();
    }
    final messenger = ScaffoldMessenger.of(context);
    if (state.notice != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.notice!)));
      cubit.clearNotice();
    }
    if (state.alreadyConfirmed) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('auth.verify_email_already'.tr())));
      _toLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLogin();
      },
      child: BlocConsumer<VerifyEmailCubit, VerifyEmailState>(
        listenWhen: (previous, current) =>
            current.notice != null ||
            (current.alreadyConfirmed && !previous.alreadyConfirmed) ||
            current.clearTick != previous.clearTick,
        listener: (context, state) => _onState(context, state),
        builder: (context, state) {
          final cubit = context.read<VerifyEmailCubit>();
          final theme = Theme.of(context);
          final t = context.tokens;

          return Form(
            key: _formKey,
            child: AuthScaffold(
              title: 'auth.verify_email_title'.tr(),
              banner: FormMessage(message: state.submit.message),
              cta: SubmitButton(
                busy: state.submit.isSubmitting || state.submit.isSuccess,
                label: 'auth.verify_email_confirm'.tr(),
                onPressed: _submit,
              ),
              footer: AuthFooterLink(
                question: '',
                action: 'auth.verify_email_other_account'.tr(),
                onPressed: _toLogin,
              ),
              children: [
                // The address reads LTR inside the Arabic sentence.
                Text.rich(
                  TextSpan(
                    text: '${'auth.verify_email_sub'.tr()} ',
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                    children: [
                      TextSpan(
                        // Isolated LTR, so the address keeps its order in Arabic.
                        text:
                            '${String.fromCharCode(0x2066)}${state.email}${String.fromCharCode(0x2069)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space5),
                AppFieldShell(
                  label: 'reset.code'.tr(),
                  bottom: 0,
                  child: AuthCodeBoxes(
                    controller: _code,
                    error: state.submit.fieldError('code'),
                    onChanged: (_) => cubit.clearMessage(),
                    // Six digits in: confirm without a tap.
                    onCompleted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'auth.verify_email_no_code'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ),
                    AppButton.text(
                      busy: state.resending,
                      onPressed: state.canResend ? cubit.resend : null,
                      label: state.resendIn > 0
                          ? 'auth.verify_email_resend_in'.tr(
                              namedArgs: {'seconds': '${state.resendIn}'},
                            )
                          : 'auth.verify_email_resend'.tr(),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mark_email_unread_outlined, size: 16, color: t.textTertiary),
                    const SizedBox(width: AppTokens.space1),
                    Flexible(
                      child: Text(
                        'auth.verify_email_spam'.tr(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
