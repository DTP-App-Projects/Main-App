import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_dates.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/roots/app_router.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/compliance/agreements.dart';
import '../../../../data/models/compliance/relationship_request.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../compliance_cubits.dart';
import '../compliance_widgets.dart';
import '../otp_acceptance_sheet.dart';

ComplianceRepository get _repo => getIt<ComplianceRepository>();

// ------------------------------------------------------ relationship requests

/// «الواردة» (others asked us) and «المرسلة» (we asked), the incoming tab
/// carrying how many still wait for our decision.
class RelationshipRequestsView extends StatefulWidget {
  const RelationshipRequestsView({super.key});

  @override
  State<RelationshipRequestsView> createState() => _RelationshipRequestsViewState();
}

class _RelationshipRequestsViewState extends State<RelationshipRequestsView> {
  String _direction = 'incoming';
  int _awaiting = 0;

  @override
  void initState() {
    super.initState();
    _countAwaiting();
  }

  Future<void> _countAwaiting() async {
    final result = await _repo.relationshipRequests(direction: 'incoming', requestStatus: 'submitted');
    if (!mounted) return;
    setState(() => _awaiting = result.dataOrNull?.total ?? _awaiting);
  }

  Future<void> _open(BuildContext context, RelationshipRequest r) async {
    await context.push(AppRoutes.relationshipRequestFor(r.id));
    // A decision there changes the count here.
    await _countAwaiting();
  }

  @override
  Widget build(BuildContext context) => PagedScreen<RelationshipRequest>(
        key: ValueKey(_direction),
        title: 'rr.title'.tr(),
        fetch: (page) => _repo.relationshipRequests(page: page, direction: _direction),
        header: AppFilterBar(
          options: [
            AppFilterOption(
              label: _awaiting > 0 ? '${'rr.incoming'.tr()}  ($_awaiting)' : 'rr.incoming'.tr(),
              selected: _direction == 'incoming',
              onTap: () => setState(() => _direction = 'incoming'),
            ),
            AppFilterOption(
              label: 'rr.outgoing'.tr(),
              selected: _direction == 'outgoing',
              onTap: () => setState(() => _direction = 'outgoing'),
            ),
          ],
        ),
        emptyIcon: Icons.handshake_outlined,
        emptyTitle: 'rr.empty'.tr(),
        emptyBody: 'rr.empty_hint'.tr(),
        itemBuilder: (context, r) => DocumentTile(
          code: r.requestNo,
          title: r.counterparty?.name ?? '',
          subtitle: [
            r.requestedModelLabel,
            if (r.isCredit && r.requestedCreditTermDays != null)
              'rr.term_days'.tr(namedArgs: {'days': '${r.requestedCreditTermDays}'}),
          ].where((s) => s.isNotEmpty).join(' · '),
          status: r.status,
          amount: r.requestedCreditLimit,
          currency: 'SAR',
          icon: Icons.handshake_outlined,
          badge: r.canDecide ? AppBadge('rr.awaiting_you'.tr(), tone: AppTone.info) : null,
          onTap: () => _open(context, r),
        ),
      );
}

class RelationshipRequestDetailView extends StatelessWidget {
  final int requestId;

  const RelationshipRequestDetailView({super.key, required this.requestId});

  Future<void> _accept(BuildContext context, RelationshipRequest r, DetailCubit<RelationshipRequest> cubit) async {
    // Only the supplier grants, and only on a credit request — less than
    // asked, never more. Unchanged values are left out of the request.
    final grants = r.isCredit && r.myRole == 'supplier';
    final grant = grants ? await _askGrant(context, r) : (limit: null, days: null);
    if (grant == null || !context.mounted) return;
    final ok = await showOtpAcceptance(
      context,
      documentType: r.otpDocumentType,
      documentId: r.id,
      title: 'rr.accept_title'.tr(),
      subtitle: r.requestNo,
      submit: (code) => _repo.decideRelationshipRequest(
        r.id,
        status: 'accepted',
        otpCode: code,
        creditLimit: grant.limit,
        creditTermDays: grant.days,
      ),
    );
    if (ok) {
      await cubit.succeeded('rr.accepted'.tr());
    } else {
      // Blocked or abandoned: re-read — someone may have decided already,
      // or this user turned out not to be able to.
      await cubit.load();
    }
  }

