import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:digital_trade_portal/core/ui/ui.dart';
import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/features/shared/auth/presentation/views/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';
import 'golden_support.dart';

/// Renders the redesigned auth screens so they can be looked at:
///
///     flutter test test/ui/auth_golden_test.dart --dart-define=GOLDENS=true --update-goldens
///
/// A design artefact, not a regression lock — see `ledger_golden_test.dart`
/// for why these are gated. The samples are built from the real
/// `AuthScaffold`, fields and buttons, so they cannot drift from the screens.
const _goldens = bool.fromEnvironment('GOLDENS');

void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();
    await loadGoldenFonts();
  });

  Widget frame(String locale, Brightness brightness, Widget home) {
    final theme = buildAppTheme(ThemeTokens.traderFallback, locale, brightness: brightness);
    return EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'lib/core/language',
      startLocale: Locale(locale),
      fallbackLocale: const Locale('en'),
      child: Builder(
        builder: (context) => MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: home,
        ),
      ),
    );
  }

  final screens = <String, Widget>{
    'login': const _LoginSample(),
    'login-error': const _LoginSample(errors: true),
    'mode': const _ModeSample(),
    'details': const _DetailsSample(),
  };

  for (final entry in screens.entries) {
    for (final locale in ['ar', 'en']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        // Dark only for the entry screen, to keep the set small.
        if (brightness == Brightness.dark && entry.key != 'login') continue;
        final suffix = brightness == Brightness.dark ? '-dark' : '';
        testWidgets('${entry.key} $locale$suffix', skip: !_goldens, (tester) async {
          tester.view
            ..physicalSize = const Size(390 * 2, 844 * 2)
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.runAsync(() async {
            await tester.pumpWidget(frame(locale, brightness, entry.value));
            await Future<void>.delayed(const Duration(milliseconds: 60));
          });
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/auth-${entry.key}-$locale$suffix.png'),
          );
        });
      }
    }
  }
}

class _LoginSample extends StatelessWidget {
  final bool errors;

  const _LoginSample({this.errors = false});

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showBack: false,
        showLogo: true,
        title: 'auth.welcome'.tr(),
        subtitle: 'auth.subtitle'.tr(),
        cta: SubmitButton(busy: false, label: 'auth.sign_in'.tr(), onPressed: () {}),
        footer: AuthFooterLink(
          question: 'auth.no_account'.tr(),
          action: 'auth.create_account'.tr(),
          onPressed: () {},
        ),
        children: [
          AppField(
            controller: TextEditingController(),
            label: 'auth.email'.tr(),
            required: true,
            icon: Icons.mail_outline_rounded,
            hint: 'auth.email_hint'.tr(),
            textDirection: TextDirection.ltr,
            serverError: errors ? 'validation.required'.tr() : null,
          ),
          AppField(
            controller: TextEditingController(text: errors ? '' : 'hunter2hunter2'),
            label: 'auth.password'.tr(),
            required: true,
            icon: Icons.lock_outline_rounded,
            hint: '••••••••',
            obscure: true,
            serverError: errors ? 'validation.password_min'.tr() : null,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton.text(label: 'auth.forgot_password'.tr(), onPressed: () {}, height: 40),
          ),
        ],
      );
}

class _ModeSample extends StatelessWidget {
  const _ModeSample();

  @override
  Widget build(BuildContext context) => AuthScaffold(
        step: (1, 2),
        plain: true,
        title: 'register.mode_title'.tr(),
        subtitle: 'register.mode_subtitle'.tr(),
        cta: AppButton.primary(label: 'common.continue'.tr(), onPressed: () {}),
        children: [
          AuthChoiceCard(
            icon: Icons.storefront_outlined,
            title: 'register.mode_trader'.tr(),
            body: 'register.mode_trader_hint'.tr(),
            selected: false,
            onTap: () {},
          ),
          AuthChoiceCard(
            icon: Icons.local_shipping_outlined,
            title: 'register.mode_supplier'.tr(),
            body: 'register.mode_supplier_hint'.tr(),
            selected: true,
            onTap: () {},
          ),
          AuthChoiceCard(
            icon: Icons.swap_horiz_rounded,
            title: 'register.mode_hybrid'.tr(),
            body: 'register.mode_hybrid_hint'.tr(),
            selected: false,
            onTap: () {},
          ),
        ],
      );
}

class _DetailsSample extends StatelessWidget {
  const _DetailsSample();

  @override
  Widget build(BuildContext context) => AuthScaffold(
        step: (2, 2),
        plain: true,
        title: 'register.details_title'.tr(),
        subtitle: 'register.details_body'.tr(),
        children: [
          AppSectionLabel('register.section_you'.tr(),
              padding: const EdgeInsetsDirectional.only(bottom: 12, start: 4)),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppField(
                  controller: TextEditingController(text: 'Khalid'),
                  label: 'register.first_name'.tr(),
                  required: true,
                ),
                IdPicker<int>(
                  label: 'register.country'.tr(),
                  value: null,
                  items: const [1, 2],
                  idOf: (i) => i,
                  labelOf: (i) => '$i',
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ],
      );
}
