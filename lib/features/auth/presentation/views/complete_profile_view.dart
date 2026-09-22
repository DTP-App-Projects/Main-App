import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal/core/shared_widgets/loading_dialog.dart';
import 'package:digital_trade_portal/core/shared_widgets/profile_picture.dart';
import 'package:digital_trade_portal/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/image_type.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/complete_profile/complete_profile_cubit.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/select_profile_photo/select_profile_photo_cubit.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';


class CompleteProfileView extends StatefulWidget {
  const CompleteProfileView({super.key, required this.phone});

  final String phone;

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView> {
  TextEditingController name = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController birthdate = TextEditingController();
  String gender = "";
  var formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    birthdate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => SelectProfilePhotoCubit(getIt<AuthRepoImpl>()))],
      child: WillPopScope(
        onWillPop: () async => !LoadingDialog().isShowing,
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.width15(context)),
              child: Column(
                children: [
                  SizedBox(height: AppConstants.height10(context)),
                  CustomAppBar(title: "set_up_profile".tr()),
                  SizedBox(height: AppConstants.height15(context)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BlocBuilder<SelectProfilePhotoCubit, SelectProfilePhotoState>(
                              builder: (context, state) {
                                return ProfilePicture(
                                  imageType: context.read<SelectProfilePhotoCubit>().profilePhotoFile == null
                                      ? ImageType.asset
                                      : ImageType.file,
                                  imageLink:
                                      context.read<SelectProfilePhotoCubit>().profilePhotoFile ?? AssetData.lamlom,
                                  hasEdit: true,
                                  fit: BoxFit.cover,
                                  onTap: () {
                                    context.read<SelectProfilePhotoCubit>().selectProfilePhoto();
                                  },
                                  size: MediaQuery.of(context).size.height * 0.12,
                                );
                              },
                            ),
                            SizedBox(height: AppConstants.height30(context)),
                            Text("${"name".tr()} *", style: Styles.font16BoldBlack(context)),
                            SizedBox(height: AppConstants.height10(context)),
                            DefaultTextFormField(
                              textInputType: TextInputType.text,
                              controller: name,
                              hintText: "name_hint".tr(),
                              borderRadius: AppConstants.sp15(context),
                              fillColor: AppColors.neutralColor[100],
                              isFilled: true,
                              hasBorder: false,
                            ),
                            SizedBox(height: AppConstants.height20(context)),
                            Text("${"gender".tr()} *", style: Styles.font16BoldBlack(context)),
                            SizedBox(height: AppConstants.height10(context)),
                            // Row(
                            //   children: [
                            //     GenderItem(
                            //       onTap: () {
                            //         setState(() {
                            //           gender = "male";
                            //         });
                            //       },
                            //       value: "male",
                            //       title: "male".tr(),
                            //       groupValue: gender,
                            //     ),
                            //     SizedBox(width: AppConstants.width15(context)),
                            //     GenderItem(
                            //       onTap: () {
                            //         setState(() {
                            //           gender = "female";
                            //         });
                            //       },
                            //       value: "female",
                            //       title: "female".tr(),
                            //       groupValue: gender,
                            //     ),
                            //   ],
                            // ),
                            SizedBox(height: AppConstants.height20(context)),
                            Text("birthdate".tr(), style: Styles.font16BoldBlack(context)),
                            SizedBox(height: AppConstants.height10(context)),
                            DefaultTextFormField(
                              textInputType: TextInputType.phone,
                              controller: birthdate,
                              hintText: "birthdate_hint".tr(),
                              borderRadius: AppConstants.sp15(context),
                              fillColor: AppColors.neutralColor[100],
                              isFilled: true,
                              hasBorder: false,
                              readOnly: true,
                              validation: (value) {
                                return null;
                              },
                              onTap: () {
                                showDatePicker(
                                  context: context,
                                  firstDate: DateTime(1000),
                                  lastDate: DateTime.now(),
                                ).then((value) {
                                  if (value != null) {
                                    birthdate.text = DateFormat("yyyy-MM-dd", "en").format(value);
                                  }
                                });
                              },
                            ),
                            SizedBox(height: AppConstants.height20(context)),
                            Text("email".tr(), style: Styles.font16BoldBlack(context)),
                            SizedBox(height: AppConstants.height10(context)),
                            DefaultTextFormField(
                              textInputType: TextInputType.emailAddress,
                              controller: email,
                              hintText: "emailHint".tr(),
                              borderRadius: AppConstants.sp15(context),
                              fillColor: AppColors.neutralColor[100],
                              isFilled: true,
                              hasBorder: false,
                              validation: (String? value) {
                                if (value!.isNotEmpty) {
                                  if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'valid_email'.tr();
                                  }
                                }

                                return null;
                              },
                            ),

                            SizedBox(height: AppConstants.height30(context)),
                            BlocProvider(
                              create: (context) => CompleteProfileCubit(getIt<AuthRepoImpl>()),
                              child: BlocConsumer<CompleteProfileCubit, CompleteProfileState>(
                                listener: (context, state) {
                                  if (state is CompleteProfileLoadingState) {
                                    LoadingDialog().show(context);
                                  } else if (state is CompleteProfileSuccessState) {
                                    LoadingDialog().hide();
                                    toast(text: state.message, context: context);
                                    CacheKeysManger.saveCompleteProfile(true);
                                    AppConstants.isGuest = false;
                                    // context.read<GetProfileCubit>().getProfile();
                                    // context.read<GetWishlistCubit>().getWishlist();
                                    // context.read<GetCartCubit>().getCart();
                                    // context.read<GetWalletCubit>().getWallet();
                                    // context.read<GetStoriesCubit>().getStories(place: "homepage");
                                    // context.read<GetAddressesCubit>().getAddresses();
                                    // context.read<GetNormalOrdersCubit>().getNormalOrders(statusIndex: 0);
                                    // A brand new customer has nothing stored on
                                    // the server, so this pushes the local picks up.
                                    // final myInterestsCubit = context.read<MyInterestsCubit>();
                                    // final feed = PreferencesFeed.of(context);
                                    // myInterestsCubit.syncOnLogin().then((_) => feed.refresh());
                                    context.read<ChangeNavBarStatusCubit>().changeNavBarIndex(0);
                                    GoRouter.of(context).go("/mainLayoutView");
                                  } else if (state is CompleteProfileErrorState) {
                                    LoadingDialog().hide();
                                    toast(text: state.errMessage, context: context, isSuccess: false);
                                  }
                                },
                                builder: (context, state) {
                                  return DefaultButton(
                                    onPress: () {
                                      if (formKey.currentState!.validate()) {
                                        if (gender == "") {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("select_gender".tr()),
                                              backgroundColor: AppColors.red,
                                            ),
                                          );
                                        } else {
                                          context.read<CompleteProfileCubit>().completeProfile(
                                            name: name.text,
                                            gender: gender,
                                            birthday: birthdate.text,
                                            email: email.text,
                                            phone: widget.phone,
                                            avatar: context.read<SelectProfilePhotoCubit>().profilePhotoFile,
                                          );
                                        }
                                      }
                                    },
                                    text: "complete_profile".tr(),
                                    hasShadow: true,
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: AppConstants.height20(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
