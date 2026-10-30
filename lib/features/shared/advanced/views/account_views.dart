import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/i18n/app_dates.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../core/workspace/workspace_cubit.dart';
import '../../../../data/models/advanced/finance.dart';
import '../../../../data/models/bootstrap/flags.dart';
import '../../../../data/repositories/account_repository.dart';
import '../view_models/advanced_cubits.dart';

/// Account settings: enrolled devices, identity verification, and the
/// **in-app delete path both app stores require**.
class AccountSettingsView extends StatelessWidget {
  const AccountSettingsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => AccountCubit(getIt<AccountRepository>())..load(),
        child: const _AccountBody(),
      );
}

class _AccountBody extends StatelessWidget {
  const _AccountBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AccountCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final locale = context.locale.toString();

    // Nafath is only offered when the platform says it is on; with it off the
    // endpoint answers 200 `nafath_disabled`, which is a dead end for a user.
    final flags = context.watch<SessionCubit>().state.bootstrap?.platformFlags;
    final nafathEnabled = flags?.nafathEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('account.title'.tr())),
      body: Builder(
        builder: (context) {
          if (state.loading) return const FormSkeleton(fields: 4);
          // B9: a failed load is a state of its own, not an empty screen.
          if (state.errorMessage != null) {
            return AppErrorState(
              message: state.errorMessage!.isEmpty ? 'errors.generic'.tr() : state.errorMessage!,
              onRetry: cubit.load,
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.gutter,
                AppTokens.space2,
                AppTokens.gutter,
                AppTokens.space8,
              ),
              children: [
                AppSectionLabel(
                  'account.devices'.tr(),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.space1,
                    AppTokens.space2,
                    AppTokens.space1,
                    AppTokens.space1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTokens.space1,
                    0,
                    AppTokens.space1,
                    AppTokens.space3,
                  ),
                  child: Text(
                    'account.devices_hint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                ),
                if (state.devices.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        const AppIconCircle(Icons.fingerprint_rounded, tone: AppTone.neutral),
                        const SizedBox(width: AppTokens.space4),
                        Expanded(
                          child: Text(
                            'account.no_devices'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AppMenuGroup(
                    children: [
                      for (final device in state.devices)
                        AppMenuRow(
                          icon: _deviceIcon(device.devicePlatform),
                          title: device.deviceName.isEmpty ? device.deviceId : device.deviceName,
                          subtitle: [
                            device.devicePlatform,
                            device.biometricType,
                            if (device.lastUsedAt != null)
                              AppDates.date(device.lastUsedAt, locale),
                          ].where((part) => part.isNotEmpty).join(' · '),
                          showChevron: false,
                          trailing: IconButton(
                            tooltip: 'account.revoke'.tr(),
                            icon: Icon(Icons.link_off_rounded, color: t.dangerText),
                            onPressed: () => _revoke(context, cubit, device),
                          ),
                        ),
                    ],
                  ),

                AppSectionLabel('account.identity'.tr()),
                AppMenuGroup(
                  children: [
                    AppMenuRow(
                      icon: Icons.verified_user_outlined,
                      tone: nafathEnabled ? AppTone.brand : AppTone.neutral,
                      title: 'account.nafath'.tr(),
                      subtitle: nafathEnabled
                          ? 'account.nafath_hint'.tr()
                          : 'errors.nafath_disabled'.tr(),
                      onTap: nafathEnabled ? () => _openNafath(context) : null,
                    ),
                  ],
                ),

                AppSectionLabel('account.danger'.tr()),
                // The answer to the last action, above the actions it answers.
                FormMessage(message: state.action.message),
                _DeletionSection(state: state),
              ],
            ),
          );
        },
      ),
    );
  }

  static IconData _deviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ios') || p.contains('iphone') || p.contains('ipad')) {
      return Icons.phone_iphone_rounded;
    }
    if (p.contains('android')) return Icons.phone_android_rounded;
    return Icons.devices_outlined;
  }

  Future<void> _revoke(
    BuildContext context,
    AccountCubit cubit,
    BiometricCredential device,
  ) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'account.revoke'.tr(),
      body: 'account.revoke_confirm'.tr(),
      confirmLabel: 'account.revoke'.tr(),
      destructive: true,
    );
    if (!confirmed) return;
    final ok = await cubit.revokeDevice(device.id);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('errors.generic'.tr())),
    );
  }

  Future<void> _openNafath(BuildContext context) => showAppSheet<void>(
        context: context,
        title: 'account.nafath'.tr(),
        subtitle: 'account.nafath_hint'.tr(),
        builder: (_) => BlocProvider(
          create: (_) => NafathCubit(getIt<AccountRepository>()),
          child: const NafathSheet(),
        ),
      );
}

/// The delete path. It is deliberately the last thing on the screen, and
/// deliberately reversible while the request is still open.
class _DeletionSection extends StatelessWidget {
  final AccountState state;

  const _DeletionSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();
    final locale = context.locale.toString();

