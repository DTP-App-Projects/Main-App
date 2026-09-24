import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/i18n/locale_switch.dart';
import '../../../../../../core/shared_widgets/brand_background.dart';
import '../../../../../../core/ui/ui.dart';

/// Shared chrome for the unauthenticated screens — the Driver login (S1):
/// a faint brand glow, the language pill, the logo tile, a bold title, the
/// fields in a white form card, and the primary CTA *outside* the card.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// The form. Drawn inside the white form card unless [plain].
  final List<Widget> children;
  final bool showBack;

  /// `(current, total)` for a multi-step flow, 1-based, drawn as a teal
  /// segmented bar.
  final (int, int)? step;

  /// A form-level message, above the card so it is not scrolled away by the
  /// field it is about.
  final Widget? banner;

  /// The primary action, under the card.
  final Widget? cta;

  /// Secondary links under the CTA ("No account? Create one").
  final Widget? footer;

  /// The brand tile above the title — for entry screens, not mid-flow steps.
  final bool showLogo;

  /// Lay [children] straight on the page (for choice cards that are cards
  /// themselves) instead of inside the form card.
  final bool plain;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = true,
    this.step,
    this.banner,
    this.cta,
    this.footer,
    this.showLogo = false,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final canPop = showBack && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: t.isDark ? t.background : Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: BrandBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                // Keeps copy and fields readable on a tablet.
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.gutter,
                    AppTokens.space4,
                    AppTokens.gutter,
                    AppTokens.space8,
                  ),
                  children: [
                    Row(
                      children: [
                        if (canPop)
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                            icon: const AppBackIcon(),
                            padding: EdgeInsets.zero,
                          ),
                        const Spacer(),
                        // The one pre-auth surface where the language can be
                        // changed — someone who cannot read the screen needs it.
                        const LocaleToggleButton(),
                      ],
                    ),
                    SizedBox(height: showLogo ? AppTokens.space8 : AppTokens.space6),
                    if (showLogo) ...[
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppLogoTile(size: 80),
                      ),
                      const SizedBox(height: AppTokens.space6),
                    ],
                    if (step case (final current, final total)) ...[
                      _StepCounter(current: current, total: total),
                      const SizedBox(height: AppTokens.space5),
                    ],
                    Text(title, style: theme.textTheme.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyLarge?.copyWith(color: t.textSecondary),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space6),
                    ?banner,
                    if (plain)
                      ...children
                    else
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    if (cta != null) ...[const SizedBox(height: AppTokens.space8), cta!],
                    ?footer,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Step 2 of 3` over a teal segmented bar.
class _StepCounter extends StatelessWidget {
  final int current;
  final int total;

  const _StepCounter({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'auth.step_of'.tr(args: ['$current', '$total']),
          style: theme.textTheme.labelMedium?.copyWith(
            color: t.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        Row(
          children: [
            for (var index = 1; index <= total; index++) ...[
              if (index > 1) const SizedBox(width: AppTokens.space1),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= current ? t.primary : t.primaryTint,
                    borderRadius: AppTokens.fullRadius,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A row of two: the quiet question and the action that answers it. A `Wrap`
/// rather than a `Row`, so the pair does not drift apart in RTL.
class AuthFooterLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onPressed;

  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: AppTokens.space4),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
        ),
        AppButton.text(label: action, onPressed: onPressed),
      ],
    ),
  );
}

/// A selectable option card: icon disc, title, hint, radio mark on the end
/// side. Teal hairline + brand disc when selected.
class AuthChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  const AuthChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: AppTokens.lgRadius,
          border: Border.all(
            color: selected ? t.primary : t.border,
            width: selected ? 1.5 : AppTokens.ruleWidth,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTokens.lgRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Row(
                children: [
                  AppIconCircle(icon, tone: selected ? AppTone.brand : AppTone.neutral),
                  const SizedBox(width: AppTokens.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(body, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space3),
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? t.primary : t.iconMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