  /// The granted limit and term, prefilled with the request and checked
  /// against it: equal or lower only.
  Future<({double? limit, int? days})?> _askGrant(BuildContext context, RelationshipRequest r) async {
    final limit = TextEditingController(text: _plain(r.requestedCreditLimit));
    final days = TextEditingController(text: r.requestedCreditTermDays?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showAppSheet<bool>(
      context: context,
      title: 'rr.grant_title'.tr(),
      subtitle: 'rr.grant_hint'.tr(),
      builder: (sheet) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              controller: limit,
              label: 'rr.granted_limit_field'.tr(),
              suffixText: 'SAR',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              validator: (v) => _notAbove(v, r.requestedCreditLimit),
            ),
            AppField(
              controller: days,
              label: 'rr.granted_term_field'.tr(),
              suffixText: 'rr.days'.tr(),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              validator: (v) => _notAbove(v, r.requestedCreditTermDays?.toDouble()),
            ),
            const SizedBox(height: AppTokens.space3),
            AppButton.primary(
              label: 'common.continue'.tr(),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.of(sheet).pop(true);
              },
            ),
          ],
        ),
      ),
    );
    if (result != true) return null;
    final grantedLimit = double.tryParse(limit.text.trim());
    final grantedDays = int.tryParse(days.text.trim());
    return (
      limit: grantedLimit == r.requestedCreditLimit ? null : grantedLimit,
      days: grantedDays == r.requestedCreditTermDays ? null : grantedDays,
    );
  }

  /// Empty is "as requested"; anything above the request is refused.
  static String? _notAbove(String? value, double? requested) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    if (n == null || n <= 0) return 'rr.limit_positive'.tr();
    if (requested != null && n > requested) return 'rr.grant_over'.tr();
    return null;
  }

  Future<void> _reject(BuildContext context, RelationshipRequest r, DetailCubit<RelationshipRequest> cubit) async {
    // «هل تريد رفض الطلب؟» with the reason in the same step (3–1000).
    final note = await showAppReasonDialog(
      context,
      title: 'rr.reject_confirm'.tr(),
      hint: 'rr.reject_title'.tr(),
      confirmLabel: 'rr.reject'.tr(),
      required: true,
      destructive: true,
      minLength: 3,
      maxLength: 1000,
    );
    if (note == null) return;
    await cubit.run(
      () => _repo.decideRelationshipRequest(r.id, status: 'rejected', note: note.trim()),
      successMessage: 'rr.rejected'.tr(),
    );
  }

  Future<void> _submit(BuildContext context, RelationshipRequest r, DetailCubit<RelationshipRequest> cubit) async {
    if (!r.submitRequiresOtp) {
      await cubit.run(() => _repo.decideRelationshipRequest(r.id, status: 'submitted'));
      return;
    }
    final ok = await showOtpAcceptance(
      context,
      documentType: r.otpDocumentType,
      documentId: r.id,
      title: 'rr.submit'.tr(),
      submit: (code) => _repo.decideRelationshipRequest(r.id, status: 'submitted', otpCode: code),
    );
    if (ok) await cubit.succeeded(null);
  }

  Future<void> _changeTerms(BuildContext context, RelationshipRequest r, DetailCubit<RelationshipRequest> cubit) async {
    final grant = await _askGrant(context, r);
    if (grant == null) return;
    await cubit.run(
      () => _repo.updateCreditTerms(r.id, creditLimit: grant.limit, creditTermDays: grant.days),
      successMessage: 'rr.terms_updated'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) => DetailScreen<RelationshipRequest>(
        title: 'rr.detail_title'.tr(),
        fetch: () => _repo.relationshipRequest(requestId),
        children: (context, r, cubit) {
          final locale = context.locale.toString();
          final busy = cubit.state.action.isSubmitting;
          return [
            DocumentHeaderCard(
              number: r.requestNo,
              title: r.counterparty?.name ?? '',
              status: r.status,
              statusLabel: r.statusLabel,
              rows: [
                DetailRow(label: 'rr.model'.tr(), value: Text(r.requestedModelLabel)),
                if (r.isCredit) ...[
                  DetailRow(
                    label: 'rr.requested_limit'.tr(),
                    value: r.requestedCreditLimit == null
                        ? const Text('—')
                        : MoneyText(r.requestedCreditLimit!),
                  ),
                  DetailRow(
                    label: 'rr.requested_term'.tr(),
                    value: Text(r.requestedCreditTermDays == null
                        ? '—'
                        : 'rr.term_days'.tr(namedArgs: {'days': '${r.requestedCreditTermDays}'})),
                  ),
                  if (r.creditLimit > 0 || r.creditTermDays > 0) ...[
                    DetailRow(label: 'rr.granted_limit'.tr(), value: MoneyText(r.creditLimit)),
                    DetailRow(
                      label: 'rr.granted_term'.tr(),
                      value: Text('rr.term_days'.tr(namedArgs: {'days': '${r.creditTermDays}'})),
                    ),
                  ],
                  DetailRow(label: 'rr.debt_documentation'.tr(), value: Text(r.debtDocumentationLabel)),
                ],
                DetailRow(label: 'rr.supply_status'.tr(), value: SupplyStatusPill(status: r.supplyStatus)),
                DetailRow(label: 'rr.submitted_at'.tr(), value: Text(AppDates.riyadh(r.submittedAt, locale))),
                if (r.decidedAt != null)
                  DetailRow(label: 'rr.decided_at'.tr(), value: Text(AppDates.riyadh(r.decidedAt, locale))),
                if (r.decisionNote.isNotEmpty)
                  DetailRow(
                    label: r.status == 'rejected' ? 'rr.reject_reason'.tr() : 'rr.note'.tr(),
                    value: Text(r.decisionNote),
                  ),
              ],
            ),
            // The requester's side is read-only: say where it stands.
            if (r.isRequester && r.status == 'submitted')
              AppBanner(message: 'rr.waiting_other'.tr(), tone: AppTone.info, icon: Icons.hourglass_top_rounded),
            if (r.frameworkAgreement != null) ...[
              AppSectionLabel('compliance.chain_fa'.tr()),
              AppMenuGroup(children: [
                AppMenuRow(
                  icon: Icons.description_outlined,
                  title: r.frameworkAgreement!.number.isEmpty ? 'compliance.chain_fa'.tr() : r.frameworkAgreement!.number,
                  value: r.frameworkAgreement!.statusLabel,
                  onTap: () => context.push(AppRoutes.agreementFor(AgreementKind.framework, r.frameworkAgreement!.id)),
                ),
              ]),
            ],
            FrozenTextCard(text: r.bodyText, hash: r.documentHash),
            const SizedBox(height: AppTokens.space4),
            ActionMessage(cubit.state.action),
            if (r.canDecide) ...[
              // «تأكيد برمز تحقق — قبول ملزم…», above the binding act.
              AppBanner(message: 'rr.otp_notice'.tr(), tone: AppTone.info, icon: Icons.verified_user_outlined),
              AppButton.primary(
                label: 'rr.accept'.tr(),
                icon: Icons.verified_outlined,
                onPressed: busy ? null : () => _accept(context, r, cubit),
              ),
              const SizedBox(height: AppTokens.space3),
              AppButton.outlineDanger(
                label: 'rr.reject'.tr(),
                onPressed: busy ? null : () => _reject(context, r, cubit),
              ),
            ],
            if (r.canSubmit) ...[
              const SizedBox(height: AppTokens.space4),
              AppButton.primary(label: 'rr.submit'.tr(), onPressed: busy ? null : () => _submit(context, r, cubit)),
            ],
            if (r.myRole == 'supplier' && r.status == 'accepted' && r.isCredit) ...[
              const SizedBox(height: AppTokens.space3),
              AppButton.outline(
                label: 'rr.change_terms'.tr(),
                icon: Icons.tune_rounded,
                onPressed: busy ? null : () => _changeTerms(context, r, cubit),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space2),
                child: Text('rr.change_terms_hint'.tr(), style: Theme.of(context).textTheme.labelSmall),
              ),
            ],
            if (r.relationshipId > 0) ...[
              const SizedBox(height: AppTokens.space3),
              DisputePackButton(scopeType: 'relationship', scopeId: r.relationshipId),
            ],
          ];
        },
      );

  static String _plain(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : '$v');
}

