import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';

import '../colors/colors.dart';

ThemeData themeDataLight = ThemeData(
  highlightColor: Colors.transparent,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
  splashColor: Colors.transparent,
  primaryColor: AppColors.primarySwatchColor,
  primarySwatch: AppColors.primaryColor,
  scaffoldBackgroundColor: Colors.white,
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primarySwatchColor),
  fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
);
