import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:flutter/material.dart';

void exitDialog(context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shadowColor: Colors.white,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),

      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.width10(context),
          vertical: AppConstants.height20(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("exit".tr(), style: Styles.font24BoldBlack(context).copyWith(color: AppColors.red)),
            SizedBox(height: AppConstants.height15(context)),
            Image.asset(AssetData.lamlomSad, width: MediaQuery.of(context).size.width * 0.5),
            SizedBox(height: AppConstants.height15(context)),
            Text("exit_hint".tr(), style: Styles.font14MediumGrey46(context),textAlign: TextAlign.center,),
            SizedBox(height: AppConstants.height20(context)),
            Row(
              children: [
                Expanded(
                  child: DefaultButton(
                    onPress: () {
                      NavigationUtils.navigateBack(context: context);
                    },
                    text: "cancel".tr(),
                  ),
                ),
                SizedBox(width: AppConstants.width10(context)),

                Expanded(
                  child: DefaultButton(
                    onPress: () {
                      exit(0);
                    },
                    text: "yes".tr(),
                    backgroundColor: Colors.white,
                    hasBorder: true,
                    borderColor: AppColors.red,
                    textColor: AppColors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
