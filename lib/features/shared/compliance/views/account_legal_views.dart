import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/compliance/legal.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';
import '../files/document_file_view.dart';

ComplianceRepository get _repo => getIt<ComplianceRepository>();

// ----------------------------------------------------------------- complaints

/// The list keeps the server's categories and response window from page one,
/// so "new complaint" never has to fetch them again.
class _ComplaintsCubit extends PagedCubit<ComplaintTicket> {
  List<ComplaintCategory> categories = const [];
  int responseDays = 15;

  @override
  Future<ApiResult<Paged<ComplaintTicket>>> fetchPage(int page) async {
    final result = await _repo.complaintTickets(page: page);
    if (result case Ok(:final data)) {
      categories = data.categories;
      responseDays = data.responseDays;
      return Ok(Paged(
        items: data.tickets,
        currentPage: data.currentPage,
        lastPage: data.lastPage,
        perPage: 15,
        total: data.total,
      ));
    }
    return result.castFailure<Paged<ComplaintTicket>>();
  }
}

class ComplaintsView extends StatelessWidget {
  const ComplaintsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => _ComplaintsCubit()..load(),
        child: BlocBuilder<_ComplaintsCubit, PagedState<ComplaintTicket>>(
          builder: (context, state) {
            final cubit = context.read<_ComplaintsCubit>();
            final locale = context.locale.toString();
            return Scaffold(
              appBar: AppBar(title: Text('complaint.title'.tr())),
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.add_comment_outlined),
                label: Text('complaint.new'.tr()),
                onPressed: () async {
                  final created = await context.push<bool>(AppRoutes.complaintNew, extra: cubit.categories);
                  if (created == true) await cubit.refresh();
                },
              ),
              body: PagedListView<ComplaintTicket>(
                state: state,
                onRefresh: cubit.refresh,
                onLoadMore: cubit.loadMore,
                emptyIcon: Icons.support_agent_outlined,
                emptyTitle: 'complaint.empty'.tr(),
                emptyBody: 'complaint.empty_hint'.tr(namedArgs: {'days': '${cubit.responseDays}'}),
                itemBuilder: (t) => DocumentTile(
                  code: t.ticketNo,
                  title: t.subject,
                  subtitle: [
                    t.categoryLabel,
                    if (!t.isClosed && t.dueAt != null)
                      'complaint.due'.tr(namedArgs: {'date': AppDates.date(AppDates.toRiyadh(t.dueAt), locale)}),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  status: t.status,
                  icon: Icons.support_agent_outlined,
                  badge: t.unread ? AppBadge('complaint.new_reply'.tr(), tone: AppTone.info) : null,
                  onTap: () async {
                    await context.push(AppRoutes.complaintFor(t.id));
                    await cubit.refresh();
                  },
                ),
              ),
            );
          },
        ),
      );
}

class ComplaintFormView extends StatefulWidget {
  final List<ComplaintCategory> categories;

  const ComplaintFormView({super.key, this.categories = const []});

  @override
  State<ComplaintFormView> createState() => _ComplaintFormViewState();
}

class _ComplaintFormViewState extends State<ComplaintFormView> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String? _category;
  String? _file;
  SubmitState _submit = const SubmitState();
  late List<ComplaintCategory> _categories = widget.categories;

  @override
  void initState() {
    super.initState();
    // Deep-linked straight here: read the categories from the list endpoint.
    if (_categories.isEmpty) {
      _repo.complaintTickets().then((r) {
        if (mounted && r is Ok<ComplaintList>) setState(() => _categories = r.data.categories);
      });
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = picked?.files.single.path;
    if (path != null) setState(() => _file = path);
  }

  Future<void> _save() async {
    if (_category == null || _subject.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _submit = SubmitState(status: FormStatus.failure, message: 'complaint.form_incomplete'.tr()));
      return;
    }
    setState(() => _submit = const SubmitState(status: FormStatus.submitting));
    final result = await _repo.openComplaint(
      category: _category!,
      subject: _subject.text.trim(),
      body: _body.text.trim(),
      attachmentPath: _file,
    );
    if (!mounted) return;
    if (result is Ok<ComplaintTicket>) {
      context.pop(true);
      return;
    }
    setState(() => _submit = result.failureState);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('complaint.new'.tr())),
        body: ListView(
          padding: AppTokens.pagePadding,
          children: [
            CodePicker(
              label: 'complaint.category'.tr(),
              value: _category,
              codes: [for (final c in _categories) c.key],
              labelOf: (k) => _categories.firstWhere((c) => c.key == k).label,
              error: _submit.fieldError('category'),
              onChanged: (v) => setState(() => _category = v),
            ),
            AppField(
              controller: _subject,
              label: 'complaint.subject'.tr(),
              required: true,
              maxLength: 150,
              serverError: _submit.fieldError('subject'),
            ),
            AppField(
              controller: _body,
              label: 'complaint.body'.tr(),
              required: true,
              maxLines: 6,
              serverError: _submit.fieldError('body'),
            ),
            AppButton.outline(
              label: _file == null ? 'complaint.attach'.tr() : _file!.split(RegExp(r'[\\/]')).last,
              icon: Icons.attach_file_rounded,
              height: 48,
              onPressed: _pick,
            ),
            const SizedBox(height: AppTokens.space4),
            FormMessage(message: _submit.message),
            SubmitButton(busy: _submit.isSubmitting, label: 'complaint.send'.tr(), onPressed: _save),
          ],
        ),
      );
}

