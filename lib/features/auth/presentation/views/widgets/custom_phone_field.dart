import 'package:easy_localization/easy_localization.dart' as locale;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal/core/utils/assets/assets.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal/core/utils/validations/saudi_phone_formatter.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_cubit.dart';

class CustomPhoneField extends StatelessWidget {
  const CustomPhoneField({super.key, required this.phoneController, required this.isLogin, this.isEnabled=true});

  final TextEditingController phoneController;
  final bool isLogin;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextFormField(
        textInputType: TextInputType.phone,
        hintText: "5xxxxxxxx",
        isEnabled: isEnabled,
        suffixIcon: isLogin
            ? context.read<AuthCubit>().loginPhoneLength >= 9
                ? IconButton(
                    onPressed: () {
                      phoneController.clear();
                      context.read<AuthCubit>().checkLoginPhoneLength(length: 0);
                    },
                    icon: const Icon(Icons.cancel),
                  )
                : null
            : context.read<AuthCubit>().registerPhoneLength >= 9
                ? IconButton(
                    onPressed: () {
                      phoneController.clear();
                      context.read<AuthCubit>().checkRegisterPhoneLength(length: 0);
                    },
                    icon: const Icon(Icons.cancel),
                  )
                : null,
        formatter: [SaudiPhoneNumberFormatter()],
        onChange: (value) {
          if (isLogin) {
            context.read<AuthCubit>().checkLoginPhoneLength(length: value.length);
          } else {
            context.read<AuthCubit>().checkRegisterPhoneLength(length: value.length);
          }
          if(value.length==9){
            FocusScope.of(context).unfocus();
          }
        },
        validationMsg: "enterPhoneNumber".tr(),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(AppConstants.sp10(context)),
                  bottomStart: Radius.circular(AppConstants.sp10(context)),
                ),
                color: const Color(0xffF5F5F5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: AppConstants.width5(context)),
                  SvgPicture.asset(AssetData.arabic, width: AppConstants.width30(context)),
                  SizedBox(width: AppConstants.width5(context)),
                  Text(
                    "966".tr(),
                    style: Styles.font17MediumBlack(context),
                  ),
                  SizedBox(width: AppConstants.width5(context)),
                  Container(
                    color: const Color(0xffE6E6E6),
                    width: 1,
                    height: MediaQuery.of(context).size.height * 0.053,
                  ),
                ],
              ),
            ),
            SizedBox(width: AppConstants.width5(context)),
          ],
        ),
        controller: phoneController,
        fillColor: const Color(0xffFDFDFD),
      ),
    );
  }
}
