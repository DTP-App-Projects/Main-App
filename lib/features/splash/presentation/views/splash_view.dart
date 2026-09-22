import 'dart:io';
import 'package:digital_trade_portal/features/splash/presentation/views/widgets/splash_view_body.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // Transparent so the brand background paints under the navigation bar.
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarBrightness: Platform.isAndroid ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(backgroundColor: Colors.white, body: const SplashViewBody()),
    );
  }
}
