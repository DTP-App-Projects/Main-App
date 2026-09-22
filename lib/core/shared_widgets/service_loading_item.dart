import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_loading_text.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';

class ServiceLoadingItem extends StatelessWidget {
  const ServiceLoadingItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomLoadingText(
          height: MediaQuery.of(context).size.height * 0.15,
          width: MediaQuery.of(context).size.width,
          borderRadius: AppConstants.sp10(context),
        ),
        SizedBox(height: AppConstants.height10(context)),
        CustomLoadingText(
          width: MediaQuery.of(context).size.width * 0.2,
          height: MediaQuery.of(context).size.height * 0.016,
        ),
        SizedBox(height: AppConstants.height5(context)),
        CustomLoadingText(width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.height * 0.018),
        SizedBox(height: AppConstants.height5(context)),
        CustomLoadingText(
          width: MediaQuery.of(context).size.width * 0.15,
          height: MediaQuery.of(context).size.height * 0.014,
        ),
      ],
    );
  }
}
