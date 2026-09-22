import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/shared_widgets/loading_dialog.dart';
import 'package:digital_trade_portal/core/shared_widgets/translation_item.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal/features/auth/presentation/views/login_view.dart';
import 'package:digital_trade_portal/features/auth/presentation/views/widgets/custom_register_form.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (LoadingDialog().isShowing) {
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
        body: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(builder: (context, langState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.width20(context)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppConstants.height20(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                            onTap: () {
                              NavigationUtils.navigateBack(context: context);
                            },
                            child: const Icon(Icons.arrow_back)),
                        const TranslationItem(),
                      ],
                    ),
                    SizedBox(height: AppConstants.height20(context) * 2),
                    Text("signUpLamat".tr(), style: Styles.font24BoldBlack(context)),
                    SizedBox(height: AppConstants.height10(context)),
                    Text(
                      "signUpInfo".tr(),
                      style: Styles.font12MediumBlack(context).copyWith(color: AppColors.grey46),
                    ),
                    SizedBox(height: AppConstants.height15(context)),
                    const CustomRegisterForm(),
                    SizedBox(height: AppConstants.height10(context)),
                    Wrap(
                      children: [
                        Text(
                          "agreeTermsRegister".tr(),
                          style: Styles.font12MediumBlack(context).copyWith(color: AppColors.grey46),
                        ),
                        GestureDetector(
                          onTap: () {
                            // showModalBottomSheet(
                            //     context: context,
                            //     isScrollControlled: true,
                            //     useSafeArea: true,
                            //     constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                            //     builder: (context) => const TermsAndConditionsBottomSheet());
                          },
                          child: Text(
                            "termsAndConditions".tr(),
                            style: Styles.font12MediumBlack(context)
                                .copyWith(color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // SizedBox(height: AppConstants.height10(context) * 2.5),
                    // Row(
                    //   children: [
                    //     const Expanded(child: Divider()),
                    //     SizedBox(width: AppConstants.width15(context)),
                    //     Text(
                    //       "or".tr(),
                    //       style: Styles.font10MediumBlack(context),
                    //     ),
                    //     SizedBox(width: AppConstants.width15(context)),
                    //     const Expanded(child: Divider()),
                    //   ],
                    // ),
                    // SizedBox(height: AppConstants.height20(context)),
                    // DefaultButton(
                    //   onPress: () {},
                    //   text: "withGoogle".tr(),
                    //   hasBorder: true,
                    //   backgroundColor: Colors.white,
                    //   elevation: 0,
                    //   borderRadius: AppConstants.sp10(context),
                    //   icon: SvgPicture.asset(
                    //     AssetData.gmail,
                    //     width: MediaQuery.of(context).size.width * 0.06,
                    //   ),
                    //   textColor: Colors.black,
                    //   borderColor: const Color(0xffD3D3D3),
                    // ),
                    // SizedBox(height: AppConstants.height20(context)),
                    // DefaultButton(
                    //   onPress: () {},
                    //   text: "withApple".tr(),
                    //   backgroundColor: Colors.black,
                    //   elevation: 0,
                    //   borderRadius: AppConstants.sp10(context),
                    //   icon: SvgPicture.asset(AssetData.apple, width: MediaQuery.of(context).size.width * 0.06),
                    // ),
                    SizedBox(height: AppConstants.height10(context)),
                    Wrap(
                      children: [
                        Text(
                          "haveAccount".tr(),
                          style: Styles.font12MediumBlack(context).copyWith(color: AppColors.grey46),
                        ),
                        GestureDetector(
                          onTap: () {
                            NavigationUtils.navigateReplacement(context: context, destinationScreen: const LoginView());
                          },
                          child: Text(
                            "login".tr(),
                            style: Styles.font12MediumBlack(context)
                                .copyWith(color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
