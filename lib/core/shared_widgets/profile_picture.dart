import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/image_type.dart';
import 'default_cached_network_image.dart';

class ProfilePicture extends StatelessWidget {
  ProfilePicture({
    super.key,
    this.onTap,
    required this.imageType,
    required this.imageLink,
    this.size,
    this.hasEdit = false,
    this.fit,
  });

  void Function()? onTap;
  ImageType imageType;
  dynamic imageLink;
  double? size;
  bool hasEdit;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Align(
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.height55(context)),
              child: (imageLink == null)
                  ? null
                  : (imageType == ImageType.file)
                      ? Image.file(imageLink,
                          height:size?? MediaQuery.of(context).size.height * 0.1,
                          width: size??MediaQuery.of(context).size.height * 0.1,
                          fit: fit ?? BoxFit.cover)
                      : (imageType == ImageType.network)
                          ? DefaultCachedNetworkImage(
                              imageUrl: imageLink,
                              imageHeight:size?? MediaQuery.of(context).size.height * 0.1,
                              imageWidth:size?? MediaQuery.of(context).size.height * 0.1,
                              fit: fit ?? BoxFit.cover,
                            )
                          : (imageType == ImageType.asset)
                              ?  Image.asset(imageLink,
                                      height:size?? MediaQuery.of(context).size.height * 0.1,
                                      width:size?? MediaQuery.of(context).size.height * 0.1,
                                      fit: fit ?? BoxFit.cover)
                              : null,
            ),
            if (hasEdit)
              Container(
                margin: EdgeInsets.all(AppConstants.sp5(context)),
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(
                    AppConstants.sp5(context),
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: AppConstants.sp20(context),
                ),
              )
          ],
        ),
      ),
    );
  }
}
