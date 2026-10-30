import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/push/push_service.dart';
import '../../../../../core/session/session_cubit.dart';
import '../../../../../core/ui/form_status.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/roots/app_router.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/repositories/auth_repository.dart';
import '../view_models/login_cubit.dart';
import 'widgets/auth_widgets.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoginCubit(getIt<AuthRepository>(), getIt<SessionCubit>(), getIt<PushService>()),
    child: const _LoginBody(),
  );
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // Tells the platform the credential is worth offering to save. Without
    // it the keychain sees a form that was filled and abandoned.
    TextInput.finishAutofillContext();
    context.read<LoginCubit>().submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    // Routing after a successful login is the router's job — SessionCubit
    // flips to authenticated and the redirect picks the shell.
    return BlocConsumer<LoginCubit, SubmitState>(
      // Right password, unconfirmed email: the server already mailed a code.
      listener: (context, state) {
        final challenge = context.read<LoginCubit>().takeVerification();
        if (challenge != null) context.go(AppRoutes.verifyEmail, extra: challenge);
      },
      builder: (context, state) {
        final cubit = context.read<LoginCubit>();

        return Form(
          key: _formKey,
          child: AuthScaffold(
            showBack: false,
            showLogo: true,
            title: 'auth.welcome'.tr(),
            subtitle: 'auth.subtitle'.tr(),
            banner: FormMessage(message: state.message),
            cta: SubmitButton(
              busy: state.isSubmitting,
              label: 'auth.sign_in'.tr(),
              onPressed: _submit,
            ),
            footer: AuthFooterLink(
              question: 'auth.no_account'.tr(),
              action: 'auth.create_account'.tr(),
              onPressed: () => context.push(AppRoutes.register),
            ),
            children: [
              // One group, so the platform treats the pair as a credential
              // rather than two unrelated text fields.
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppField(
                      controller: _email,
                      label: 'auth.email'.tr(),
                      required: true,
                      icon: Icons.mail_outline_rounded,
                      hint: 'auth.email_hint'.tr(),
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      validator: AppValidators.email,
                      serverError: state.fieldError('email'),
                      onChanged: (_) => cubit.clearMessage(),
                    ),
                    AppField(
                      controller: _password,
                      label: 'auth.password'.tr(),
                      required: true,
                      icon: Icons.lock_outline_rounded,
                      hint: '••••••••',
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: AppValidators.password,
                      serverError: state.fieldError('password'),
                      onChanged: (_) => cubit.clearMessage(),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AppButton.text(
                  label: 'auth.forgot_password'.tr(),
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  height: 40,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
