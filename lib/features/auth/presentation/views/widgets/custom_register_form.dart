import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal/core/shared_widgets/loading_dialog.dart';
import 'package:digital_trade_portal/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_cubit.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_states.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/login/login_cubit.dart';
import 'package:digital_trade_portal/features/auth/presentation/views/verification_view.dart';
import 'package:digital_trade_portal/features/auth/presentation/views/widgets/custom_phone_field.dart';

class CustomRegisterForm extends StatefulWidget {
  const CustomRegisterForm({super.key});

  @override
  State<CustomRegisterForm> createState() => _CustomRegisterFormState();
}

class _CustomRegisterFormState extends State<CustomRegisterForm> {
  TextEditingController phone = TextEditingController();
  var formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocBuilder<AuthCubit, AuthStates>(
          builder: (context, state) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "phoneNumber".tr(),
                        style: Styles.font12MediumBlack(context).copyWith(color: AppColors.grey46),
                      ),
                      Text("*", style: Styles.font12MediumBlack(context).copyWith(color: const Color(0xffC11102))),
                    ],
                  ),
                  SizedBox(height: AppConstants.height5(context)),
                  CustomPhoneField(phoneController: phone, isLogin: false),
                  SizedBox(height: AppConstants.height15(context)),
                  BlocProvider(
                    create: (context) => LoginCubit(getIt.get<AuthRepoImpl>()),
                    child: BlocConsumer<LoginCubit, LoginState>(
                      listener: (context, state) {
                        if (state is LoginLoadingState) {
                          LoadingDialog().show(context);
                        } else if (state is LoginSuccessState) {
                          LoadingDialog().hide();
                          toast(text: state.model.message ?? "", context: context);
                          NavigationUtils.navigateTo(
                            context: context,
                            destinationScreen: VerificationView(phone: phone.text, requestId: state.model.requestId!),
                          );
                          phone.clear();
                          context.read<AuthCubit>().checkRegisterPhoneLength(length: 0);
                        } else if (state is LoginErrorState) {
                          LoadingDialog().hide();
                          toast(text: state.errMessage, context: context, isSuccess: false);
                        }
                      },
                      builder: (context, state) {
                        return DefaultButton(
                          onPress: () {
                            if (context.read<AuthCubit>().registerPhoneLength == 9) {
                              context.read<LoginCubit>().login(phone: phone.text);
                            }
                          },
                          text: "continue".tr(),
                          borderRadius: AppConstants.sp15(context),
                          elevation: 0,
                          hasShadow: true,
                          isEnabled: context.read<AuthCubit>().registerPhoneLength == 9,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
