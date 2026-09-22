import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:multi_dropdown/multi_dropdown.dart';

class CustomMultiDropdown extends StatelessWidget {
  const CustomMultiDropdown({
    super.key,
    this.items,
    this.onChanged,
    this.validator,
    required this.hintText,
    this.hasBorder = true,
    this.enabled = true,
    this.searchEnabled = false,
    this.borderRadius = 10,
    this.borderSideColor,
    this.borderSideEnabledColor,
    this.borderSideWidth = 1.0,
    this.enabledBorderRadiusColor = Colors.grey,
  });

  final List<String>? items;
  final Function(List<String>)? onChanged;
  final String? Function(List<DropdownItem<String>>?)? validator;
  final String hintText;
  final double borderRadius;
  final double borderSideWidth;
  final Color enabledBorderRadiusColor;
  final Color? borderSideColor;
  final Color? borderSideEnabledColor;
  final bool hasBorder;
  final bool enabled;
  final bool searchEnabled;

  @override
  Widget build(BuildContext context) {
    return MultiDropdown<String>(
      items: items!
          .map((item) => DropdownItem<String>(
                value: item.toString(),
                label: item.toString(),
              ))
          .toList(),
      // controller: controller,
      enabled: enabled,
      searchEnabled: searchEnabled,

      chipDecoration: ChipDecoration(
          backgroundColor: const Color(0xffF1F1F1),
          wrap: true,
          runSpacing: 2,
          padding:
              EdgeInsets.symmetric(horizontal: AppConstants.width10(context), vertical: AppConstants.height5(context)),
          spacing: 10,
          borderRadius: BorderRadius.all(Radius.circular(AppConstants.sp5(context)))),

      fieldDecoration: FieldDecoration(
        hintText: hintText,
        hintStyle: Styles.hintText(context),
        showClearIcon: false,
        borderRadius: AppConstants.sp10(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(
              borderRadius,
            ),
          ),
          borderSide: (!hasBorder)
              ? BorderSide.none
              : BorderSide(
                  color: borderSideColor ?? AppColors.primaryColor,
                  width: borderSideWidth,
                ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(
              borderRadius,
            ),
          ),
          borderSide: (!hasBorder)
              ? BorderSide.none
              : BorderSide(
                  color: borderSideColor ?? AppColors.primaryColor,
                  width: borderSideWidth,
                ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(
              borderRadius,
            ),
          ),
          borderSide: (!hasBorder)
              ? BorderSide.none
              : BorderSide(
                  color: borderSideEnabledColor ?? Colors.grey.shade300,
                  width: borderSideWidth,
                ),
        ),
      ),
      dropdownDecoration: DropdownDecoration(
        marginTop: AppConstants.height5(context),
        maxHeight: MediaQuery.of(context).size.height * 0.5,
        elevation: 5,
        header: SizedBox(height: AppConstants.height5(context)),
      ),
      dropdownItemDecoration: DropdownItemDecoration(
        selectedIcon: const Icon(Icons.check_box, color: Colors.green),
        disabledIcon: Icon(Icons.lock, color: Colors.grey.shade300),
      ),
      validator: validator,
      onSelectionChange: onChanged,
    );
  }
}
