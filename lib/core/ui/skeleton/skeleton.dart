import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../utils/theme/tokens.dart';

// Driver skeletons: soft bars, card-shaped blocks.
const BorderRadius _line = AppTokens.smRadius;
const BorderRadius _block = AppTokens.lgRadius;

/// The one skeleton primitive. Every loading state in the app composes these
/// boxes into the shape of the real layout — a centred spinner is not a
/// loading state, and a screen without one is not done.
///
/// Boxes must sit under a [SkeletonShimmer], which supplies the sweep and
/// picks its colours from the **active workspace's** theme.
class Skeleton extends StatelessWidget {
  final double? width;

  /// Fraction of the available width. Use it to make text lines ragged rather
  /// than a stack of identical full-width bars.
  final double? widthFactor;

  final double height;
  final BorderRadiusGeometry radius;

  const Skeleton({
    super.key,
    this.width,
    this.widthFactor,
    this.height = 14,
    this.radius = _line,
  });

  /// A line of text.
  const Skeleton.line({Key? key, double widthFactor = 1, double height = 12})
      : this(key: key, widthFactor: widthFactor, height: height, radius: _line);

  /// A card, image or button placeholder.
  const Skeleton.box({Key? key, double? width, required double height})
      : this(key: key, width: width, height: height, radius: _block);

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
    );
    final factor = widthFactor;
    if (factor == null) return box;
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: factor.clamp(0.05, 1.0),
      child: box,
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
}

/// Wraps a skeleton tree in a gentle neutral shimmer on the page colour.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Shimmer.fromColors(
      baseColor: tokens.isDark ? tokens.border : const Color(0xFFE9EBF0),
      highlightColor: tokens.isDark ? tokens.surfaceRaised : const Color(0xFFF6F7FA),
      child: child,
    );
  }
}
