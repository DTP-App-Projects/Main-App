import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/utils/assets/assets.dart';

class SplashViewBody extends StatefulWidget {
  const SplashViewBody({super.key});

  @override
  State<SplashViewBody> createState() => _SplashViewBodyState();
}

class _SplashViewBodyState extends State<SplashViewBody> {


  navigate() async {
    if (await CacheKeysManger.getToken() != ""&&CacheKeysManger.getCompleteProfile()) {
      GoRouter.of(context).pushReplacement("/mainLayoutView");
    } else {
      GoRouter.of(context).pushReplacement("/onboardingView");
    }
  }
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2700), () async {
      navigate();
      // context.read<GetAppSettingsCubit>().getAppSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        AssetData.splash,
        repeat: false,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
      ),
    );
  }
}
