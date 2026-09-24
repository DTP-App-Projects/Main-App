import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/shared_widgets/brand_background.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/colors/colors.dart';
import 'splash_loading_indicator.dart';

/// The brand, held while bootstrap resolves: the Driver login canvas, the
/// logo tile, the name in the brand gradient and the slogan.
class SplashViewBody extends StatefulWidget {
  const SplashViewBody({super.key});

  @override
  State<SplashViewBody> createState() => _SplashViewBodyState();
}

class _SplashViewBodyState extends State<SplashViewBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _logoFade = _curve(0, .45, Curves.easeOut);
  late final Animation<double> _logoScale = Tween<double>(
    begin: .9,
    end: 1,
  ).animate(_curve(0, .55, Curves.easeOutCubic));
  late final Animation<double> _titleFade = _curve(.35, .75, Curves.easeOut);
  late final Animation<double> _sloganFade = _curve(.50, .85, Curves.easeOut);
  late final Animation<double> _loaderFade = _curve(.65, 1, Curves.easeOut);

  Animation<double> _curve(double begin, double end, Curve curve) => CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );

  // Navigation is not this widget's job: the router redirects off
  // SessionCubit as soon as bootstrap resolves.
  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Stack(
      children: [
        const Positioned.fill(child: BrandBackground()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
            child: Column(
              children: [
                const Spacer(flex: 4),
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(scale: _logoScale, child: const AppLogoTile(size: 112)),
                ),
                const SizedBox(height: AppTokens.space6),
                _RiseTransition(
                  animation: _titleFade,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => AppColors.brandGradient
                        .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                    child: Text(
                      'app.name'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                _RiseTransition(
                  animation: _sloganFade,
                  child: Text(
                    'app.slogan'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                  ),
                ),
                const Spacer(flex: 3),
                FadeTransition(opacity: _loaderFade, child: const SplashLoadingIndicator()),
                const SizedBox(height: AppTokens.space8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fades its child in while sliding it slightly upwards.
class _RiseTransition extends StatelessWidget {
  const _RiseTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - animation.value) * 12), child: child),
      ),
    );
  }
}
