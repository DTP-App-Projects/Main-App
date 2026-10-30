import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paged.dart';
import '../../../core/ui/form_status.dart';
import '../../../core/ui/paged_cubit.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/roots/app_router.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/api_paths.dart';
import '../../../data/models/compliance/chain.dart';
import '../../../data/repositories/compliance_repository.dart';
import 'compliance_cubits.dart';
import 'files/document_file_view.dart';

String messageOr(String? message) =>
    (message == null || message.isEmpty) ? 'errors.generic'.tr() : message;

/// A whole list screen: app bar, paginated rows, pull-to-refresh, skeleton,
/// empty state. [actions] go in the app bar; [fab] for "new".
class PagedScreen<T> extends StatelessWidget {
  final String title;
  final Future<ApiResult<Paged<T>>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyBody;
  final Widget? header;
  final Widget? fab;
  final List<Widget> actions;

  const PagedScreen({
    super.key,
    required this.title,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyBody,
    this.header,
    this.fab,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FetchPagedCubit<T>(fetch)..load(),
        child: Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          floatingActionButton: fab,
          body: BlocBuilder<FetchPagedCubit<T>, PagedState<T>>(
            builder: (context, state) {
              final cubit = context.read<FetchPagedCubit<T>>();
              return PagedListView<T>(
                state: state,
                onRefresh: cubit.refresh,
                onLoadMore: cubit.loadMore,
                header: header,
                emptyIcon: emptyIcon,
                emptyTitle: emptyTitle,
                emptyBody: emptyBody,
                itemBuilder: (item) => itemBuilder(context, item),
              );
            },
          ),
        ),
      );
}

/// A whole detail screen around a [DetailCubit]: skeleton, offline, error,
/// pull-to-refresh, the last action's message on top.
class DetailScreen<T> extends StatelessWidget {
  final String title;
  final Future<ApiResult<T>> Function() fetch;
  final List<Widget> Function(BuildContext context, T data, DetailCubit<T> cubit) children;
  final List<Widget> Function(BuildContext context, T data)? actions;

  const DetailScreen({super.key, required this.title, required this.fetch, required this.children, this.actions});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DetailCubit<T>(fetch)..load(),
        child: BlocBuilder<DetailCubit<T>, DetailState<T>>(
          builder: (context, state) {
            final cubit = context.read<DetailCubit<T>>();
            final data = state.data;
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: data == null || actions == null ? null : actions!(context, data),
              ),
              body: Builder(builder: (context) {
                if (state.loading && data == null) return const DetailSkeleton();
                if (data == null) {
                  if (state.offline) return AppOfflineState(onRetry: cubit.load);
                  return AppErrorState(message: messageOr(state.errorMessage), onRetry: cubit.load);
                }
                return RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: AppTokens.pagePadding,
                    children: [
                      ...children(context, data, cubit),
                      const SizedBox(height: AppTokens.space8),
                    ],
                  ),
                );
              }),
            );
          },
        ),
      );
}

/// The answer to the last action on a document (an API error, or a short
/// success line), placed directly above that document's action buttons.
class ActionMessage extends StatelessWidget {
  final SubmitState action;

  const ActionMessage(this.action, {super.key});

  @override
  Widget build(BuildContext context) => FormMessage(message: action.message, success: action.isSuccess);
}

/// The heading card of a document: number (LTR), status pill, rows.
class DocumentHeaderCard extends StatelessWidget {
  final String number;
  final String title;
  final String status;
  final String? statusLabel;
  final List<Widget> rows;

  const DocumentHeaderCard({
    super.key,
    required this.number,
    required this.title,
    required this.status,
    this.statusLabel,
    this.rows = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return AppCard(
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
                    Text(title, style: theme.textTheme.titleMedium),
                    if (number.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(number, style: AppType.code(t.textSecondary), textDirection: TextDirection.ltr),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              StatusChip(status: status, label: statusLabel),
            ],
          ),
          if (rows.isNotEmpty) const SizedBox(height: AppTokens.space3),
          ...rows,
        ],
      ),
    );
  }
}

/// The frozen text the parties accept, with its SHA-256 — the document as
/// evidence, not just as data.
class FrozenTextCard extends StatelessWidget {
  final String text;
  final String hash;

