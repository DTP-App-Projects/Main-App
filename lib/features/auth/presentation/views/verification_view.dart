import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:digital_trade_portal/features/auth/presentation/views/widgets/verification_view_body.dart';

class VerificationView extends StatelessWidget {
  const VerificationView({super.key, required this.phone, required this.requestId});

  final String phone;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VerificationViewBody(
        phone: phone,
          requestId:requestId
      ),
    );
  }
}
