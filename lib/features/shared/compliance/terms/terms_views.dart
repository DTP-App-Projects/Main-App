import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/compliance/terms.dart';
import '../../../../data/repositories/compliance_repository.dart';
import 'terms_cubit.dart';

/// The terms screen, reached three ways: on start / after login when a
/// version is in force and not accepted, from the global `409
/// terms_acceptance_required` handler (which replays the blocked write when
/// this pops `true`), and from the notice banner to accept early.
class TermsGateView extends StatefulWidget {
  const TermsGateView({super.key});

  @override
  State<TermsGateView> createState() => _TermsGateViewState();
}

class _TermsGateViewState extends State<TermsGateView> {
  final Set<int> _selected = {};

  /// Versions whose full text was opened here. Accepting needs the text read
  /// first, then the explicit checkbox.
  final Set<int> _opened = {};
  bool _agreed = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    getIt<TermsCubit>().load().then((status) {
      if (!mounted || status == null) return;
      setState(() => _seed(status));
    });
  }

  /// Everything the user may accept is pre-selected; the checkbox is the
  /// act, not the selection.
  void _seed(TermsStatus status) {
    if (_seeded) return;
    _seeded = true;
    _selected
      ..clear()
      ..addAll(status.unaccepted.where((d) => d.canAccept).map((d) => d.id));
  }

  Future<void> _open(BuildContext context, TermsVersion doc) async {
    setState(() => _opened.add(doc.id));
    await context.push(AppRoutes.termsDocumentFor(doc.id));
  }

  Future<void> _accept(BuildContext context) async {
    final ok = await getIt<TermsCubit>().accept(_selected.toList());
    if (ok && context.mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TermsCubit, TermsGateState>(
      bloc: getIt<TermsCubit>(),
      builder: (context, state) {
        final theme = Theme.of(context);
        final locale = context.locale.toString();
        final docs = state.status.unaccepted;
        final onlyOthers = docs.isNotEmpty && docs.every((d) => !d.canAccept);
        final allRead = _selected.every(_opened.contains);
        // «قرأت العقد وأوافق عليه» when only organization contracts are
        // offered (the partnership contract, a joining agreement).
        final contractsOnly = docs
            .where((d) => _selected.contains(d.id))
            .every((d) => d.isOrganizationScope);

        return Scaffold(
          appBar: AppBar(title: Text('terms.gate_title'.tr())),
          body: Builder(
            builder: (context) {
              if (state.loading && !_seeded) return const DetailSkeleton();
              if (docs.isEmpty) {
                return AppEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'terms.all_accepted'.tr(),
                  body: 'terms.all_accepted_hint'.tr(),
                );
              }
              return ListView(
                padding: AppTokens.pagePadding,
                children: [
                  Text('terms.gate_intro'.tr(), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppTokens.space4),
                  for (final doc in docs)
                    _TermsDocCard(
                      doc: doc,
                      locale: locale,
                      selected: _selected.contains(doc.id),
                      read: _opened.contains(doc.id),
                      onOpen: () => _open(context, doc),
                    ),
                  const SizedBox(height: AppTokens.space2),
                  if (onlyOthers)
                    AppBanner(message: 'terms.signatory_only'.tr(), tone: AppTone.info)
                  else ...[
                    if (!allRead)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
                        child: Text('terms.read_first'.tr(), style: theme.textTheme.labelMedium),
                      ),
                    CheckboxListTile(
                      key: const Key('terms_agree'),
                      value: _agreed && allRead,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: allRead ? (v) => setState(() => _agreed = v ?? false) : null,
                      title: Text(
                        contractsOnly ? 'terms.agree_contract'.tr() : 'terms.agree'.tr(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    FormMessage(message: state.submit.message),
                    // Level 1: the server's wording of the act, verbatim.
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
                      child: Text('acceptance.click_legal'.tr(), style: theme.textTheme.labelMedium),
                    ),
                    SubmitButton(
                      busy: state.submit.isSubmitting,
                      label: 'terms.accept'.tr(),
                      onPressed: (!_agreed || !allRead || _selected.isEmpty || state.submit.isSubmitting)
                          ? null
                          : () => _accept(context),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TermsDocCard extends StatelessWidget {
  final TermsVersion doc;
  final String locale;
  final bool selected;
  final bool read;
  final VoidCallback onOpen;

  const _TermsDocCard({
    required this.doc,
    required this.locale,
    required this.selected,
    required this.read,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Any `doc_key`, known or new (`service_partnership`, …), by
              // the server's own label.
              Expanded(child: Text(doc.shortName, style: theme.textTheme.titleSmall)),
              AppBadge('terms.version'.tr(namedArgs: {'version': doc.version}), tone: AppTone.neutral),
            ],
          ),
          if (!doc.canAccept) ...[
            const SizedBox(height: AppTokens.space2),
            AppBadge(
              'terms.awaiting_signatory'.tr(),
              tone: AppTone.warning,
              icon: Icons.hourglass_top_rounded,
            ),
          ],
          const SizedBox(height: AppTokens.space1),
          Text(doc.title, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppTokens.space2),
          Text(
            doc.inForce
                ? 'terms.in_force_since'.tr(namedArgs: {'date': AppDates.riyadh(doc.effectiveAt, locale)})
                : 'terms.effective_on'.tr(namedArgs: {'date': AppDates.riyadh(doc.effectiveAt, locale)}),
            style: theme.textTheme.labelSmall,
          ),
          if (doc.isOrganizationScope) ...[
            const SizedBox(height: AppTokens.space2),
            Row(
              children: [
                Icon(Icons.apartment_outlined, size: 16, color: t.iconMuted),
                const SizedBox(width: AppTokens.space1),
                Expanded(
                  child: Text(
                    doc.canAccept ? 'terms.org_scope_signatory'.tr() : 'terms.org_scope_other'.tr(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              if (read && doc.canAccept) ...[
                Icon(Icons.check_circle_outline_rounded, size: 16, color: t.primary),
                const SizedBox(width: AppTokens.space1),
              ],
              Text('terms.read_full'.tr(), style: theme.textTheme.labelMedium?.copyWith(color: t.primary)),
              const SizedBox(width: AppTokens.space1),
              const DirectionalChevron(size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

/// One version's full text, as frozen on the server, with its legal footer.
class TermsDocumentView extends StatefulWidget {
  final int termsVersionId;

  const TermsDocumentView({super.key, required this.termsVersionId});

  @override
  State<TermsDocumentView> createState() => _TermsDocumentViewState();
}

class _TermsDocumentViewState extends State<TermsDocumentView> {
  late Future<ApiResult<TermsVersion>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<ComplianceRepository>().termsVersion(widget.termsVersionId);
  }

  void _retry() => setState(() {
    _future = getIt<ComplianceRepository>().termsVersion(widget.termsVersionId);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    return Scaffold(
      appBar: AppBar(title: Text('terms.document_title'.tr())),
      body: FutureBuilder<ApiResult<TermsVersion>>(
        future: _future,
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null) return const DetailSkeleton();
          if (result is! Ok<TermsVersion>) {
            if (result.isOffline) return AppOfflineState(onRetry: _retry);
            return AppErrorState(message: result.failureMessage ?? 'errors.generic'.tr(), onRetry: _retry);
          }
          final doc = result.data;
          return ListView(
            padding: AppTokens.pagePadding,
            children: [
              Text(doc.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppTokens.space2),
              DetailRow(label: 'terms.version_label'.tr(), value: Text(doc.version)),
              DetailRow(label: 'terms.effective_label'.tr(), value: Text(AppDates.riyadh(doc.effectiveAt, locale))),
              if (doc.changeSummary.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                AppBanner(title: 'terms.change_summary'.tr(), message: doc.changeSummary),
              ],
              // The text is Arabic and authored RTL whatever the UI locale.
              Directionality(
                textDirection: TextDirection.rtl,
                child: Html(data: doc.bodyHtml),
              ),
              if (doc.legalFooter.isNotEmpty) ...[
                const Divider(height: AppTokens.space6),
                Text(doc.legalFooter, style: theme.textTheme.labelSmall),
              ],
              if (doc.bodyHash.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                Text(
                  'SHA-256: ${doc.bodyHash}',
                  textDirection: TextDirection.ltr,
                  style: AppType.code(context.tokens.textSecondary),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The 7-day notice: a published version that is not in force yet.
/// Dismissible for this session; the gate takes over once it is in force.
class TermsNoticeBanner extends StatelessWidget {
  const TermsNoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TermsCubit, TermsGateState>(
      bloc: getIt<TermsCubit>(),
      builder: (context, state) {
        if (!state.showBanner) return const SizedBox.shrink();
        final first = state.status.upcoming.first;
        final locale = context.locale.toString();
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AppTokens.gutter, AppTokens.space2, AppTokens.gutter, 0),
            child: AppBanner(
              key: const Key('terms_notice_banner'),
              tone: AppTone.info,
              icon: Icons.gavel_rounded,
              margin: EdgeInsetsDirectional.zero,
              // An organization contract (the partnership contract) is the
              // signatory's to accept; a user-scope text is everyone's own.
              message: (first.isOrganizationScope ? 'terms.notice_banner_contract' : 'terms.notice_banner')
                  .tr(namedArgs: {'name': first.shortName, 'date': AppDates.riyadh(first.effectiveAt, locale)}),
              action: Row(
                children: [
                  AppButton.text(
                    label: 'terms.review'.tr(),
                    height: 36,
                    onPressed: () => context.push(AppRoutes.termsGate),
                  ),
                  AppButton.text(
                    label: 'terms.read'.tr(),
                    height: 36,
                    onPressed: () => context.push(AppRoutes.termsDocumentFor(first.id)),
                  ),
                  AppButton.text(label: 'common.close'.tr(), height: 36, onPressed: getIt<TermsCubit>().dismissBanner),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Account → legal: every published version and what was accepted, when and
/// how (evidence times in Riyadh time).
class TermsHistoryView extends StatelessWidget {
  const TermsHistoryView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _AcceptancesCubit(getIt<ComplianceRepository>())..load(),
    child: const _TermsHistoryBody(),
  );
}

class _AcceptancesCubit extends PagedCubit<TermsAcceptance> {
  final ComplianceRepository _repo;

  _AcceptancesCubit(this._repo);

  @override
  Future<ApiResult<Paged<TermsAcceptance>>> fetchPage(int page) => _repo.termsAcceptances(page: page);
}

class _TermsHistoryBody extends StatelessWidget {
  const _TermsHistoryBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<_AcceptancesCubit>();
    final locale = context.locale.toString();
    return Scaffold(
      appBar: AppBar(title: Text('terms.history_title'.tr())),
      body: Column(
        children: [
          BlocBuilder<TermsCubit, TermsGateState>(
            bloc: getIt<TermsCubit>(),
            builder: (context, terms) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(AppTokens.gutter, AppTokens.space3, AppTokens.gutter, 0),
              child: AppMenuGroup(
                children: [
                  for (final doc in terms.status.documents)
                    AppMenuRow(
                      icon: doc.isOrganizationScope ? Icons.apartment_outlined : Icons.person_outline_rounded,
                      title: doc.shortName,
                      subtitle: 'terms.version'.tr(namedArgs: {'version': doc.version}),
                      value: doc.accepted ? 'terms.accepted'.tr() : 'terms.not_accepted'.tr(),
                      onTap: () => context.push(AppRoutes.termsDocumentFor(doc.id)),
                    ),
                ],
              ),
            ),
          ),
          AppSectionLabel('terms.acceptances'.tr()),
          Expanded(
            child: PagedListView<TermsAcceptance>(
              state: cubit.state,
              onRefresh: cubit.refresh,
              onLoadMore: cubit.loadMore,
              emptyIcon: Icons.history_rounded,
              emptyTitle: 'terms.no_acceptances'.tr(),
              emptyBody: 'terms.no_acceptances_hint'.tr(),
              itemBuilder: (a) {
                // Rows carry the doc key only; the title comes from the
                // published versions already loaded for the list above.
                final version = getIt<TermsCubit>().state.status.documents
                    .where((d) => d.id == a.termsVersionId)
                    .firstOrNull;
                return DocumentTile(
                  code: a.version.isEmpty ? '' : 'v${a.version}',
                  title: version?.shortName ?? a.docKey,
                  subtitle: [
                    _methodLabel(a.method),
                    AppDates.riyadh(a.acceptedAt, locale),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  status: 'accepted',
                  icon: Icons.verified_outlined,
                  onTap: () {
                    if (a.termsVersionId != 0) context.push(AppRoutes.termsDocumentFor(a.termsVersionId));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The legal names of the acceptance levels — never «توقيع إلكتروني
  /// معتمد» for a click or a code.
  static String _methodLabel(String method) => switch (method) {
    'click' => 'acceptance.click_legal'.tr(),
    'otp' => 'acceptance.otp_legal'.tr(),
    '' => '',
    _ => method,
  };
}
