import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/views/widgets/bottom_nav_bar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/utils/assets/assets.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> icons = [AssetData.home, AssetData.cart, AssetData.orders, AssetData.profile];

    return BlocBuilder<ChangeNavBarStatusCubit, ChangeNavBarStatusState>(
      builder: (context, state) {
        List<String> titles = ["home".tr(), "cart".tr(), "my_orders".tr(), "profile".tr()];
        return Container(
          height: MediaQuery.of(context).size.width>600?MediaQuery.of(context).size.height*0.1:null,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.neutralColor[100]!,
                offset: const Offset(0, 6),
                spreadRadius: 8,
                blurRadius: 5,
              ),
            ],
          ),
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 6.0,
            color: Colors.white,
            padding: EdgeInsets.zero,
            surfaceTintColor: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      BottomNavBarItem(isProfile: false, icon: icons[0], index: 0, title: titles[0]),
                      BottomNavBarItem(isProfile: false, icon: icons[1], index: 1, title: titles[1]),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      BottomNavBarItem(isProfile: false, icon: icons[2], index: 2, title: titles[2]),
                      BottomNavBarItem(isProfile: true, icon: icons[3], index: 3, title: titles[3]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
