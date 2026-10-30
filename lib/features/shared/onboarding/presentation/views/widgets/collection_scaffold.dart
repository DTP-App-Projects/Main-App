import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/ui/collection_cubit.dart';
import '../../../../../../core/ui/ui.dart';
import '../../view_models/onboarding_cubit.dart';

/// Branches, bank accounts and documents are the same screen three times:
/// a subtitle, a list, an add button, and an editor in a sheet.
class CollectionScaffold<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyMessage;
  final String addLabel;
  final CollectionState<T> state;
  final Future<void> Function() onRetry;
  final VoidCallback onAdd;
  final Widget Function(T item) itemBuilder;

  /// The content's own icon for the empty state (a store for branches…).
  final IconData emptyIcon;

  /// Which wizard step this screen owns.
  ///
  /// Reported to the wizard on the way out — and **only if a row was actually
  /// saved**, so backing out of a screen you only looked at costs nothing.
  /// The wizard used to re-read its whole state either way.
  final OnboardingStepKind changeKind;

  const CollectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.addLabel,
    required this.state,
    required this.onRetry,
    required this.onAdd,
    required this.itemBuilder,
    required this.changeKind,
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sticky: reopening the editor resets `submit`, which used to make a
    // saved row look unsaved to the wizard.
    final changed = state.savedAny;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(changed ? changeKind : null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          // The framework's own back button would pop without a result.
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(changed ? changeKind : null),
          ),
        ),
        // Offered here only when there is already a list; an empty screen
        // makes its own invitation below, and two "add" buttons on one screen
        // is one too many.
        floatingActionButton: state.loading || state.items.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(addLabel),
              ),
        body: Builder(
          builder: (context) {
            if (state.loading) return const ListSkeleton(rows: 4);
            if (state.offline) return AppOfflineState(onRetry: onRetry);
            if (state.errorMessage != null) {
              return AppErrorState(
                message: state.errorMessage!.isEmpty ? 'errors.generic'.tr() : state.errorMessage!,
                onRetry: onRetry,
              );
            }
            if (state.items.isEmpty) {
              return AppEmptyState(
                icon: emptyIcon,
                title: emptyMessage,
                body: subtitle,
                actionLabel: addLabel,
                onAction: onAdd,
              );
            }

            return RefreshIndicator(
              onRefresh: onRetry,
              child: ListView(
                // The bottom inset clears the floating add button.
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppTokens.gutter,
                  AppTokens.space2,
                  AppTokens.gutter,
                  96,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppTokens.space1,
                      0,
                      AppTokens.space1,
                      AppTokens.space4,
                    ),
                    child: Text(subtitle, style: theme.textTheme.bodySmall),
                  ),
                  for (final item in state.items) itemBuilder(item),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The editor half: a Driver bottom sheet holding whatever fields the row
/// needs, sized to its content.
Future<void> showEditorSheet({
  required BuildContext context,
  required String title,
  required List<Widget> Function(BuildContext context) fields,
}) =>
    showAppSheet<void>(
      context: context,
      title: title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: fields(sheetContext),
      ),
    );

/// A row in one of the lists, as a Driver item card: the content's icon in a
/// tinted disc, title, subtitle, a trailing status and a chevron.
///
/// [status] tints the disc and the trailing text when the row carries one —
/// an expired document is the case that matters.
class CollectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final IconData icon;

  /// A document status, when the row has one. Empty means neutral.
  final String status;

  final VoidCallback onTap;

  const CollectionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.status = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final hasStatus = status.isNotEmpty;
    final tone = hasStatus ? _toneFor(toneForStatus(status)) : AppTone.brand;

    return Semantics(
      button: true,
      child: AppCard.item(
        onTap: onTap,
        child: Row(
          children: [
            AppIconCircle(icon, tone: tone),
            const SizedBox(width: AppTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTokens.space2),
              // A status reads as a pill; a plain value (a currency, "Default")
              // stays quiet text.
              if (hasStatus)
                StatusChip(status: status, label: trailing)
              else
                Text(trailing!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(width: AppTokens.space2),
            DirectionalChevron(size: 20, color: t.iconMuted),
          ],
        ),
      ),
    );
  }

  static AppTone _toneFor(StatusTone tone) => switch (tone) {
        StatusTone.good => AppTone.brand,
        StatusTone.inFlight => AppTone.info,
        StatusTone.warn => AppTone.warning,
        StatusTone.danger => AppTone.danger,
        StatusTone.unknown => AppTone.neutral,
      };
}
