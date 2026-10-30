import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/error/api_failure_ui.dart';
import '../../../core/network/api_result.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/services/remote_services/service_locator.dart';
import '../../../data/models/lookups/lookup_item.dart';
import '../../../data/repositories/lookups_repository.dart';
import '../../../data/repositories/organization_repository.dart';

/// «الفريق والصلاحيات» (guide Part 2.6): the organization's members, their
/// roles, default branch and status. Adding one creates their account; the
/// server answers with a temporary password, shown once to hand over.
class TeamView extends StatefulWidget {
  const TeamView({super.key});

  @override
  State<TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<TeamView> {
  final _repo = getIt<OrganizationRepository>();
  late Future<ApiResult<List<Employee>>> _future = _repo.employees();
  List<OrgRoleOption> _roles = const [];
  List<LookupItem> _branches = const [];

  @override
  void initState() {
    super.initState();
    _repo.roles().then((r) => mounted ? setState(() => _roles = r.dataOrNull ?? const []) : null);
    getIt<LookupsRepository>()
        .items(Lookup.branches)
        .then((r) => mounted ? setState(() => _branches = r.dataOrNull ?? const []) : null);
  }

  void _reload() => setState(() => _future = _repo.employees());

  Future<void> _edit([Employee? employee]) async {
    final result = await showAppSheet<({Employee employee, String temporaryPassword})>(
      context: context,
      title: employee == null ? 'team.add'.tr() : 'team.edit'.tr(),
      builder: (_) => _EmployeeForm(employee: employee, roles: _roles, branches: _branches),
    );
    if (result == null || !mounted) return;
    _reload();
    if (result.temporaryPassword.isNotEmpty) {
      await showAppConfirm(
        context,
        title: 'team.created_title'.tr(),
        body: 'team.temporary_password'.tr(namedArgs: {'password': result.temporaryPassword}),
        confirmLabel: 'team.copy_password'.tr(),
        cancelLabel: 'common.done'.tr(),
      ).then((copy) {
        if (copy) Clipboard.setData(ClipboardData(text: result.temporaryPassword));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('team.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text('team.add'.tr()),
      ),
      body: FutureBuilder<ApiResult<List<Employee>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const ListSkeleton(rows: 4);
          final result = snapshot.data;
          if (result is! Ok<List<Employee>>) {
            return AppErrorState(message: result?.failureMessage ?? 'errors.generic'.tr(), onRetry: _reload);
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(AppTokens.gutter, AppTokens.space3, AppTokens.gutter, 96),
              children: [
                Text('team.hint'.tr(), style: theme.textTheme.bodySmall),
                const SizedBox(height: AppTokens.space3),
                for (final e in result.data)
                  AppCard.item(
                    // The owner is managed by the platform, not here.
                    onTap: e.isOwner ? null : () => _edit(e),
                    child: Row(
                      children: [
                        AppInitialAvatar(name: e.name),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name, style: theme.textTheme.titleSmall),
                              Text(
                                [
                                  e.isOwner ? 'team.owner'.tr() : e.jobTitle,
                                  if (e.roleNames.isNotEmpty) e.roleNames.join('، '),
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusChip(status: e.status),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeForm extends StatefulWidget {
  final Employee? employee;
  final List<OrgRoleOption> roles;
  final List<LookupItem> branches;

  const _EmployeeForm({required this.employee, required this.roles, required this.branches});

  @override
  State<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<_EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.employee?.name ?? '');
  late final _email = TextEditingController(text: widget.employee?.email ?? '');
  late final _phone = TextEditingController(text: _phoneText(widget.employee?.phone));
  late final _job = TextEditingController(text: widget.employee?.jobTitle ?? '');
  late final Set<int> _roleIds = {...?widget.employee?.roleIds};
  late int? _branchId = widget.employee?.defaultBranchId;
  late String? _status = widget.employee?.status.isEmpty ?? true ? 'active' : widget.employee!.status;
  bool _busy = false;
  String? _error;

  /// The server drops a phone's leading zero (it stores a number).
  static String _phoneText(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.startsWith('5') ? '0$raw' : raw;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _job]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // The whole row, every time: an update clears what it does not send.
    final result = await getIt<OrganizationRepository>().saveEmployee(
      membershipId: widget.employee?.membershipId,
      name: _name.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      jobTitle: _job.text.trim().isEmpty ? null : _job.text.trim(),
      roleIds: _roleIds.toList(),
      defaultBranchId: _branchId,
      status: _status ?? 'active',
    );
    if (!mounted) return;
    if (result case Ok(:final data)) {
      Navigator.of(context).pop(data);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.failureMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(controller: _name, label: 'team.name'.tr(), required: true, validator: AppValidators.required),
          AppField(
            controller: _email,
            label: 'auth.email'.tr(),
            required: true,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            validator: AppValidators.email,
          ),
          AppField(
            controller: _phone,
            label: 'register.phone'.tr(),
            hint: SaudiPhone.hint,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            inputFormatters: SaudiPhone.formatters,
          ),
          AppField(controller: _job, label: 'team.job_title'.tr(), hint: 'common.optional'.tr()),
          if (widget.branches.isNotEmpty)
            IdPicker<LookupItem>(
              label: 'team.default_branch'.tr(),
              value: _branchId,
              items: widget.branches,
              idOf: (b) => b.id,
              labelOf: (b) => b.label(locale),
              required: false,
              onChanged: (id) => setState(() => _branchId = id),
            ),
          if (widget.employee != null)
            CodePicker(
              label: 'team.status'.tr(),
              value: _status,
              codes: const ['active', 'suspended'],
              labelOf: (code) => 'status.$code'.tr(),
              onChanged: (value) => setState(() => _status = value),
            ),
          Text('team.roles'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: AppTokens.space2),
          for (final role in widget.roles)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _roleIds.contains(role.id),
              onChanged: (checked) => setState(() => checked == true ? _roleIds.add(role.id) : _roleIds.remove(role.id)),
              title: Text(role.name, style: theme.textTheme.titleSmall),
              subtitle: role.permissions.isEmpty
                  ? null
                  : Text(role.permissions.join('، '), style: theme.textTheme.bodySmall, maxLines: 3),
            ),
          FormMessage(message: _error),
          SubmitButton(busy: _busy, label: 'common.save'.tr(), onPressed: _submit),
        ],
      ),
    );
  }
}
