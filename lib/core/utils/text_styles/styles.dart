import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';

abstract class Styles {
  // Thin	100
  // Extra Light	200
  // Light	300
  // Regular (Normal)	400
  // Medium	500
  // Semi-Bold	600
  // Bold	700
  // Extra Bold	800
  // Black (Heavy)	900

  static TextStyle hintText(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .016,
    fontWeight: FontWeight.w500,
    color: const Color(0xff9C9B9A),
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ///////////////////////// Size 10 ///////////////////////

  static TextStyle font10RegularBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .012,
    fontWeight: FontWeight.w400,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font10MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .012,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font10MediumGrey46(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .012,
    fontWeight: FontWeight.w500,
    color: AppColors.grey46,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font10SemiBoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .012,
    fontWeight: FontWeight.w600,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font10BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .012,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ///////////////////////// Size 11 ///////////////////////

  static TextStyle font11RegularBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .013,
    fontWeight: FontWeight.w400,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font11MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .013,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font11MediumGrey46(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .013,
    fontWeight: FontWeight.w500,
    color: AppColors.grey46,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font11BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .013,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  //////////////////////////////// size 12 //////////////////////////
  static TextStyle font12RegularBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .014,
    fontWeight: FontWeight.w400,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font12RegularGrey46(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .014,
    fontWeight: FontWeight.w400,
    color: AppColors.grey46,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font12MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .014,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font12MediumGrey46(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .014,
    fontWeight: FontWeight.w500,
    color: AppColors.grey46,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font12BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .014,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  /////////////////////// Size 14 ////////////////////////

  static TextStyle font14RegularBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .016,
    fontWeight: FontWeight.w400,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font14MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .016,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font14MediumGrey46(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .016,
    fontWeight: FontWeight.w500,
    color: AppColors.grey46,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font14BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .016,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ////////////////////// Size 16 ///////////////////////////////////

  static TextStyle font16RegularBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .018,
    fontWeight: FontWeight.w400,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font16MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .018,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font16SemiBoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .018,
    fontWeight: FontWeight.w600,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font16BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .018,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ////////////////////// Size 17 //////////////////////////////////////
  static TextStyle font17MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .019,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ////////////////////// Size 18 ///////////////////////////////////

  static TextStyle font18RegularBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .02,
    fontWeight: FontWeight.w400,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font18MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .02,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font18SemiBoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .02,
    fontWeight: FontWeight.w600,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font18BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .02,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ////////////////////////////// Size 19 ///////////////////////////

  static TextStyle font19RegularGrey(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .021,
    fontWeight: FontWeight.w400,
    color: AppColors.greyFont,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ////////////////////////// Size 20 /////////////////////////
  static TextStyle font20MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .02,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font20BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .022,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  ////////////////////////// Size 24 /////////////////////////
  static TextStyle font24MediumBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .026,
    fontWeight: FontWeight.w500,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );

  static TextStyle font24BoldBlack(context) => TextStyle(
    fontSize: MediaQuery.of(context).size.height * .026,
    fontWeight: FontWeight.w700,
    color: AppColors.neutralColor,
    fontFamily: CacheKeysManger.getUserLanguage() == "en" ? "DMSans" : "IBMPlex",
  );
}