// --------------------------------------------- FA, addenda, credit ACKs

String _kindTitle(AgreementKind kind) => switch (kind) {
      AgreementKind.framework => 'agreement.fa_title'.tr(),
      AgreementKind.addendum => 'agreement.addenda_title'.tr(),
      AgreementKind.acknowledgment => 'agreement.ack_title'.tr(),
    };

class AgreementsView extends StatelessWidget {
  final AgreementKind kind;

  const AgreementsView({super.key, required this.kind});

  @override
  Widget build(BuildContext context) => PagedScreen<SignableDocument>(
        title: _kindTitle(kind),
        fetch: (page) => switch (kind) {
          AgreementKind.framework => _repo.frameworkAgreements(page: page),
          AgreementKind.addendum => _repo.addenda(page: page),
          AgreementKind.acknowledgment => _repo.creditAcknowledgments(page: page),
        },
        emptyIcon: Icons.description_outlined,
        emptyTitle: 'agreement.empty'.tr(),
        emptyBody: 'agreement.empty_hint'.tr(),
        itemBuilder: (context, d) => DocumentTile(
          code: d.number,
          title: d.counterparty?.name ?? '',
          status: d.status,
          amount: d.amount,
          currency: d.amount == null ? null : 'SAR',
          icon: Icons.description_outlined,
          badge: d.canSign ? AppBadge('agreement.awaiting_signature'.tr(), tone: AppTone.info) : null,
          onTap: () => context.push(AppRoutes.agreementFor(kind, d.id)),
        ),
      );
}

