import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/theme/tokens.dart';
import 'app_buttons.dart';

/// The Driver confirmation dialog: centred title (red when destructive),
/// centred body, two equal buttons side by side.
///
/// The emphasis rule from the Driver logout dialog: the **safe** action is the
/// solid one; a destructive confirm is the quieter red outline. Resolves to
/// `true` only when the user confirmed.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _AppDialog(
      title: title,
      body: body,
      destructive: destructive,
      confirmLabel: confirmLabel ?? 'common.confirm'.tr(),
      cancelLabel: cancelLabel ?? 'common.cancel'.tr(),
      onConfirm: () => Navigator.of(context).pop(true),
    ),
  );
  return result ?? false;
}

/// A confirmation that also collects a note. Resolves to the note (possibly
/// empty when [required] is false), or `null` when cancelled.
Future<String?> showAppReasonDialog(
  BuildContext context, {
  required String title,
  String? body,
  String? hint,
  String? confirmLabel,
  bool required = false,
  bool destructive = false,
  int maxLength = 2000,

  /// Confirm stays disabled until the note reaches this many characters;
  /// [lengthRule] (already localized) explains why, under the field.
  int minLength = 0,
  String? lengthRule,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: title,
        body: body,
        hint: hint,
        confirmLabel: confirmLabel ?? 'common.continue'.tr(),
        required: required,
        destructive: destructive,
        maxLength: maxLength,
        minLength: minLength,
        lengthRule: lengthRule,
      ),
    );

class _AppDialog extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? content;
  final bool destructive;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;

  const _AppDialog({
    required this.title,
    required this.body,
    required this.destructive,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);

    final cancel = destructive
        ? AppButton.solid(
            label: cancelLabel,
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          )
        : AppButton.outline(
            label: cancelLabel,
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          );
    final confirm = destructive
        ? AppButton.outlineDanger(label: confirmLabel, height: 48, onPressed: onConfirm)
        : AppButton.solid(label: confirmLabel, height: 48, onPressed: onConfirm);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: destructive ? t.dangerText : t.textPrimary,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: AppTokens.space3),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: AppTokens.space4),
              content!,
            ],
            const SizedBox(height: AppTokens.space6),
            Row(
              children: [
                // The safe action takes the reading-start side (Driver S5).
                Expanded(child: destructive ? cancel : confirm),
                const SizedBox(width: AppTokens.space3),
                Expanded(child: destructive ? confirm : cancel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? body;
  final String? hint;
  final String confirmLabel;
  final bool required;
  final bool destructive;
  final int maxLength;
  final int minLength;
  final String? lengthRule;

  const _ReasonDialog({
    required this.title,
    required this.body,
    required this.hint,
    required this.confirmLabel,
    required this.required,
    required this.destructive,
    required this.maxLength,
    required this.minLength,
    required this.lengthRule,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = _controller.text.trim().length;
    final longEnough = length >= widget.minLength;
    final canConfirm = (!widget.required || length > 0) && longEnough;
    return _AppDialog(
      title: widget.title,
      body: widget.body,
      destructive: widget.destructive,
      confirmLabel: widget.confirmLabel,
      cancelLabel: 'common.cancel'.tr(),
      onConfirm: canConfirm ? () => Navigator.of(context).pop(_controller.text.trim()) : null,
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          hintText: widget.hint,
          counterText: '',
          helperText: (widget.minLength > 0 && !longEnough) ? widget.lengthRule : null,
          border: const OutlineInputBorder(borderRadius: AppTokens.lgRadius),
        ),
      ),
    );
  }
}

/// The Driver bottom sheet: r24 top corners, a handle, a start-aligned title
/// (red when destructive), a quiet body line, then content. Keyboard-aware and
/// sized to its content up to 90% of the screen.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool destructive = false,
  bool isDismissible = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      showDragHandle: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppTokens.gutter,
            0,
            AppTokens.gutter,
            AppTokens.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) AppSheetHeader(title: title, subtitle: subtitle, destructive: destructive),
              Builder(builder: builder),
            ],
          ),
        ),
      ),
    );

/// The title block of a Driver sheet, for sheets that build their own body.
class AppSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool destructive;

  const AppSheetHeader({super.key, required this.title, this.subtitle, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(color: destructive ? t.dangerText : null),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTokens.space2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
