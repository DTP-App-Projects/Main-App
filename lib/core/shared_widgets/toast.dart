import 'package:cherry_toast/cherry_toast.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';

toast({
  required String text,
  bool isSuccess = true,
  required BuildContext context,
}) async {
  if (isSuccess) {
    CherryToast.success(title: Text(text, style: Styles.font16MediumBlack(context))).show(context);
  } else {
    CherryToast.error(title: Text(text, style: Styles.font16MediumBlack(context))).show(context);
  }
}
