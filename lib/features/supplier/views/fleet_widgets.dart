import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Shared bits of the fleet screens (van sales, delivery contracts, internal
/// transfers).

/// A typed number, from either keyboard: `٣٫٥` and `3,5` both read 3.5.
/// Empty or unreadable → null.
double? parseFleetNumber(String raw) {
  final ascii = String.fromCharCodes(
    raw.trim().runes.map((r) {
      if (r >= 0x0660 && r <= 0x0669) return 0x30 + r - 0x0660;
      if (r >= 0x06F0 && r <= 0x06F9) return 0x30 + r - 0x06F0;
      if (r == 0x066B || r == 0x2C) return 0x2E; // ٫ and , → .
      return r;
    }),
  );
  return ascii.isEmpty ? null : double.tryParse(ascii);
}

/// `30` not `30.0`; three places for real fractions (stock is per 0.001).
String fmtQty(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);

/// One small figure: the number on top, its label under it.
class FleetFigure extends StatelessWidget {
  final String label;
  final double value;

  /// A token colour for a figure that needs attention; primary text otherwise.
  final Color? color;

  const FleetFigure({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fmtQty(value),
          textDirection: TextDirection.ltr,
          style: AppType.ledger(color ?? t.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}
