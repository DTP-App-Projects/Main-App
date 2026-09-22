import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';

class SarImage extends StatelessWidget {
  const SarImage({super.key, this.color, this.size});
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: AppConstants.width5(context)/1.5,),
        SvgPicture.asset(
          AssetData.sar,
          color: color??AppColors.neutralColor,
          width:size?? MediaQuery.of(context).size.height*.016,
          height: size??MediaQuery.of(context).size.height*.016,
        ),

      ],
    );
  }
}
