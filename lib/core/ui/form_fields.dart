import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../utils/theme/tokens.dart';
import 'app_buttons.dart';
import 'app_surfaces.dart';

/// Form primitives shared by every form in the app.
///
/// Driver field anatomy: the label sits **above** the field (14/500, red `*`
/// when required), the field is an off-white well with a hairline border, and
/// an error turns the border deep red with the message underneath.
///
/// The one non-obvious rule: a field shows either its client-side validation
/// message or the server's `bag` entry for the same slot — never both, and
/// never a raw error key.

/// A label above any field-shaped child.
class AppFieldShell extends StatelessWidget {
  final String? label;
  final bool required;
  final Widget child;

  /// Space under the whole field; forms stack these.
  final double bottom;

  const AppFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.bottom = AppTokens.space5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null && label!.isNotEmpty) ...[
            Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (required)
                    TextSpan(text: '*', style: TextStyle(color: t.fieldError)),
                ],
              ),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppTokens.space2),
          ],
          child,
        ],
      ),
    );
  }
}

class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? serverError;
  final String? helper;
  final bool obscure;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final int? maxLength;
  final int maxLines;

  /// Lets a password manager fill and, more importantly, *save*.
  final Iterable<String>? autofillHints;

  /// Used to clear a stale server error as soon as the user edits the field
  /// it was attached to.
  final ValueChanged<String>? onChanged;

  final Widget? suffix;

  /// Marks the label with a red `*`.
  final bool required;

  /// A leading icon inside the field (mail, lock, phone…).
  final IconData? icon;

  /// An example value (Driver: "Example@yourmail.com").
  final String? hint;

  /// Unit / currency after the value ("SAR", "days", "%").
  final String? suffixText;

  /// Forces a direction — IBANs, emails, codes read LTR in Arabic too.
  final TextDirection? textDirection;

  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.serverError,
    this.helper,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.autofillHints,
    this.onChanged,
    this.suffix,
    this.required = false,
    this.icon,
    this.hint,
    this.suffixText,
    this.textDirection,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  /// Reveal is per-field and resets when the screen is rebuilt from scratch.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final obscured = widget.obscure && !_revealed;
    final t = context.tokens;
    final hasError = widget.serverError != null;

    return AppFieldShell(
      label: widget.label,
      required: widget.required,
      child: TextFormField(
        controller: widget.controller,
        obscureText: obscured,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        maxLength: widget.maxLength,
        maxLines: obscured ? 1 : widget.maxLines,
        minLines: widget.maxLines > 1 ? widget.maxLines.clamp(1, 3) : null,
        validator: widget.validator,
        autofillHints: widget.enabled ? widget.autofillHints : null,
        onChanged: widget.onChanged,
        textDirection: widget.textDirection,
        decoration: InputDecoration(
          hintText: widget.hint,
          helperText: widget.helper,
          counterText: '',
          errorText: widget.serverError,
          prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 22),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _revealed ? 'auth.hide_password'.tr() : 'auth.show_password'.tr(),
                  icon: Icon(
                    _revealed ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 22,
                    // Driver S2: the eye turns red with the field.
                    color: hasError ? t.fieldError : t.textPrimary,
                  ),
                  onPressed: () => setState(() => _revealed = !_revealed),
                )
              : (widget.suffix ?? (widget.suffixText == null ? null : AppUnitSuffix(widget.suffixText!))),
        ),
      ),
    );
  }
}

/// A unit or currency at a field's end edge ("SAR", "days", "%"), set apart
/// from the value instead of running into it.
class AppUnitSuffix extends StatelessWidget {
  final String unit;

  const AppUnitSuffix(this.unit, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: AppTokens.space2, end: AppTokens.space4),
        child: Text(
          unit,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.textTertiary),
        ),
      );
}

InputDecoration _pickerDecoration(String? error, {String? hint}) => InputDecoration(
      errorText: error,
      hintText: hint ?? 'lookup.choose'.tr(),
    );

/// A dropdown over anything with an int id.
class IdPicker<T> extends StatelessWidget {
  final String label;
  final int? value;
  final List<T> items;
  final int Function(T) idOf;
  final String Function(T) labelOf;
  final String? error;
  final bool required;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const IdPicker({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
    this.error,
    this.required = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // A value whose row is not in the list yet (a city before its country is
    // chosen) would assert inside DropdownButtonFormField.
    final known = items.any((item) => idOf(item) == value);
    final t = context.tokens;

    return AppFieldShell(
      label: label,
      required: required,
      child: DropdownButtonFormField<int>(
        initialValue: known ? value : null,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, color: t.textSecondary),
        dropdownColor: t.surfaceRaised,
        borderRadius: AppTokens.mdRadius,
        decoration: _pickerDecoration(error),
        items: items
            .map((item) => DropdownMenuItem(
                  value: idOf(item),
                  child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (enabled && items.isNotEmpty) ? onChanged : null,
        validator: (v) => (required && v == null) ? 'validation.required'.tr() : null,
      ),
    );
  }
}

/// A dropdown over a fixed set of server enum values (`branch_type`,
/// `supplier_nature`, …), labelled from the translation file.
class CodePicker extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> codes;
  final String Function(String code) labelOf;
  final String? error;
  final bool required;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const CodePicker({
    super.key,
    required this.label,
    required this.value,
    required this.codes,
    required this.labelOf,
    required this.onChanged,
    this.error,
    this.required = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppFieldShell(
      label: label,
      required: required,
      child: DropdownButtonFormField<String>(
        initialValue: codes.contains(value) ? value : null,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, color: t.textSecondary),
        dropdownColor: t.surfaceRaised,
        borderRadius: AppTokens.mdRadius,
        decoration: _pickerDecoration(error),
        items: codes
            .map((code) => DropdownMenuItem(
                  value: code,
                  child: Text(labelOf(code), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: enabled ? onChanged : null,
        validator: (v) => (required && v == null) ? 'validation.required'.tr() : null,
      ),
    );
  }
}

/// A non-blocking banner for the form-level message — a credential failure, a
/// suspended account, offline. Localized before it gets here.
class FormMessage extends StatelessWidget {
  final String? message;
  final bool success;

  const FormMessage({super.key, this.message, this.success = false});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return AppBanner(
      message: message!,
      tone: success ? AppTone.brand : AppTone.danger,
    );
  }
}

/// The screen's primary CTA: the Driver gradient button.
class SubmitButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SubmitButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) =>
      AppButton.primary(label: label, onPressed: onPressed, busy: busy, icon: icon);
}

class AppValidators {
  AppValidators._();

  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'validation.required'.tr() : null;

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.required'.tr();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return ok ? null : 'validation.email'.tr();
  }

  /// The server's own rule is `min:6` on every password field.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'validation.required'.tr();
    return value.length < 6 ? 'validation.password_min'.tr() : null;
  }
}
