import 'package:digital_trade_portal/core/utils/constants.dart';
import 'package:digital_trade_portal/core/utils/colors/colors.dart';
import 'package:digital_trade_portal/core/utils/text_styles/styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal/core/shared_widgets/brand_background.dart';
import '../../../../../core/utils/assets/assets.dart';
import 'splash_loading_indicator.dart';

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
    begin: .82,
    end: 1,
  ).animate(_curve(0, .55, Curves.easeOutBack));
  late final Animation<double> _titleFade = _curve(.35, .75, Curves.easeOut);
  late final Animation<double> _sloganFade = _curve(.50, .85, Curves.easeOut);
  late final Animation<double> _loaderFade = _curve(.65, 1, Curves.easeOut);

  Animation<double> _curve(double begin, double end, Curve curve) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: curve),
  );

  Future<void> navigate() async {
    final token = await CacheKeysManger.getToken();
    if (!mounted) return;
    if (token != "") {
      GoRouter.of(context).pushReplacement("/mainLayoutView");
    } else {
      GoRouter.of(context).pushReplacement("/loginView");
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      navigate();
      // context.read<GetAppSettingsCubit>().getAppSettings();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: BrandBackground()),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
            child: Column(
              children: [
                const Spacer(flex: 4),
                _buildLogo(context),
                SizedBox(height: AppConstants.height24(context)),
                _buildTitle(context),
                SizedBox(height: AppConstants.height5(context)),
                _buildSlogan(context),
                const Spacer(flex: 3),
                FadeTransition(opacity: _loaderFade, child: const SplashLoadingIndicator()),
                SizedBox(height: AppConstants.height30(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(BuildContext context) {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: Image.asset(AssetData.logo, width: MediaQuery.of(context).size.width, fit: BoxFit.contain),
      ),
    );
  }

  /// The app name painted with the same gradient used in the logo.
  Widget _buildTitle(BuildContext context) {
    return _RiseTransition(
      animation: _titleFade,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) =>
            AppColors.brandGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
        child: Text(
          "appName".tr(),
          textAlign: TextAlign.center,
          style: Styles.font24BoldBlack(context).copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSlogan(BuildContext context) {
    return _RiseTransition(
      animation: _sloganFade,
      child: Text(
        "appSlogan".tr(),
        textAlign: TextAlign.center,
        style: Styles.font14MediumGrey46(context).copyWith(letterSpacing: .2),
      ),
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
        child: Transform.translate(offset: Offset(0, (1 - animation.value) * 18), child: child),
      ),
    );
  }
}