    if (state.deletionPending) {
      final request = state.deletion!;
      final scheduled = request.scheduledFor == null
          ? null
          : '${'account.deletion_scheduled'.tr()}: '
              '${AppDates.date(request.scheduledFor, locale)}';
      return AppBanner(
        tone: AppTone.danger,
        icon: Icons.delete_outline_rounded,
        title: scheduled == null ? null : 'account.deletion_pending'.tr(),
        message: scheduled ?? 'account.deletion_pending'.tr(),
        margin: EdgeInsetsDirectional.zero,
        action: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppTokens.space2),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.solid(
              label: 'account.deletion_cancel'.tr(),
              icon: Icons.restore_rounded,
              height: 48,
              expand: false,
              onPressed: cubit.cancelDeletion,
            ),
          ),
        ),
      );
    }

    return AppMenuGroup(
      children: [
        AppMenuRow(
          icon: Icons.delete_forever_outlined,
          tone: AppTone.danger,
          title: 'account.delete_account'.tr(),
          subtitle: 'account.delete_hint'.tr(),
          onTap: () => _confirm(context, cubit),
        ),
      ],
    );
  }

  /// The Driver "delete account" sheet: red title, what it does, an optional
  /// reason, and the one solid red button.
  Future<void> _confirm(BuildContext context, AccountCubit cubit) async {
    final reason = await showAppSheet<String>(
      context: context,
      title: 'account.delete_account'.tr(),
      subtitle: 'account.delete_confirm'.tr(),
      destructive: true,
      builder: (_) => const _DeletionSheet(),
    );
    if (reason == null) return;
    await cubit.requestDeletion(reason);
  }
}

class _DeletionSheet extends StatefulWidget {
  const _DeletionSheet();

  @override
  State<_DeletionSheet> createState() => _DeletionSheetState();
}

class _DeletionSheetState extends State<_DeletionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 5,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'account.delete_reason'.tr(),
              counterText: '',
              border: const OutlineInputBorder(borderRadius: AppTokens.lgRadius),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTokens.lgRadius,
                borderSide: BorderSide(color: context.tokens.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space6),
          AppButton.danger(
            label: 'account.delete_confirm_button'.tr(),
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          ),
        ],
      );
}

/// Nafath: start a check, then poll until the user approves it in their
/// Nafath app. The polling is bounded and stops as soon as it resolves.
///
/// Built as the body of a Driver sheet (`showAppSheet` draws the title).
class NafathSheet extends StatefulWidget {
  const NafathSheet({super.key});

  @override
  State<NafathSheet> createState() => _NafathSheetState();
}

class _NafathSheetState extends State<NafathSheet> {
  final _nationalId = TextEditingController();

  @override
  void dispose() {
    _nationalId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NafathCubit>();
    final state = cubit.state;
    final theme = Theme.of(context);
    final t = context.tokens;
    final transaction = state.transaction;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (transaction == null) ...[
          AppField(
            controller: _nationalId,
            label: 'account.national_id'.tr(),
            required: true,
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            maxLength: 10,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            helper: 'account.national_id_hint'.tr(),
          ),
          FormMessage(message: state.action.message),
          SubmitButton(
            busy: state.action.isSubmitting,
            label: 'account.nafath_start'.tr(),
            onPressed: () {
              final value = _nationalId.text.trim();
              if (value.length != 10) return;
              cubit.start(value);
            },
          ),
        ] else ...[
          // The number the user must match inside the Nafath app.
          if (transaction.randomText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppTokens.space5,
                vertical: AppTokens.space6,
              ),
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: AppTokens.lgRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                transaction.randomText,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: t.primary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space3),
            Text(
              'account.nafath_match'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppTokens.space5),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.polling) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
                ),
                const SizedBox(width: AppTokens.space3),
              ],
              StatusChip(status: transaction.status),
            ],
          ),
          const SizedBox(height: AppTokens.space6),
          FormMessage(message: state.action.message),
          if (transaction.isApproved)
            AppButton.solid(
              label: 'common.close'.tr(),
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            AppButton.outline(
              label: 'common.cancel'.tr(),
              onPressed: () async {
                await cubit.cancel();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ],
    );
  }
}

/// Opens a web-only screen with the session already established.
///
/// The URL is short-lived and signed, so it is fetched at the moment of the
/// tap rather than held. An in-app WebView would need `webview_flutter`; this
/// hands off to the system browser instead.
Future<void> openWebBridge(BuildContext context, String target) async {
  final workspace = context.read<WorkspaceCubit>().state;
  final locale = context.locale.languageCode;

  final result = await getIt<AccountRepository>().webBridge(
    target: target,
    organizationId: workspace?.organizationId,
    workspace: workspace?.workspaceParam,
    lang: locale,
  );

  if (result case Ok(:final data) when data.isValid) {
    await launchUrl(Uri.parse(data.url), mode: LaunchMode.externalApplication);
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.failureMessage ?? 'errors.generic'.tr())),
  );
}
