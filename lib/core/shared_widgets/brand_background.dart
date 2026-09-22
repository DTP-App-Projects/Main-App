import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';

/// Plain white canvas with two soft brand coloured glows in the opposite
/// corners, so the middle of the screen stays white and any content placed
/// on top of it keeps a clean, edge free background.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, this.opacity = .14});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final blobSize = width * 1.1;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -blobSize * .45,
            start: -blobSize * .30,
            child: _Blob(size: blobSize, color: AppColors.secondaryColor, opacity: opacity),
          ),
          PositionedDirectional(
            bottom: -blobSize * .45,
            end: -blobSize * .30,
            child: _Blob(size: blobSize, color: AppColors.primarySwatchColor, opacity: opacity),
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
