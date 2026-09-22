import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/features/splash/presentation/views/widgets/splash_view_body.dart';
import '../../../../core/utils/colors/colors.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.primaryColor,
        systemNavigationBarDividerColor: AppColors.primaryColor,
        statusBarBrightness: Platform.isAndroid?Brightness.light:Brightness.dark,
        statusBarColor: AppColors.primaryColor,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryColor,
        body: const SplashViewBody(),
      ),
    );
  }
}
