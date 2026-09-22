import 'package:easy_localization/easy_localization.dart' as locale;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/shared_widgets/loading_dialog.dart';
import 'package:digital_trade_portal/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal/core/shared_widgets/translation_item.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_cubit.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_states.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/login_verification/login_verification_cubit.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import '../../../../../core/shared_widgets/custom_button.dart';
import '../../../../../core/utils/colors/colors.dart';
import '../../../../../core/utils/constants.dart';
import '../../../../../core/utils/text_styles/styles.dart';
import '../complete_profile_view.dart';

class VerificationViewBody extends StatefulWidget {
  const VerificationViewBody({super.key, required this.phone, required this.requestId});

  final String phone;
  final String requestId;

  @override
  State<VerificationViewBody> createState() => _VerificationViewBodyState();
}

class _VerificationViewBodyState extends State<VerificationViewBody> {
  // bool finished = false;
  TextEditingController otpCode = TextEditingController();
  final formKeyVerification = GlobalKey<FormState>();

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
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.height20(context)),
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
                        child: const Icon(Icons.arrow_back),
                      ),
                      const TranslationItem(),
                    ],
                  ),
                  SizedBox(height: AppConstants.height20(context) * 2),
                  Text("verifyPhone".tr(), style: Styles.font24BoldBlack(context)),
                  SizedBox(height: AppConstants.height10(context)),
                  Text("${"enterDigits".tr()} +966${widget.phone}", style: Styles.font14MediumGrey46(context)),
                  SizedBox(height: AppConstants.height20(context)),
                  Form(
                    key: formKeyVerification,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppConstants.width5(context)),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: PinCodeTextField(
                          length: 4,
                          appContext: context,
                          obscureText: false,
                          cursorColor: Colors.transparent,
                          animationType: AnimationType.fade,
                          keyboardType: TextInputType.number,
                          textStyle: Styles.font19RegularGrey(context).copyWith(
                            fontSize: MediaQuery.of(context).size.height * .031,
                            fontWeight: FontWeight.w700,
                            fontFamily: "DMSans",
                            color: AppColors.neutralColor,
                          ),
                          validator: (value) {
                            if (value!.isEmpty || value.length < 4) {
                              return "enterCorrectOtp".tr();
                            }
                            return null;
                          },
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
                            borderWidth: 0.5,
                            fieldHeight: MediaQuery.of(context).size.height * .07,
                            // fieldHeight: MediaQuery.of(context).size.height * .06,
                            // fieldWidth: MediaQuery.of(context).size.height * .06,
                            fieldWidth: MediaQuery.of(context).size.height * .07,
                            activeFillColor: Colors.white,
                            inactiveColor: const Color(0xffEAEEF2),
                            inactiveFillColor: Colors.white,
                            activeColor: const Color(0xffF7F7F7),
                            selectedFillColor: const Color(0xffEAD0FF),
                            selectedColor: AppColors.primaryColor,
                          ),
                          animationDuration: const Duration(milliseconds: 300),
                          enableActiveFill: true,
                          controller: otpCode,
                          onChanged: (value) {
                            otpCode.text = value;
                            context.read<AuthCubit>().enableVerifyButton();
                          },
                          beforeTextPaste: (text) {
                            return true;
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppConstants.height20(context)),
                  BlocBuilder<AuthCubit, AuthStates>(
                    builder: (context, s) {
                      return BlocProvider(
                        create: (context) => LoginVerificationCubit(getIt.get<AuthRepoImpl>()),
                        child: BlocConsumer<LoginVerificationCubit, LoginVerificationState>(
                          listener: (context, state) async {
                            if (state is LoginVerificationLoadingState) {
                              LoadingDialog().show(context);
                            } else if (state is LoginVerificationSuccessState) {
                              LoadingDialog().hide();
                              toast(text: state.verificationModel.message!, context: context);
                              await CacheKeysManger.saveToken(token: state.verificationModel.data!.token ?? "");
                              // this condition to check if user is complete profile or not
                              if (state.verificationModel.data!.userData!.name == null) {
                                CacheKeysManger.saveCompleteProfile(false);
                                // profile is not completed
                                NavigationUtils.navigateReplacement(
                                  context: context,
                                  destinationScreen: CompleteProfileView(phone: widget.phone),
                                );
                              } else {
                                // profile is completed
                                CacheKeysManger.saveCompleteProfile(true);
                                // context.read<GetProfileCubit>().getProfile();
                                // context.read<GetWishlistCubit>().getWishlist();
                                // context.read<GetWalletCubit>().getWallet();
                                // context.read<GetAddressesCubit>().getAddresses();
                                // context.read<GetCartCubit>().getCart();
                                // context.read<GetStoriesCubit>().getStories(place: "homepage");
                                // context.read<GetNormalOrdersCubit>().getNormalOrders(statusIndex: 0);
                                // The server's interests win over the local picks
                                // on login; the feed reloads once they are in.
                                // final myInterestsCubit = context.read<MyInterestsCubit>();
                                // final feed = PreferencesFeed.of(context);
                                // myInterestsCubit.syncOnLogin().then((_) => feed.refresh());
                                AppConstants.isGuest = false;
                                context.read<ChangeNavBarStatusCubit>().changeNavBarIndex(0);
                                GoRouter.of(context).go("/mainLayoutView");
                              }
                            } else if (state is LoginVerificationErrorState) {
                              LoadingDialog().hide();
                              toast(text: state.errMessage, context: context, isSuccess: false);
                            }
                          },
                          builder: (context, state) {
                            return DefaultButton(
                              onPress: () {
                                if (formKeyVerification.currentState!.validate()) {
                                  context.read<LoginVerificationCubit>().loginVerification(
                                    phone: widget.phone,
                                    otp: otpCode.text,
                                    requestId: widget.requestId,
                                  );
                                }
                              },
                              text: 'verify'.tr(),
                              hasShadow: true,
                              isEnabled: otpCode.text.length == 4 ? true : false,
                              height: AppConstants.height15(context),
                              borderRadius: AppConstants.sp10(context),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  // SizedBox(height: AppConstants.height20(context)),
                  // Text("didn’tReceiveCode".tr(), style: Styles.font12MediumGrey46(context)),
                  // SizedBox(height: AppConstants.height5(context)),
                  // finished
                  //     ? GestureDetector(
                  //         onTap: () {
                  //           setState(() {
                  //             finished = !finished;
                  //           });
                  //         },
                  //         child: Text(
                  //           "resendCode".tr(),
                  //           style: Styles.font12MediumBlack(
                  //             context,
                  //           ).copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                  //         ),
                  //       )
                  //     : Row(
                  //         mainAxisAlignment: MainAxisAlignment.start,
                  //         children: [
                  //           Text("getCode".tr(), style: Styles.font12MediumGrey46(context)),
                  //           SizedBox(width: AppConstants.width5(context)),
                  //           Countdown(
                  //             seconds: 120,
                  //             build: (BuildContext context, double time) => Text(
                  //               "${(time ~/ 60).toString()}:${(time.toInt() % 60).toInt()}",
                  //               style: Styles.font12MediumBlack(
                  //                 context,
                  //               ).copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                  //             ),
                  //             interval: const Duration(seconds: 1),
                  //             onFinished: () {
                  //               setState(() {
                  //                 finished = true;
                  //               });
                  //             },
                  //           ),
                  //         ],
                  //       ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
