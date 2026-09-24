// easy_localization re-exports intl, whose `TextDirection` is a different
// type from the framework's and has no `ltr` — hide it.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../../../core/ui/ui.dart';
import '../../../../../../data/models/bootstrap/journey.dart';
import '../../../../../../data/models/trade/purchase_order.dart';

/// Where the organization stands, in one hero card.
///
/// The figure is the protagonist: "how much of this is left" is the only
/// question anyone opens this screen with, and the answer is a count. The
/// server's own `state_label` and `next_best_action` sit under it verbatim —
/// they are authored in the caller's language, so they are shown as sent
/// rather than mapped onto a vocabulary the client would have to invent.
class OnboardingProgress extends StatelessWidget {
  final Journey journey;
  final String organizationStatus;
  final int stepsComplete;
  final int stepsTotal;

  const OnboardingProgress({
    super.key,
    required this.journey,
    required this.organizationStatus,
    required this.stepsComplete,
    required this.stepsTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final label = journey.stateLabel.isNotEmpty ? journey.stateLabel : organizationStatus;

    return AppCard(
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('onboarding.steps_done'.tr(), style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppTokens.space1),
                    // A fraction reads left-to-right in both locales. Laid out
                    // in a plain Row it mirrored, so Arabic showed "6 / 4" for
                    // four of six — the same trap `MoneyText` exists to avoid.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        // Shrink to the digits: left to fill, the LTR override
                        // would drag the block to the left edge while its
                        // label stayed right.
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$stepsComplete', style: AppType.ledgerLarge(t.textPrimary)),
                          Text(
                            ' / $stepsTotal',
                            style: AppType.ledger(t.textTertiary, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: AppTokens.space3),
                Flexible(child: StatusChip(status: organizationStatus, label: label)),
              ],
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          // A segmented measure: one rounded teal segment per finished step.
          Row(
            children: [
              for (var index = 1; index <= stepsTotal; index++) ...[
                if (index > 1) const SizedBox(width: AppTokens.space1),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= stepsComplete ? t.primary : t.neutralTint,
                      borderRadius: AppTokens.fullRadius,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (journey.nextBestAction.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Icon(Icons.lightbulb_outline_rounded, size: 18, color: t.primary),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Text(
                    journey.nextBestAction,
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One step of the setup, as a Driver menu row.
///
/// The leading disc carries the state: a teal check when done, a clock in
/// warning tint while in review, and a neutral disc with the step's number
/// when there is still work to do.
class StepRow extends StatelessWidget {
  final String label;
  final bool complete;

  /// A profile that has already gone for review — done, and not editable.
  final bool locked;

  /// The step's position, shown in the disc while it is still to do.
  final int? number;

  final VoidCallback? onTap;

  const StepRow({
    super.key,
    required this.label,
    required this.complete,
    this.locked = false,
    this.number,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;

    final Widget disc;
    final String statusText;
    final Color statusColor;
    if (locked) {
      disc = const AppIconCircle(Icons.schedule_rounded, tone: AppTone.warning);
      statusText = 'onboarding.step_in_review'.tr();
      statusColor = t.warningText;
    } else if (complete) {
      disc = const AppIconCircle(Icons.check_rounded, tone: AppTone.brand);
      statusText = 'onboarding.step_done'.tr();
      statusColor = t.primary;
    } else {
      disc = Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.neutralTint, shape: BoxShape.circle),
        child: Text(
          number == null ? '•' : '$number',
          style: theme.textTheme.titleSmall?.copyWith(color: t.textSecondary),
          textDirection: TextDirection.ltr,
        ),
      );
      statusText = 'onboarding.step_todo'.tr();
      statusColor = t.textSecondary;
    }

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTokens.rowHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppTokens.space5,
              vertical: AppTokens.space3,
            ),
            child: Row(
              children: [
                disc,
                const SizedBox(width: AppTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppTokens.space2),
                  DirectionalChevron(size: 20, color: t.iconMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `trader.missing[]` / `supplier.missing[]` — **the reviewer's own words.**
///
/// Secondary to the step spine: a tinted note attached to the profile it came
/// from, never a second checklist competing with it for what to do next.
class ReviewerNotes extends StatelessWidget {
  final String title;
  final ProfileJourney profile;

  const ReviewerNotes({super.key, required this.title, required this.profile});

  @override
  Widget build(BuildContext context) {
    // A profile the organization never asked for has neither status nor gaps.
    if (profile.status.isEmpty && profile.missing.isEmpty) return const SizedBox.shrink();

    final hasGaps = profile.missing.isNotEmpty;
    // An en dash, not a bullet glyph: these are sentences the reviewer wrote,
    // not a list the app authored.
    final message = hasGaps
        ? profile.missing.map((item) => '–  $item').join('\n')
        : 'onboarding.nothing_missing'.tr();

    return AppBanner(
      title: title,
      message: message,
      tone: hasGaps ? AppTone.warning : AppTone.brand,
      icon: hasGaps ? Icons.rate_review_outlined : null,
      margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
      action: profile.status.isEmpty
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusChip(status: profile.status),
            ),
    );
  }
}

/// `journey.timeline[]` — the last few review events.
///
/// Maps onto the app's own timeline widget rather than carrying a second
/// implementation of the same thing.
class JourneyTimeline extends StatelessWidget {
  final List<JourneyEvent> events;

  const JourneyTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return DocumentTimeline(
      events: [
        for (final event in events)
          TimelineEvent(
            event: event.status,
            title: event.title,
            description: event.text,
            status: event.status,
            actorName: '',
            at: event.date,
          ),
      ],
    );
  }
}
