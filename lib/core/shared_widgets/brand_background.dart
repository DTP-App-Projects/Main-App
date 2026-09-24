import 'package:flutter/material.dart';

import '../utils/colors/colors.dart';
import '../utils/theme/tokens.dart';

/// The Driver login canvas (S1): the page colour with two soft brand glows —
/// bluish top-right, greenish bottom-left — so the middle stays clean for
/// content. Physical corners, like the gradient: a brand mark, not a
/// reading direction.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, this.opacity});

  /// Glow strength; defaults to a quieter value in dark mode.
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final blobSize = width * 1.1;
    final strength = opacity ?? (t.isDark ? .10 : .14);

    return DecoratedBox(
      decoration: BoxDecoration(color: t.isDark ? t.background : Colors.white),
      child: Stack(
        children: [
          Positioned(
            top: -blobSize * .45,
            right: -blobSize * .30,
            child: _Blob(size: blobSize, color: AppColors.brandBlue, opacity: strength),
          ),
          Positioned(
            bottom: -blobSize * .45,
            left: -blobSize * .30,
            child: _Blob(size: blobSize, color: AppColors.brandTeal, opacity: strength),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
