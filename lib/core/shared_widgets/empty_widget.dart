import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:lottie/lottie.dart';

import '../utils/constants.dart';

class EmptyWidget extends StatelessWidget {
  const EmptyWidget({super.key,  this.icon, required this.title,this.size});
final String? icon;
final String title;
final double? size;
  @override
  Widget build(BuildContext context) {
    return   Center(
      child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(icon??AssetData.empty,width:size?? MediaQuery.of(context).size.width*.7),
          SizedBox(height: AppConstants.height10(context)),
          Text(title,style:Styles.font14MediumGrey46(context)),
        ],
      ),
    );
  }
}
