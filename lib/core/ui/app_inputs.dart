import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/app_dates.dart';
import '../utils/theme/tokens.dart';
import 'form_fields.dart';

/// A search well with a leading search icon and a clear button.
class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.hint,
    this.autofocus = false,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      AppTokens.gutter,
      AppTokens.space3,
      AppTokens.gutter,
      AppTokens.space2,
    ),
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted ?? widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hint ?? 'common.search'.tr(),
          fillColor: t.surface,
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'common.clear'.tr(),
                  icon: Icon(Icons.close_rounded, size: 20, color: t.textSecondary),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// A date field: calendar icon, the formatted date (or a hint), and a clear
/// button when the date is optional.
class AppDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  /// Shown when [value] is null and the field is optional.
  final VoidCallback? onClear;
  final String? error;
  final String? hint;
  final bool required;
  final bool withTime;
  final bool enabled;

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.error,
    this.hint,
    this.required = false,
    this.withTime = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();
    final text = value == null
        ? (hint ?? (required ? 'lookup.choose'.tr() : 'common.optional'.tr()))
        : (withTime ? AppDates.dateTime(value, locale) : AppDates.date(value, locale));

    return AppFieldShell(
      label: label,
      required: required,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppTokens.mdRadius,
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            errorText: error,
            enabled: enabled,
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            suffixIcon: (value != null && onClear != null && enabled)
                ? IconButton(
                    tooltip: 'common.clear'.tr(),
                    icon: Icon(Icons.close_rounded, size: 20, color: t.textSecondary),
                    onPressed: onClear,
                  )
                : null,
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: value == null ? t.textTertiary : t.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// A compact numeric field for quantities, with an optional unit and label.
///
/// Stateless over a controller the caller owns, so the existing screen
/// logic (parse on change, validate against a max) stays where it is.
class AppQtyField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final ValueChanged<String> onChanged;
  final String? unit;
  final String? error;
  final String? helper;
  final bool decimal;
  final bool enabled;

  const AppQtyField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.label,
    this.unit,
    this.error,
    this.helper,
    this.decimal = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => AppFieldShell(
        label: label,
        bottom: AppTokens.space3,
        child: TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,٠-٩٫]' : r'[0-9٠-٩]')),
          ],
          // Figures read LTR in both languages.
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: unit == null ? null : AppUnitSuffix(unit!),
            errorText: error,
            helperText: helper,
          ),
        ),
      );
}
