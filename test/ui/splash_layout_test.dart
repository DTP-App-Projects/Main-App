import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:digital_trade_portal/features/splash/presentation/views/splash_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';
import 'package:digital_trade_portal/core/shared_widgets/brand_background.dart';

/// The splash fills the screen in portrait and landscape.
void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();
  });
  for (final (name, size) in [('phone', const Size(390, 844)), ('landscape', const Size(844, 390))]) {
    testWidgets(name, (tester) async {
      tester.view..physicalSize = size * 2..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final (client, _) = clientWith(FakeAdapter.json(const {}));
      final store = SessionStore();
      final bootstrap = BootstrapRepository(client);
      final session = SessionCubit(store, bootstrap, WorkspaceCubit(store, OpsRepository(client)),
          PushService(AuthRepository(client), bootstrap, store));
      await tester.runAsync(() async {
        await tester.pumpWidget(BlocProvider.value(value: session, child: EasyLocalization(
          supportedLocales: const [Locale('ar'), Locale('en')],
          path: 'lib/core/language', startLocale: const Locale('ar'), fallbackLocale: const Locale('ar'),
          child: Builder(builder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(ThemeTokens.traderFallback, 'ar'),
            locale: context.locale, localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const SplashView())),
        )));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(seconds: 2));
      // The brand canvas spans the whole screen, not just the widest line of
      // text (it used to stop at ~70% of the width, leaving a grey strip).
      expect(tester.getSize(find.byType(BrandBackground)), size);
      // And the logo sits in the horizontal middle.
      expect(tester.getCenter(find.byType(Image)).dx, closeTo(size.width / 2, 0.5));
    });
  }
}
