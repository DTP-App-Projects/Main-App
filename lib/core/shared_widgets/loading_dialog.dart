import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';

class LoadingDialog {
  static final LoadingDialog _instance = LoadingDialog._internal();

  factory LoadingDialog() => _instance;

  LoadingDialog._internal();

  OverlayEntry? _overlayEntry;
  bool _isShowing = false; // Track overlay visibility

  void show(BuildContext context) {
    if (_isShowing) return; // Prevent multiple overlays
    _isShowing = true;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withOpacity(0.3),
          ),
          Center(
            child: Container(
              padding: EdgeInsets.all(AppConstants.sp30(context) * 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
                color: Colors.white,
              ),
              child: SizedBox(
                width: AppConstants.height30(context),
                height: AppConstants.height30(context),
                child: CircularProgressIndicator(
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    if (!_isShowing) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  bool get isShowing => _isShowing; // Allow checking if it's showing
}
