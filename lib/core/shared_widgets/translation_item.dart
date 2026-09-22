import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/shared_widgets/language_bottom_sheet.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';

class TranslationItem extends StatelessWidget {
  const TranslationItem({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
            context: context, backgroundColor: Colors.white, builder: (context) => LanguageBottomSheet());
      },
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: AppConstants.width10(context), vertical: AppConstants.height10(context)),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
            border: Border.all(color: const Color(0xffE0E0E0))),
        child: Row(
          children: [
            SvgPicture.asset(
              AssetData.translation,
              color: const Color(0xffb7b1b1),
            ),
            SizedBox(width: AppConstants.width5(context)),
            Text("lang".tr(), style: Styles.font12MediumBlack(context)),
          ],
        ),
      ),
    );
  }
}