class AgreementDetailView extends StatelessWidget {
  final AgreementKind kind;
  final int documentId;

  const AgreementDetailView({super.key, required this.kind, required this.documentId});

  Future<void> _sign(BuildContext context, SignableDocument d, DetailCubit<SignableDocument> cubit) async {
    final ok = await showOtpAcceptance(
      context,
      documentType: d.otpDocumentType.isEmpty ? kind.documentType : d.otpDocumentType,
      documentId: d.id,
      title: kind == AgreementKind.acknowledgment ? 'agreement.accept'.tr() : 'agreement.sign'.tr(),
      subtitle: d.number,
      submit: (code) => switch (kind) {
        AgreementKind.framework => _repo.signFrameworkAgreement(d.id, code),
        AgreementKind.addendum => _repo.signAddendum(d.id, code),
        AgreementKind.acknowledgment => _repo.acceptCreditAcknowledgment(d.id, code),
      },
    );
    if (ok) await cubit.succeeded('agreement.signed_ok'.tr());
  }

  @override
  Widget build(BuildContext context) => DetailScreen<SignableDocument>(
        title: _kindTitle(kind),
        fetch: () => switch (kind) {
          AgreementKind.framework => _repo.frameworkAgreement(documentId),
          AgreementKind.addendum => _repo.addendum(documentId),
          AgreementKind.acknowledgment => _repo.creditAcknowledgment(documentId),
        },
        children: (context, d, cubit) {
          final locale = context.locale.toString();
          final theme = Theme.of(context);
          final t = context.tokens;
          return [
            DocumentHeaderCard(
              number: d.number,
              title: d.counterparty?.name ?? _kindTitle(kind),
              status: d.status,
              statusLabel: d.statusLabel,
              rows: [
                if (d.supplier != null) DetailRow(label: 'agreement.supplier'.tr(), value: Text(d.supplier!.name)),
                if (d.trader != null) DetailRow(label: 'agreement.trader'.tr(), value: Text(d.trader!.name)),
                if (d.amount != null) DetailRow(label: 'agreement.amount'.tr(), value: MoneyText(d.amount!)),
                if (d.signedAt != null)
                  DetailRow(label: 'agreement.signed_at'.tr(), value: Text(AppDates.riyadh(d.signedAt, locale))),
              ],
            ),
            // Both parties' signatories sign: who has, who is still pending.
            if (d.signatures.isNotEmpty) ...[
              AppSectionLabel('agreement.signatures'.tr()),
              AppCard(
                child: Column(
                  children: [
                    for (final s in d.signatures)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
                        child: Row(
                          children: [
                            Icon(
                              s.signed ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                              size: 20,
                              color: s.signed ? t.toneColor(StatusTone.good) : t.iconMuted,
                            ),
                            const SizedBox(width: AppTokens.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${'agreement.side_${s.side}'.tr()}${s.signerName.isEmpty ? '' : ' — ${s.signerName}'}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    s.signed
                                        ? '${'acceptance.otp_legal'.tr()} · ${AppDates.riyadh(s.signedAt, locale)}'
                                        : 'agreement.pending_signature'.tr(),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            FrozenTextCard(text: d.bodyText, hash: d.documentHash),
            const SizedBox(height: AppTokens.space4),
            ActionMessage(cubit.state.action),
            if (d.canSign) ...[
              AppButton.primary(
                label: kind == AgreementKind.acknowledgment ? 'agreement.accept'.tr() : 'agreement.sign'.tr(),
                icon: Icons.verified_outlined,
                onPressed: cubit.state.action.isSubmitting ? null : () => _sign(context, d, cubit),
              ),
            ],
          ];
        },
      );
}
