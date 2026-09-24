import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';

/// Three brand coloured dots pulsing in sequence, used as the splash loader.
class SplashLoadingIndicator extends StatefulWidget {
  const SplashLoadingIndicator({super.key});

  @override
  State<SplashLoadingIndicator> createState() => _SplashLoadingIndicatorState();
}

class _SplashLoadingIndicatorState extends State<SplashLoadingIndicator> with SingleTickerProviderStateMixin {
  static const int _dotsCount = 3;
  static const double _dotsDelay = .16;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed dp: a height-relative dot vanished on short or landscape screens.
    const dotSize = 5.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_dotsCount, (index) {
            final progress = (_controller.value + index * _dotsDelay) % 1;
            final pulse = math.sin(progress * math.pi).abs();

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: dotSize * .55),
              child: Transform.scale(
                scale: .70 + .30 * pulse,
                child: Container(
                  width: dotSize * 2,
                  height: dotSize * 2,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: .65 - .65 * pulse),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
