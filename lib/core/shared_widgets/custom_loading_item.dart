import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';

class CustomLoadingItem extends StatelessWidget {
  const CustomLoadingItem({super.key, this.color, this.size});
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: SpinKitFadingCircle(
        color: color??AppColors.primaryColor,
        size:size?? MediaQuery.of(context).size.width*0.12,
      ),
    );
  }
}
