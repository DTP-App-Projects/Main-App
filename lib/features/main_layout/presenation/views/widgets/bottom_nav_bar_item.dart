import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal/core/shared_widgets/default_cached_network_image.dart';
import 'package:digital_trade_portal/core/shared_widgets/login_dialog.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';

class BottomNavBarItem extends StatelessWidget {
  const BottomNavBarItem({
    super.key,
    required this.icon,
    required this.index,
    required this.title,
    this.isProfile = false,
  });

  final String icon;
  final String title;
  final int index;
  final bool isProfile;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (ChangeNavBarStatusCubit.get(context).currentIndex != index) {
          if (AppConstants.isGuest && index != 0) {
            loginDialog(context: context);
          } else {
            ChangeNavBarStatusCubit.get(context).changeNavBarIndex(index);
          }
        }
      },
      icon: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // BlocBuilder<GetProfileCubit, GetProfileState>(
          //           builder: (context, profileState) {
          //             if (profileState is GetProfileSuccessState) {
          //               if (profileState.model.data?.avatar != null) {
          //                 return Container(
          //                   decoration: BoxDecoration(
          //                     color: Colors.grey.shade300,
          //                     shape: BoxShape.circle,
          //                     border: Border.all(color: AppColors.primaryColor),
          //                   ),
          //                   child: ClipOval(
          //                     child: DefaultCachedNetworkImage(
          //                       imageUrl: profileState.model.data?.avatar ?? "",
          //                       imageHeight: MediaQuery.of(context).size.height * .03,
          //                       imageWidth: MediaQuery.of(context).size.height * .03,
          //                       fit: BoxFit.cover,
          //                     ),
          //                   ),
          //                 );
          //               } else {
          //                 return Image.asset(
          //                   icon,
          //                   width: MediaQuery.of(context).size.height * .03,
          //                   height: MediaQuery.of(context).size.height * .03,
          //                 );
          //               }
          //             } else {
          //               return CustomLoadingItem(size: AppConstants.sp30(context));
          //             }
          //           },
          //         )
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryColor),
            ),
            child: ClipOval(
              child: DefaultCachedNetworkImage(
                imageUrl:
                    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSYO-RnslVwrpn-JSpQJ_MjYOzZrAa5WBIaoA&s",
                imageHeight: MediaQuery.of(context).size.height * .03,
                imageWidth: MediaQuery.of(context).size.height * .03,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: AppConstants.height10(context)),
          Text(
            title,
            style: Styles.font14MediumBlack(context).copyWith(
              color: ChangeNavBarStatusCubit.get(context).currentIndex == index
                  ? AppColors.primaryColor
                  : AppColors.neutralColor[500],
            ),
          ),
        ],
      ),
    );
  }
}
