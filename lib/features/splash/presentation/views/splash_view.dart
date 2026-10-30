import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/session/session_state.dart';
import '../../../../core/shared_widgets/brand_background.dart';
import '../../../../core/ui/ui.dart';
import 'widgets/splash_view_body.dart';

/// The session gate: restore the token, call `/v2/bootstrap`, and hold the
/// brand while that happens. Where the user lands afterwards is the router's
/// redirect, not this screen's business.
///
/// The one thing it does own is the failure case — a bootstrap that fails is
/// not a reason to strand the user on an animation forever.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.tokens.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Transparent bars so the brand canvas paints under them; icon
      // brightness follows the theme (`dart:io` Platform is not needed —
      // `statusBarBrightness` is iOS-only and ignored on Android).
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: context.tokens.background,
        body: BlocBuilder<SessionCubit, SessionState>(
          buildWhen: (previous, current) => previous.status != current.status,
          builder: (context, state) {
            if (state.status != SessionStatus.error) return const SplashViewBody();

            final retry = context.read<SessionCubit>().refresh;
            // Offline is recoverable by the user; a coded failure usually is
            // not, so they get different screens and different copy — both on
            // the brand canvas rather than a bare white page.
            return Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: BrandBackground()),
                SafeArea(
                  child: state.errorCode == 'offline'
                      ? AppOfflineState(onRetry: retry)
                      : AppErrorState(
                          message: ErrorMessages.forCode(state.errorCode),
                          onRetry: retry,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
