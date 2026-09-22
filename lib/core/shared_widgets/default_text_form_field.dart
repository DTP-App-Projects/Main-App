import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/validations/convert_to_english_numbers.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/validations/saudi_phone_formatter.dart';
import '../utils/text_styles/styles.dart';

class DefaultTextFormField extends StatefulWidget {
  final int? maxLength;
  final int? maxLines;
  final bool isEnabled;
  final bool required;
  final bool isPassword;
  final bool isFilled;
  final bool hasBorder;
  final bool autoFocus;
  final bool readOnly;
  final double contentPaddingVertical;
  final double contentPaddingHorizontal;
  final double borderRadius;
  final double borderSideWidth;
  final Color enabledBorderRadiusColor;
  final Color? borderSideColor;
  final Color? borderSideEnabledColor;
  final Color? labelColorActive;
  final String? validationMsg;
  final TextInputType textInputType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Function? onPressSuffixIcon;
  final Function(String)? onFilledSubmit;
  final Function(String)? onChange;
  final Function? validation;
  final Function? onTap;
  final String? labelText;
  final String? hintText;
  final TextEditingController controller;
  final Color? fillColor;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final List<TextInputFormatter>? formatter;

  const DefaultTextFormField({
    super.key,
    this.isPassword = false,
    this.autoFocus = false,
    this.readOnly = false,
    this.isFilled = false,
    this.hasBorder = true,
    this.labelColorActive,
    this.required = true,
    this.isEnabled = true,
    this.borderSideWidth = 1.0,
    this.contentPaddingHorizontal = 10.0,
    this.borderSideColor,
    this.contentPaddingVertical = 10.0,
    this.borderRadius = 10,
    this.enabledBorderRadiusColor = Colors.grey,
    this.maxLength,
    this.maxLines,
    this.labelText,
    this.hintText,
    required this.textInputType,
    required this.controller,
    this.onFilledSubmit,
    this.onChange,
    this.borderSideEnabledColor,
    this.onTap,
    this.onPressSuffixIcon,
    this.validation,
    this.suffixIcon,
    this.prefixIcon,
    this.validationMsg,
    this.style,
    this.hintStyle,
    this.fillColor,
    this.formatter,
  });

  @override
  State<DefaultTextFormField> createState() => _DefaultTextFormFieldState();
}

class _DefaultTextFormFieldState extends State<DefaultTextFormField> {
  late FocusNode myFocusNode;
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    myFocusNode = FocusNode();
    // myFocusNode.addListener(() {
    //   setState(() {});
    // });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      style: widget.style,
      readOnly: widget.readOnly,

      obscureText: widget.isPassword && hidePassword,
      focusNode: myFocusNode,
      autofocus: widget.autoFocus,
      enabled: widget.isEnabled,
      obscuringCharacter: '●',
      controller: widget.controller,
      keyboardType: widget.textInputType,
      inputFormatters: [
        if (widget.textInputType == TextInputType.number||widget.textInputType == TextInputType.phone) ArabicToEnglishNumberFormatter(),
        if (widget.textInputType == TextInputType.phone) SaudiPhoneNumberFormatter(),
        if (widget.textInputType == TextInputType.emailAddress) FilteringTextInputFormatter.allow(RegExp(r'^[@.0-9a-zA-Z\s]*$')),
        ...?widget.formatter,
      ],
      onFieldSubmitted: (value) {
        if (widget.onFilledSubmit != null) {
          widget.onFilledSubmit!(value);
        }
      },
      onChanged: (value) {
        if (widget.onChange != null) {
          widget.onChange!(value);
        }
      },
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      validator: (String? value) {
        if (widget.validation != null) {
          return widget.validation!(value);
        } else if (value!.isEmpty && widget.required) {
          return widget.validationMsg ?? "this filed is required";
        } else {
          return null;
        }
      },
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsets.symmetric(
          vertical: widget.contentPaddingVertical,
          horizontal: widget.contentPaddingHorizontal,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
          borderSide: (!widget.hasBorder)
              ? BorderSide.none
              : BorderSide(color: widget.borderSideColor ?? AppColors.primaryColor, width: widget.borderSideWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
          borderSide: (!widget.hasBorder)
              ? BorderSide.none
              : BorderSide(color: widget.borderSideColor ?? AppColors.primaryColor, width: widget.borderSideWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
          borderSide: (!widget.hasBorder)
              ? BorderSide.none
              : BorderSide(
            color: widget.borderSideEnabledColor ?? const Color(0xffE6E6E6),
            width: widget.borderSideWidth,
          ),
        ),
        filled: true,
        fillColor: widget.fillColor ?? Colors.white,
        prefixIcon: widget.prefixIcon,
        labelText: widget.labelText,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle ?? Styles.hintText(context),
        errorMaxLines: 2,
        labelStyle: TextStyle(
          color: myFocusNode.hasFocus
              ? widget.labelColorActive ?? AppColors.primaryColor
              : widget.labelColorActive ?? Colors.grey,
          fontSize: MediaQuery.of(context).size.height * .02,
        ),
        suffixIcon:
        widget.suffixIcon ??
            (widget.isPassword
                ? InkWell(
              onTap: () {
                setState(() {
                  hidePassword = !hidePassword;
                });
              },
              child: Icon(hidePassword ? Icons.visibility_off_sharp : Icons.visibility_sharp),
            )
                : null),
      ),
    );
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    super.dispose();
  }
}
