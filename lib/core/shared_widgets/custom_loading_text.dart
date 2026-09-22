import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class CustomLoadingText extends StatelessWidget {
  const CustomLoadingText({super.key, this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      highlightColor: Colors.grey[200]!,
      baseColor: Colors.grey[300]!,
      child: Container(
        height: height ?? MediaQuery.of(context).size.height * 0.015,
        width: width ?? MediaQuery.of(context).size.width * 0.2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius ?? AppConstants.sp30(context)),
          color: Colors.grey,
        ),
      ),
    );
  }
}
