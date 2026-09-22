import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return  GestureDetector(
      onTap: () {
        NavigationUtils.navigateBack(context: context);
      },
      child: Container(
        // alignment: AlignmentDirectional.center,
        padding: EdgeInsets.all(AppConstants.sp5(context)),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: RotatedBox(
            quarterTurns: CacheKeysManger.getUserLanguage()=="ar"?2:0,
            child: SvgPicture.asset(AssetData.back)),
      ),
    );
  }
}