  const FrozenTextCard({super.key, required this.text, this.hash = ''});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty && hash.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('compliance.document_text'.tr()),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (text.isNotEmpty)
                // Frozen documents are authored in Arabic, RTL.
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SelectableText(text, style: theme.textTheme.bodySmall?.copyWith(height: 1.7)),
                ),
              if (hash.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space3),
                Text(
                  'SHA-256: $hash',
                  textDirection: TextDirection.ltr,
                  style: AppType.code(t.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens a server PDF in the in-app viewer.
class PdfButton extends StatelessWidget {
  final String path;
  final String title;
  final String fileName;

  const PdfButton({super.key, required this.path, required this.title, required this.fileName});

  @override
  Widget build(BuildContext context) => AppButton.outline(
        label: 'files.view_pdf'.tr(),
        icon: Icons.picture_as_pdf_outlined,
        height: 48,
        onPressed: () => openDocumentPdf(context, path: path, title: title, fileName: fileName),
      );
}

/// «حزمة النزاع» — one button that freezes the evidence for an order, an
/// invoice or a relationship into a ZIP, then opens it.
class DisputePackButton extends StatefulWidget {
  /// `purchase_order`, `invoice` or `relationship`.
  final String scopeType;
  final int scopeId;

  const DisputePackButton({super.key, required this.scopeType, required this.scopeId});

  @override
  State<DisputePackButton> createState() => _DisputePackButtonState();
}

class _DisputePackButtonState extends State<DisputePackButton> {
  bool _busy = false;

  Future<void> _generate() async {
    final confirmed = await showAppConfirm(
      context,
      title: 'dispute.generate_confirm'.tr(),
      body: 'dispute.generate_body'.tr(),
      confirmLabel: 'dispute.generate'.tr(),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final result = await getIt<ComplianceRepository>().generateDisputePack(widget.scopeType, widget.scopeId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Ok(:final data)) {
      context.push(AppRoutes.disputePackFor(data.id));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageOr(result.failureMessage))));
  }

  @override
  Widget build(BuildContext context) => AppButton.outline(
        label: 'dispute.generate'.tr(),
        icon: Icons.inventory_outlined,
        height: 48,
        busy: _busy,
        onPressed: _busy ? null : _generate,
      );
}

/// The chain FA → quotation → PO → ACK, left to right in reading order.
/// A missing link is drawn hollow so the gap is visible.
class ChainStrip extends StatelessWidget {
  final ChainRef? frameworkAgreement;
  final ChainRef? quotation;
  final String purchaseOrderCode;
  final ChainRef? creditAcknowledgment;

  /// Credit orders carry an ACK; others leave the last link out.
  final bool showAck;

  const ChainStrip({
    super.key,
    this.frameworkAgreement,
    this.quotation,
    required this.purchaseOrderCode,
    this.creditAcknowledgment,
    this.showAck = false,
  });

  @override
  Widget build(BuildContext context) {
    final links = <(String, String?, VoidCallback?)>[
      (
        'compliance.chain_fa'.tr(),
        frameworkAgreement?.number,
        frameworkAgreement == null
            ? null
            : () => context.push(AppRoutes.agreementFor(AgreementKind.framework, frameworkAgreement!.id)),
      ),
      (
        'compliance.chain_quotation'.tr(),
        quotation?.number,
        quotation == null ? null : () => context.push(AppRoutes.quotationFor(quotation!.id)),
      ),
      ('compliance.chain_po'.tr(), purchaseOrderCode, null),
      if (showAck)
        (
          'compliance.chain_ack'.tr(),
          creditAcknowledgment?.number,
          creditAcknowledgment == null
              ? null
              : () => context.push(AppRoutes.agreementFor(AgreementKind.acknowledgment, creditAcknowledgment!.id)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('compliance.chain'.tr()),
        Wrap(
          spacing: AppTokens.space2,
          runSpacing: AppTokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < links.length; i++) ...[
              _ChainLink(label: links[i].$1, number: links[i].$2, onTap: links[i].$3),
              if (i < links.length - 1) const DirectionalChevron(size: 16),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChainLink extends StatelessWidget {
  final String label;
  final String? number;
  final VoidCallback? onTap;

  const _ChainLink({required this.label, this.number, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final present = number != null && number!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space3, vertical: AppTokens.space2),
        decoration: BoxDecoration(
          color: present ? t.toneTint(StatusTone.good) : null,
          border: present ? null : Border.all(color: t.divider),
          borderRadius: AppTokens.mdRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              present ? number! : 'compliance.chain_missing'.tr(),
              textDirection: present ? TextDirection.ltr : null,
              style: present ? AppType.code(t.textPrimary) : theme.textTheme.labelSmall?.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// `supply_status` of a relationship: active / suspended / accelerated.
class SupplyStatusPill extends StatelessWidget {
  final String status;
  final String? label;

  const SupplyStatusPill({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) => StatusChip(
        status: status.isEmpty ? 'active' : status,
        label: label?.isNotEmpty == true ? label : 'compliance.supply_$status'.tr(),
      );
}

/// «محجوز» on an order the late-payment sweep put on hold.
class HeldBadge extends StatelessWidget {
  const HeldBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      AppBadge('compliance.held'.tr(), tone: AppTone.warning, icon: Icons.pause_circle_outline_rounded);
}

/// The kinds of signable documents, one route each.
enum AgreementKind {
  framework('framework'),
  addendum('addendum'),
  acknowledgment('acknowledgment');

  final String path;
  const AgreementKind(this.path);

  static AgreementKind parse(String? raw) =>
      AgreementKind.values.firstWhere((k) => k.path == raw, orElse: () => AgreementKind.framework);

  String get documentType => switch (this) {
        AgreementKind.framework => 'framework_agreement',
        AgreementKind.addendum => 'addendum',
        AgreementKind.acknowledgment => 'credit_acknowledgment',
      };
}

/// Server paths for the PDFs, kept next to the button that opens them.
abstract class CompliancePdf {
  static String receipt(int id) => ApiPaths.goodsReceiptPdf(id);
  static String invoice(int id) => ApiPaths.invoicePdf(id);
  static String creditNote(int id) => ApiPaths.creditNotePdf(id);
  static String returnNote(int id) => ApiPaths.returnNotePdf(id);
}