class ComplaintDetailView extends StatefulWidget {
  final int ticketId;

  const ComplaintDetailView({super.key, required this.ticketId});

  @override
  State<ComplaintDetailView> createState() => _ComplaintDetailViewState();
}

class _ComplaintDetailViewState extends State<ComplaintDetailView> {
  final _reply = TextEditingController();
  String? _file;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(DetailCubit<ComplaintTicket> cubit) async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final ok = await cubit.run(() => _repo.replyToComplaint(widget.ticketId, body: text, attachmentPath: _file));
    if (ok && mounted) {
      _reply.clear();
      setState(() => _file = null);
    }
  }

  Future<void> _close(BuildContext context, DetailCubit<ComplaintTicket> cubit) async {
    final ok = await showAppConfirm(context, title: 'complaint.close_confirm'.tr(), confirmLabel: 'complaint.close'.tr());
    if (ok) await cubit.run(() => _repo.closeComplaint(widget.ticketId));
  }

  Widget _attachments(BuildContext context, List<TicketAttachment> files) => Wrap(
        spacing: AppTokens.space2,
        children: [
          for (final f in files)
            ActionChip(
              avatar: Icon(f.isImage ? Icons.image_outlined : Icons.attach_file_rounded, size: 18),
              label: Text(f.name),
              // The attachment route is authenticated: fetch it through the
              // client, never as a bare URL.
              onPressed: () {
                final path = Uri.parse(f.url);
                final apiPath = '${path.path.replaceFirst('/api', '')}?${path.query}';
                if (f.isPdf) {
                  openDocumentPdf(context, path: apiPath, title: f.name, fileName: f.name);
                } else {
                  shareOrSaveFile(context, path: apiPath, fileName: f.name);
                }
              },
            ),
        ],
      );

  @override
  Widget build(BuildContext context) => DetailScreen<ComplaintTicket>(
        title: 'complaint.detail_title'.tr(),
        fetch: () => _repo.complaintTicket(widget.ticketId),
        children: (context, t, cubit) {
          final locale = context.locale.toString();
          final theme = Theme.of(context);
          final tokens = context.tokens;
          final busy = cubit.state.action.isSubmitting;
          return [
            DocumentHeaderCard(
              number: t.ticketNo,
              title: t.subject,
              status: t.status,
              statusLabel: t.statusLabel,
              rows: [
                DetailRow(label: 'complaint.category'.tr(), value: Text(t.categoryLabel)),
                DetailRow(label: 'complaint.opened'.tr(), value: Text(AppDates.riyadh(t.createdAt, locale))),
                // The 15-day response deadline, with the server's SLA label.
                DetailRow(
                  label: 'complaint.deadline'.tr(),
                  value: Text('${AppDates.date(AppDates.toRiyadh(t.dueAt), locale)} · ${t.slaLabel}'),
                ),
                if (t.closedAt != null) DetailRow(label: 'complaint.closed_at'.tr(), value: Text(AppDates.riyadh(t.closedAt, locale))),
              ],
            ),
            AppSectionLabel('complaint.thread'.tr()),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.body, style: theme.textTheme.bodyMedium),
                  if (t.attachments.isNotEmpty) _attachments(context, t.attachments),
                ],
              ),
            ),
            for (final m in t.messages)
              Align(
                alignment: m.isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: Container(
                  margin: const EdgeInsets.only(top: AppTokens.space2),
                  padding: const EdgeInsets.all(AppTokens.space3),
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                  decoration: BoxDecoration(
                    color: m.isMine ? tokens.toneTint(StatusTone.inFlight) : tokens.neutralTint,
                    borderRadius: AppTokens.mdRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.isAnswer) Text('complaint.platform_answer'.tr(), style: theme.textTheme.labelMedium),
                      Text(m.body, style: theme.textTheme.bodyMedium),
                      if (m.attachments.isNotEmpty) _attachments(context, m.attachments),
                      Text(AppDates.riyadh(m.createdAt, locale), style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            if (!t.isClosed) ...[
              const SizedBox(height: AppTokens.space4),
              AppField(controller: _reply, label: 'complaint.reply'.tr(), maxLines: 4),
              ActionMessage(cubit.state.action),
              Row(
                children: [
                  IconButton(
                    tooltip: 'complaint.attach'.tr(),
                    icon: Icon(_file == null ? Icons.attach_file_rounded : Icons.check_circle_outline_rounded),
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
                      );
                      final path = picked?.files.single.path;
                      if (path != null) setState(() => _file = path);
                    },
                  ),
                  const Spacer(),
                  AppButton.primary(
                    label: 'complaint.send_reply'.tr(),
                    expand: false,
                    height: 44,
                    busy: busy,
                    onPressed: busy ? null : () => _send(cubit),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space3),
              AppButton.outline(label: 'complaint.close'.tr(), height: 44, onPressed: busy ? null : () => _close(context, cubit)),
            ],
            // Closing removes the buttons; its answer stays where they were.
            if (t.isClosed) ActionMessage(cubit.state.action),
          ];
        },
      );
}

