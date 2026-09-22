import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class DefaultCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? imageWidth;
  final double? imageHeight;
  final BoxFit? fit;
  const DefaultCachedNetworkImage({
    super.key,
    required this.imageUrl,
     this.imageHeight,
     this.imageWidth, this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      width: imageWidth,
      height: imageHeight,
      imageUrl: imageUrl,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[200]!,
        child: Container(
          height: imageHeight,
          width: imageWidth,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Image.network("https://www.lebistrotduchateau.fr/uploads/q8T5D4JA/767x0_2560x0/photounavailable412.jpg",fit: BoxFit.fill,),
      fit: fit??BoxFit.fill,
    );
  }
}
