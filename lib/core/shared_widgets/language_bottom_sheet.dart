import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';

class LanguageBottomSheet extends StatelessWidget {
  const LanguageBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(builder: (context, state) {
      return Container(
        padding: EdgeInsets.all(AppConstants.sp20(context)),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppConstants.sp10(context)),
              topRight: Radius.circular(AppConstants.sp10(context)),
            )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppConstants.height10(context)),
            Text("appLang".tr(), style: Styles.font20BoldBlack(context)),
            SizedBox(height: AppConstants.height30(context)),
            GestureDetector(
              onTap: () {
                context.read<ChangeLanguageCubit>().changeLanguage(lang: "ar", context: context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.width15(context), vertical: AppConstants.height10(context)),
                decoration: BoxDecoration(
                  color: AppColors.neutralColor[100],
                  borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
                  border: Border.all(color: const Color(0xffE5E5E5)),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      AssetData.arabic,
                      width: AppConstants.width30(context),
                    ),
                    SizedBox(width: AppConstants.width10(context)),
                    Expanded(
                        child: Text(
                      "arabic".tr(),
                      style: Styles.font12MediumBlack(context),
                    )),
                    Radio(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: "ar",
                        groupValue: CacheKeysManger.getUserLanguage(),
                        onChanged: (value) {
                          context.read<ChangeLanguageCubit>().changeLanguage(lang: "ar", context: context);

                        })
                  ],
                ),
              ),
            ),
            SizedBox(height: AppConstants.height10(context)),
            GestureDetector(
              onTap: () {
                context.read<ChangeLanguageCubit>().changeLanguage(lang: "en", context: context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.width15(context), vertical: AppConstants.height10(context)),
                decoration: BoxDecoration(
                  color: AppColors.neutralColor[100],
                  borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
                  border: Border.all(color: const Color(0xffE5E5E5)),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(AssetData.english, width: AppConstants.width30(context)),
                    SizedBox(width: AppConstants.width10(context)),
                    Expanded(
                        child: Text(
                      "english".tr(),
                      style: Styles.font12MediumBlack(context),
                    )),
                    Radio(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: "en",
                        groupValue: CacheKeysManger.getUserLanguage(),
                        onChanged: (value) {
                          context.read<ChangeLanguageCubit>().changeLanguage(lang: "en", context: context);

                        })
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),

          ],
        ),
      );
    });
  }
}