// ---------------------------------------------------------------- signatories

/// Who may bind the organization, and the registration data that is locked
/// once it is active («يُعدَّل عبر إدارة المنصة»).
class SignatoriesView extends StatelessWidget {
  const SignatoriesView({super.key});

  Future<void> _add(BuildContext context, Signatory member, DetailCubit<SignatoriesInfo> cubit) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      dialogTitle: 'signatory.pick_document'.tr(),
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await cubit.run(
      () => _repo.addSignatory(membershipId: member.membershipId, documentPath: path),
      successMessage: 'signatory.added'.tr(),
    );
  }

  Future<void> _remove(BuildContext context, Signatory member, DetailCubit<SignatoriesInfo> cubit) async {
    final ok = await showAppConfirm(
      context,
      title: 'signatory.remove_confirm'.tr(namedArgs: {'name': member.name}),
      confirmLabel: 'signatory.remove'.tr(),
      destructive: true,
    );
    // The last signatory cannot be removed: the server refuses with a 422
    // whose message is shown as-is.
    if (ok) await cubit.run(() => _repo.removeSignatory(member.membershipId));
  }

  @override
  Widget build(BuildContext context) => DetailScreen<SignatoriesInfo>(
        title: 'signatory.title'.tr(),
        fetch: _repo.signatories,
        children: (context, info, cubit) {
          final theme = Theme.of(context);
          final busy = cubit.state.action.isSubmitting;
          return [
            LockedRegistrationCard(data: info.organization),
            AppSectionLabel('signatory.members'.tr()),
            Text('signatory.explainer'.tr(), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTokens.space2),
            // The add/revoke buttons are on the member rows below.
            ActionMessage(cubit.state.action),
            AppMenuGroup(children: [
              for (final m in info.members)
                AppMenuRow(
                  icon: m.isSignatory ? Icons.verified_user_outlined : Icons.person_outline_rounded,
                  title: m.name,
                  subtitle: [
                    if (m.jobTitle.isNotEmpty) m.jobTitle,
                    m.isSignatory ? 'signatory.is_signatory'.tr() : 'signatory.not_signatory'.tr(),
                    if (m.isSignatory && !m.isOwner && !m.hasAuthorizationDocument) 'signatory.no_document'.tr(),
                  ].join(' · '),
                  showChevron: false,
                  trailing: !info.canManage
                      ? null
                      : m.isSignatory
                          ? (m.isOwner
                              ? null
                              : IconButton(
                                  tooltip: 'signatory.remove'.tr(),
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                  onPressed: busy ? null : () => _remove(context, m, cubit),
                                ))
                          : IconButton(
                              tooltip: 'signatory.add'.tr(),
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              onPressed: busy ? null : () => _add(context, m, cubit),
                            ),
                ),
            ]),
            if (info.canManage) ...[
              const SizedBox(height: AppTokens.space2),
              Text('signatory.add_hint'.tr(), style: theme.textTheme.labelSmall),
            ],
          ];
        },
      );
}

/// The registration fields frozen once the organization is active: shown,
/// never editable by members.
class LockedRegistrationCard extends StatelessWidget {
  final RegistrationData data;

  const LockedRegistrationCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    Widget locked(String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(value.isEmpty ? '—' : value, textDirection: TextDirection.ltr)),
            if (data.registrationLocked) ...[
              const SizedBox(width: AppTokens.space1),
              Icon(Icons.lock_outline_rounded, size: 14, color: t.iconMuted),
            ],
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel('registration.title'.tr()),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(label: 'registration.legal_name'.tr(), value: locked(data.legalNameAr)),
              DetailRow(label: 'registration.cr'.tr(), value: locked(data.commercialRegNo)),
              DetailRow(label: 'registration.vat'.tr(), value: locked(data.vatNo)),
              if (data.activityTypeLabel.isNotEmpty)
                DetailRow(label: 'register.activity_type'.tr(), value: Text(data.activityTypeLabel)),
              DetailRow(
                label: 'registration.cr_check'.tr(),
                value: StatusChip(
                  status: data.crVerified ? 'verified' : 'pending',
                  label: data.crVerified ? 'registration.cr_verified'.tr() : 'registration.cr_pending'.tr(),
                ),
              ),
              if (data.registrationLocked) ...[
                const SizedBox(height: AppTokens.space2),
                Text('registration.locked_hint'.tr(), key: const Key('registration_locked_hint'), style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
