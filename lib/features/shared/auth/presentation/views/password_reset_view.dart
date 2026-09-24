import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../../core/session/session_store.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/roots/app_router.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../view_models/password_reset_cubit.dart';
import 'widgets/auth_widgets.dart';

/// Three server calls in order: `forgot` → `verify_code` → `reset`.
///
/// One route holds all three, because step two hands back a token that step
/// three needs — and closing this cubit is what hands it back, so the flow
/// must not be split across routes that can be popped independently.
class PasswordResetView extends StatelessWidget {
  const PasswordResetView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PasswordResetCubit(getIt<AuthRepository>(), getIt<SessionStore>()),
    child: const _ResetFlow(),
  );
}

class _ResetFlow extends StatelessWidget {
  const _ResetFlow();

  @override
  Widget build(BuildContext context) => BlocBuilder<PasswordResetCubit, PasswordResetState>(
    builder: (context, state) => switch (state.step) {
      ResetStep.request => const _RequestStep(),
      ResetStep.verify => const _VerifyStep(),
      ResetStep.choose => const _ChooseStep(),
      ResetStep.done => const _DoneStep(),
    },
  );
}

class _RequestStep extends StatefulWidget {
  const _RequestStep();

  @override
  State<_RequestStep> createState() => _RequestStepState();
}

class _RequestStepState extends State<_RequestStep> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PasswordResetCubit>();
    final state = context.watch<PasswordResetCubit>().state;

    return Form(
      key: _formKey,
      child: AuthScaffold(
        step: (1, 3),
        title: 'reset.forgot_title'.tr(),
        subtitle: 'reset.forgot_body'.tr(),
        banner: FormMessage(message: state.submit.message),
        cta: SubmitButton(
          busy: state.submit.isSubmitting,
          label: 'reset.send_code'.tr(),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            FocusScope.of(context).unfocus();
            cubit.requestCode(_email.text);
          },
        ),
        footer: AuthFooterLink(
          question: 'auth.have_account'.tr(),
          action: 'auth.sign_in'.tr(),
          onPressed: () => context.go(AppRoutes.login),
        ),
        children: [
          AppField(
            controller: _email,
            label: 'auth.email'.tr(),
            required: true,
            icon: Icons.mail_outline_rounded,
            hint: 'auth.email_hint'.tr(),
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.username],
            validator: AppValidators.email,
            serverError: state.submit.fieldError('email'),
            onChanged: (_) => cubit.clearMessage(),
          ),
        ],
      ),
    );
  }
}

class _VerifyStep extends StatefulWidget {
  const _VerifyStep();

  @override
  State<_VerifyStep> createState() => _VerifyStepState();
}

class _VerifyStepState extends State<_VerifyStep> {
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
    context.read<PasswordResetCubit>().verifyCode(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PasswordResetCubit>();
    final state = context.watch<PasswordResetCubit>().state;
    final serverError = state.submit.fieldError('code');

    return Form(
      key: _formKey,
      child: AuthScaffold(
        step: (2, 3),
        title: 'reset.code_title'.tr(),
        subtitle: 'reset.code_body'.tr(namedArgs: {'email': state.email}),
        banner: FormMessage(message: state.submit.message),
        cta: SubmitButton(
          busy: state.submit.isSubmitting,
          label: 'reset.verify'.tr(),
          onPressed: _submit,
        ),
        children: [
          AppFieldShell(
            label: 'reset.code'.tr(),
            bottom: 0,
            child: _OtpBoxes(
              controller: _code,
              error: serverError,
              onChanged: (_) => cubit.clearMessage(),
              onCompleted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          // A code that never arrives used to be a dead end — the only way
          // back was to leave and start over.
          Center(
            child: AppButton.text(
              onPressed: state.canResend ? cubit.resendCode : null,
              label: state.resendIn > 0
                  ? 'reset.resend_in'.tr(args: ['${state.resendIn}'])
                  : 'reset.resend'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six Driver-style boxes for the mailed code. Digits read LTR in both
/// languages; the platform can still autofill it from the notification.
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  const _OtpBoxes({
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final hasError = error != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = ((constraints.maxWidth - 5 * AppTokens.space2) / 6).clamp(36.0, 52.0);
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: controller,
                // The controller belongs to the step's State.
                autoDisposeControllers: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                animationType: AnimationType.fade,
                enableActiveFill: true,
                autoFocus: true,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                cursorColor: t.primary,
                textStyle: theme.textTheme.titleLarge,
                errorTextSpace: 22,
                errorTextDirection: Directionality.of(context),
                validator: (value) => (value == null || value.trim().length != 6)
                    ? 'validation.code_length'.tr()
                    : null,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: AppTokens.mdRadius,
                  fieldHeight: box + 4,
                  fieldWidth: box,
                  borderWidth: 1,
                  activeBorderWidth: 1.5,
                  selectedBorderWidth: 1.5,
                  activeColor: hasError ? t.fieldError : t.primary,
                  selectedColor: t.primary,
                  inactiveColor: hasError ? t.fieldError : t.inputBorder,
                  activeFillColor: t.inputFill,
                  selectedFillColor: t.surface,
                  inactiveFillColor: t.inputFill,
                  errorBorderColor: t.fieldError,
                ),
                onChanged: onChanged,
                onCompleted: onCompleted,
              ),
              if (hasError)
                Text(
                  error!,
                  textDirection: Directionality.of(context),
                  style: theme.textTheme.labelSmall?.copyWith(color: t.fieldError),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChooseStep extends StatefulWidget {
  const _ChooseStep();

  @override
  State<_ChooseStep> createState() => _ChooseStepState();
}

class _ChooseStepState extends State<_ChooseStep> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PasswordResetCubit>();
    final state = context.watch<PasswordResetCubit>().state;

    return Form(
      key: _formKey,
      child: AuthScaffold(
        step: (3, 3),
        // No back arrow: the verified code is spent, so there is nothing
        // behind this screen to return to.
        showBack: false,
        title: 'reset.new_title'.tr(),
        subtitle: 'reset.new_body'.tr(),
        banner: FormMessage(message: state.submit.message),
        cta: SubmitButton(
          busy: state.submit.isSubmitting,
          label: 'reset.submit'.tr(),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            FocusScope.of(context).unfocus();
            TextInput.finishAutofillContext();
            cubit.setPassword(_password.text);
          },
        ),
        children: [
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppField(
                  controller: _password,
                  label: 'reset.new_password'.tr(),
                  required: true,
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  helper: 'validation.password_min'.tr(),
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AppValidators.password,
                  serverError: state.submit.fieldError('password'),
                  onChanged: (_) => cubit.clearMessage(),
                ),
                AppField(
                  controller: _confirm,
                  label: 'reset.confirm_password'.tr(),
                  required: true,
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      value == _password.text ? null : 'validation.password_match'.tr(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) => AuthScaffold(
    showBack: false,
    plain: true,
    title: 'reset.done'.tr(),
    subtitle: 'reset.done_body'.tr(),
    cta: SubmitButton(
      busy: false,
      label: 'auth.sign_in'.tr(),
      // The borrowed token was handed back on success, so this lands on
      // the login screen and the new password is the only way in.
      onPressed: () => context.go(AppRoutes.login),
    ),
    children: const [
      SizedBox(height: AppTokens.space4),
      Center(child: AppIconCircle(Icons.check_rounded, size: 96, iconSize: 44)),
    ],
  );
}
