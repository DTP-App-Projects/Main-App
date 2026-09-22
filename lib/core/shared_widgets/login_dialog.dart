import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';

loginDialog({required BuildContext context}) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => Dialog(
    insetPadding: EdgeInsets.symmetric(horizontal: AppConstants.width20(context)),
    backgroundColor: Colors.white,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height20(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: IconButton(
              onPressed: () {
                NavigationUtils.navigateBack(context: context);
              },
              icon: Icon(Icons.close),
            ),
          ),

          Text("login_dialog".tr(), textAlign: TextAlign.center, style: Styles.font16SemiBoldBlack(context)),
          SizedBox(height: AppConstants.height5(context)),
          Image.asset(AssetData.lamlomLogin, width: MediaQuery.of(context).size.width * 0.5),
          SizedBox(height: AppConstants.height20(context)),
          Text("login_hint_dialog".tr(), textAlign: TextAlign.center, style: Styles.font14MediumGrey46(context)),
          SizedBox(height: AppConstants.height20(context)),
          DefaultButton(
            onPress: () {
              NavigationUtils.navigateBack(context: context);
              GoRouter.of(context).go("/onboardingView");
            },
            text: "login".tr(),
          ),
        ],
      ),
    ),
  ),
);
