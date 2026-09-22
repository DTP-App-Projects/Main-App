import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/shared_widgets/default_cached_network_image.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/navigation_utility.dart';

class ImageDialog extends StatelessWidget {
  const ImageDialog({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: AppConstants.width10(context)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              NavigationUtils.navigateBack(context: context);
            },
            child: Container(
              padding: EdgeInsets.all(AppConstants.sp5(context) * 1.5),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.black),
            ),
          ),
          SizedBox(height: AppConstants.height20(context)),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: DefaultCachedNetworkImage(imageUrl: imageUrl),
          ),
        ],
      ),
    );
  }
}

showImageDialog({required BuildContext context, required String imageUrl}) => showDialog(
  context: context,
  useSafeArea: true,
  builder: (context) => ImageDialog(imageUrl: imageUrl),
);
