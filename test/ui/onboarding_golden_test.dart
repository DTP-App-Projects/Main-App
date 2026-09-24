import 'package:digital_trade_portal/core/utils/theme/app_theme.dart';
import 'package:digital_trade_portal/core/utils/theme/tokens.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/data/models/bootstrap/journey.dart';
import 'package:digital_trade_portal/features/shared/onboarding/presentation/views/widgets/journey_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

/// Renders the redesigned wizard so it can be looked at:
///
///     flutter test test/ui/onboarding_golden_test.dart --dart-define=GOLDENS=true --update-goldens
///
/// A design artefact, not a regression lock — see `ledger_golden_test.dart`.
const _goldens = bool.fromEnvironment('GOLDENS');

void main() {
  setUpAll(() async {
    await useFakeStorage();
    await EasyLocalization.ensureInitialized();

    final loader = FontLoader('IBMPlex');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'));
    }
    await loader.load();
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('wizard $locale', skip: !_goldens, (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 2, 900 * 2)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            path: 'lib/core/language',
            startLocale: Locale(locale),
            fallbackLocale: const Locale('en'),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: buildAppTheme(ThemeTokens.traderFallback, locale),
                debugShowCheckedModeBanner: false,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const _WizardSample(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding-$locale.png'),
      );
    });
  }
}

/// The wizard's content, against the same widgets the real screen uses.
class _WizardSample extends StatelessWidget {
  const _WizardSample();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final journey = Journey.fromJson(const {
      'state_label': 'Awaiting your documents',
      'next_best_action': 'Upload your commercial registration to finish setup.',
      'profiles_ready': 1,
      'profiles_pending': 1,
      'trader': {
        'status': 'active',
        'score': 92,
        'missing': <String>[],
      },
      'supplier': {
        'status': 'pending_review',
        'score': 64,
        'missing': [
          'A bank account in the organization name is required.',
          'The commercial registration has expired.',
        ],
      },
    });

    final steps = <(String, bool, bool)>[
      ('Organization details', true, false),
      ('Trader profile', true, false),
      ('Supplier profile', true, true),
      ('Branches', true, false),
      ('Bank accounts', false, false),
      ('Documents', false, false),
    ];
    final done = steps.where((step) => step.$2).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('onboarding.title'.tr()),
        actions: const [Icon(Icons.apartment_outlined), SizedBox(width: 16)],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          OnboardingProgress(
            journey: journey,
            organizationStatus: 'draft',
            stepsComplete: done,
            stepsTotal: steps.length,
          ),
          _Rule(label: 'onboarding.checklist'.tr()),
          for (final (label, complete, locked) in steps)
            StepRow(label: label, complete: complete, locked: locked, onTap: () {}),
          _Rule(label: 'onboarding.reviewer_notes'.tr()),
          ReviewerNotes(title: 'profile.trader_title'.tr(), profile: journey.trader),
          ReviewerNotes(title: 'profile.supplier_title'.tr(), profile: journey.supplier),
          const SizedBox(height: AppTokens.space6),
          Padding(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              children: [
                FilledButton(
                  onPressed: null,
                  child: Text('onboarding.submit_for_review'.tr()),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  'onboarding.submit_blocked'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final String label;

  const _Rule({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppTokens.space4,
          AppTokens.space6,
          AppTokens.space4,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppTokens.space2),
            Container(height: AppTokens.ruleWidth, color: context.tokens.rule),
          ],
        ),
      );
}
