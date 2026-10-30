import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../i18n/app_dates.dart';
import '../i18n/money.dart';
import '../utils/theme/tokens.dart';
import '../utils/theme/typography.dart';

/// An amount, formatted for the active locale.
///
/// Takes the number the server sent. It does not add, subtract or round —
/// see [Money] for the rare case where the client must compute.
///
/// Amounts are the one place this design raises its voice: they are set in
/// tabular figures so that a column of them lines up and can be compared
/// down a list, which is what a trader actually does with a screen of
/// invoices. Pass [style] only to change the size, not the family.
class MoneyText extends StatelessWidget {
  final num amount;
  final String currency;
  final TextStyle? style;

  /// Renders a credit/refund in the error colour, so a negative line is not
  /// a minus sign the eye skips.
  final bool colorNegative;

  const MoneyText(
    this.amount, {
    super.key,
    this.currency = AppMoney.defaultCurrency,
    this.style,
    this.colorNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = amount < 0;
    return Text(
      AppMoney.format(amount, currency: currency, locale: context.locale.toString()),
      style: (style ?? AppType.ledger(context.tokens.ink)).copyWith(
        color: colorNegative && negative ? theme.colorScheme.error : null,
      ),
      // Amounts read left-to-right even in Arabic copy; without this the
      // currency and the digits swap ends.
      textDirection: TextDirection.ltr,
    );
  }
}

/// A server date. `""` and `null` both mean unset and render as [placeholder].
class DateText extends StatelessWidget {
  final DateTime? value;
  final bool withTime;
  final String placeholder;
  final TextStyle? style;

  const DateText(
    this.value, {
    super.key,
    this.withTime = false,
    this.placeholder = '—',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final text = value == null
        ? placeholder
        : withTime
            ? AppDates.dateTime(value, locale)
            : AppDates.date(value, locale);
    return Text(text, style: style);
  }
}

/// A chevron that points the way the reader travels: right in English, left
/// in Arabic.
class DirectionalChevron extends StatelessWidget {
  final double? size;
  final Color? color;

  const DirectionalChevron({super.key, this.size, this.color});

  /// `chevron_right` carries `matchTextDirection`: Flutter mirrors it in RTL
  /// by itself. Swapping it here as well flipped it back — every forward
  /// chevron pointed the wrong way in Arabic.
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: size,
      color: color ?? context.tokens.iconMuted,
    );
  }
}

/// Hides a widget without taking it out of the layout by position.
///
/// **The off-canvas trap:** parking something at a fixed negative `left` is a
/// web habit that breaks here — mirrored in RTL it re-enters the flow and
/// blanks the scroll area. Use this instead.
class HiddenBox extends StatelessWidget {
  final bool hidden;

  /// Keeps the child's space reserved, for a value that appears and
  /// disappears without the row jumping.
  final bool keepSpace;

  final Widget child;

  const HiddenBox({
    super.key,
    required this.hidden,
    required this.child,
    this.keepSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!hidden) return child;
    if (keepSpace) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child,
      );
    }
    return Offstage(child: child);
  }
}

/// A label/value row that stays correct in both directions: the label muted
/// at the start, the value at the end.
///
/// Rows inside a card are separated by rhythm, not rules (the card already
/// bounds them); pass [ruled] for a standalone stack that needs hairlines.
class DetailRow extends StatelessWidget {
  final String label;
  final Widget value;
  final bool ruled;

  /// Emphasises the value — a total, an outstanding amount.
  final bool emphasis;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.ruled = false,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      decoration: ruled
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider, width: AppTokens.ruleWidth),
              ),
            )
          : null,
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppTokens.space2 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasis
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DefaultTextStyle.merge(
                style: (emphasis ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                    ?.copyWith(fontWeight: FontWeight.w600, color: tokens.textPrimary),
                textAlign: TextAlign.end,
                child: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
