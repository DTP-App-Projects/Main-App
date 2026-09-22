import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/shared_widgets/exit_alert.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/views/widgets/bottom_nav_bar.dart';


class MainLayoutView extends StatefulWidget {
  const MainLayoutView({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    final navCubit = ChangeNavBarStatusCubit.get(context);
    if (widget.initialIndex != null) {
      navCubit.currentIndex = widget.initialIndex!;
    }
    _visited.add(navCubit.currentIndex);

    // if (!AppConstants.isGuest && AppConstants.isFirstOpen) {
    //   context.read<GetWishlistCubit>().getWishlist();
    //   // if (Platform.isIOS) {
    //   //   MFSDK.init(AppConstants.myFatoorahKey ?? "", MFCountry.SAUDIARABIA, MFEnvironment.LIVE);
    //   // }
    //   AppConstants.isFirstOpen = false;
    }



  Widget buildScreen(int index) {
    // لو الـ screen مش اتزارت، نرجع SizedBox.shrink() عشان ما تتبنيش
    if (!_visited.contains(index)) return const SizedBox.shrink();

    switch (index) {
      case 0:
        return const SizedBox();
      case 1:
        return const SizedBox();
      case 2:
        return const SizedBox();
      case 3:
        return const SizedBox();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (t, _) {
        exitDialog(context);
      },
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, _) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                BlocBuilder<ChangeNavBarStatusCubit, ChangeNavBarStatusState>(
                  builder: (context, state) {
                    final currentIndex = ChangeNavBarStatusCubit.get(context).currentIndex;
                    _visited.add(currentIndex);

                    return IndexedStack(index: currentIndex, children: List.generate(4, (i) => buildScreen(i)));
                  },
                ),
              ],
            ),
            bottomNavigationBar: BottomNavBar(),
          );
        },
      ),
    );
  }
}
