import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/models/onboarding/bank_account.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import '../view_models/onboarding_form_cubits.dart';
import 'widgets/collection_scaffold.dart';
import '../view_models/onboarding_cubit.dart';

/// `POST /api/v2/onboarding/bank_accounts` — an upsert.
///
/// `iban` and `account_number` come back as **numbers** when they are all
/// digits, which is why the model reads them as strings.
class BankAccountsView extends StatelessWidget {
  const BankAccountsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => BankAccountsCubit(getIt<OnboardingRepository>())..load(),
        child: const _BankAccountsBody(),
      );
}

class _BankAccountsBody extends StatelessWidget {
  const _BankAccountsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<BankAccountsCubit>();

    return CollectionScaffold<BankAccount>(
      title: 'bank.title'.tr(),
      subtitle: 'bank.subtitle'.tr(),
      emptyMessage: 'bank.empty'.tr(),
      addLabel: 'bank.add'.tr(),
      state: cubit.state,
      onRetry: cubit.load,
      onAdd: () => _openEditor(context, null),
      changeKind: OnboardingStepKind.bankAccounts,
      emptyIcon: Icons.account_balance_outlined,
      itemBuilder: (account) => CollectionTile(
        icon: Icons.account_balance_outlined,
        title: account.bankName,
        subtitle: account.iban.isEmpty ? account.accountName : account.maskedIban,
        trailing: account.currencyCode.isEmpty ? null : account.currencyCode,
        onTap: () => _openEditor(context, account),
      ),
    );
  }

  void _openEditor(BuildContext context, BankAccount? account) {
    final cubit = context.read<BankAccountsCubit>();
    cubit.resetForm();

    showEditorSheet(
      context: context,
      title: account == null ? 'bank.add'.tr() : 'bank.edit'.tr(),
      fields: (_) => [
        BlocProvider.value(value: cubit, child: _BankForm(account: account)),
      ],
    );
  }
}

class _BankForm extends StatefulWidget {
  final BankAccount? account;

  const _BankForm({required this.account});

  @override
  State<_BankForm> createState() => _BankFormState();
}

class _BankFormState extends State<_BankForm> {
  final _formKey = GlobalKey<FormState>();
  late final _bankName = TextEditingController(text: widget.account?.bankName ?? '');
  late final _accountName = TextEditingController(text: widget.account?.accountName ?? '');
  late final _accountNumber = TextEditingController(text: widget.account?.accountNumber ?? '');
  late final _iban = TextEditingController(text: widget.account?.iban ?? '');
  late final _swift = TextEditingController(text: widget.account?.swiftCode ?? '');
  late final _currency =
      TextEditingController(text: widget.account?.currencyCode.isNotEmpty == true
          ? widget.account!.currencyCode
          : 'SAR');

  @override
  void dispose() {
    for (final controller in [
      _bankName,
      _accountName,
      _accountNumber,
      _iban,
      _swift,
      _currency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final saved = await context.read<BankAccountsCubit>().save(
          bankAccountId: widget.account?.id,
          bankName: _bankName.text,
          accountName: _accountName.text,
          accountNumber: _accountNumber.text,
          iban: _iban.text,
          swiftCode: _swift.text,
          currencyCode: _currency.text,
        );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = context.watch<BankAccountsCubit>().state.submit;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormMessage(message: submit.message),
          AppField(
            controller: _bankName,
            label: 'bank.bank_name'.tr(),
            required: true,
            icon: Icons.account_balance_outlined,
            validator: AppValidators.required,
            serverError: submit.fieldError('bank_name'),
          ),
          AppField(
            controller: _accountName,
            label: 'bank.account_name'.tr(),
            required: true,
            icon: Icons.person_outline_rounded,
            validator: AppValidators.required,
            serverError: submit.fieldError('account_name'),
          ),
          AppField(
            controller: _accountNumber,
            label: 'bank.account_number'.tr(),
            keyboardType: TextInputType.number,
            // Account numbers, IBANs and SWIFT codes read LTR in Arabic too.
            textDirection: TextDirection.ltr,
            serverError: submit.fieldError('account_number'),
          ),
          AppField(
            controller: _iban,
            label: 'bank.iban'.tr(),
            keyboardType: TextInputType.text,
            textDirection: TextDirection.ltr,
            hint: 'SA00 0000 0000 0000 0000 0000',
            serverError: submit.fieldError('iban'),
          ),
          AppField(
            controller: _swift,
            label: 'bank.swift'.tr(),
            textDirection: TextDirection.ltr,
            serverError: submit.fieldError('swift_code'),
          ),
          AppField(
            controller: _currency,
            label: 'bank.currency'.tr(),
            maxLength: 3,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            serverError: submit.fieldError('currency_code'),
          ),
          const SizedBox(height: AppTokens.space2),
          SubmitButton(
            busy: submit.isSubmitting,
            label: 'common.save'.tr(),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
