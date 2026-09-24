import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';

typedef TradeEntry = ({String label, IconData icon, String route});
typedef TradeSection = ({String label, List<TradeEntry> entries});

/// The "Trade" tab: the role's hub for the whole trade cycle, grouped the
/// way the Driver account screen groups its menu (S3) — a section label over
/// a card of 72dp rows with tinted icon discs.
class TradeHub extends StatelessWidget {
  final List<TradeSection> sections;

  const TradeHub({super.key, required this.sections});

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AppHeader(
              title: 'nav.trade'.tr(),
              subtitle: 'trade.subtitle'.tr(),
              bottom: const RoleBadge(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppTokens.gutter,
              0,
              AppTokens.gutter,
              AppTokens.space8,
            ),
            sliver: SliverList.list(
              children: [
                for (final section in sections) ...[
                  AppSectionLabel(section.label),
                  AppMenuGroup(
                    children: [
                      for (final entry in section.entries)
                        AppMenuRow(
                          icon: entry.icon,
                          title: entry.label,
                          onTap: () => context.push(entry.route),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}
