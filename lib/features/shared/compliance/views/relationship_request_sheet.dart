import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../data/models/compliance/relationship_request.dart';

/// The website's «إرسال طلب علاقة تجارية» (guide Part 6.2): the requested
/// supply model is required, and a credit request also states its term, limit
/// and how the debt is documented. Resolves to the draft, or null if dismissed.
Future<RelationshipRequestDraft?> showRelationshipRequestSheet(
  BuildContext context, {
  required String counterpartyName,
}) =>
    showAppSheet<RelationshipRequestDraft>(
      context: context,
      title: 'rr.new_title'.tr(),
      subtitle: counterpartyName,
      builder: (_) => const _RequestForm(),
    );

class _RequestForm extends StatefulWidget {
  const _RequestForm();

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  static const _models = ['direct', 'credit', 'consignment'];
  static const _documentation = ['acknowledgment_only', 'promissory_note', 'both'];

  final _formKey = GlobalKey<FormState>();
  final _term = TextEditingController();
  final _limit = TextEditingController();
  final _notes = TextEditingController();

  String? _model = 'direct';
  String? _debtDocumentation = 'acknowledgment_only';

  bool get _credit => _model == 'credit';

  @override
  void dispose() {
    for (final controller in [_term, _limit, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The server's range: 1–365 days.
  static String? _termValidator(String? value) {
    final days = int.tryParse((value ?? '').trim());
    if (days == null) return 'validation.required'.tr();
    return days < 1 || days > 365 ? 'rr.term_range'.tr() : null;
  }

  static String? _limitValidator(String? value) {
    final amount = double.tryParse((value ?? '').trim());
    if (amount == null) return 'validation.required'.tr();
    return amount <= 0 ? 'rr.limit_positive'.tr() : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(RelationshipRequestDraft(
      model: _model!,
      creditTermDays: _credit ? int.parse(_term.text.trim()) : null,
      creditLimit: _credit ? double.parse(_limit.text.trim()) : null,
      debtDocumentation: _credit ? _debtDocumentation : null,
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodePicker(
            label: 'rr.model'.tr(),
            value: _model,
            codes: _models,
            labelOf: (code) => 'rr.model_$code'.tr(),
            onChanged: (value) => setState(() => _model = value),
          ),
          if (_model == 'consignment')
            AppBanner(
              message: 'rr.consignment_hint'.tr(),
              tone: AppTone.info,
              margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
            ),
          if (_credit) ...[
            AppField(
              controller: _term,
              label: 'rr.credit_term'.tr(),
              required: true,
              suffixText: 'rr.days'.tr(),
              helper: 'rr.term_range'.tr(),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              validator: _termValidator,
            ),
            AppField(
              controller: _limit,
              label: 'rr.credit_limit'.tr(),
              required: true,
              suffixText: 'SAR',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              validator: _limitValidator,
            ),
            CodePicker(
              label: 'rr.debt_documentation'.tr(),
              value: _debtDocumentation,
              codes: _documentation,
              labelOf: (code) => 'rr.debt_$code'.tr(),
              onChanged: (value) => setState(() => _debtDocumentation = value),
            ),
          ],
          AppField(
            controller: _notes,
            label: 'rr.notes'.tr(),
            hint: 'common.optional'.tr(),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space3),
            child: Text(
              'rr.signatory_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
            ),
          ),
          AppButton.primary(label: 'rr.send'.tr(), onPressed: _submit),
        ],
      ),
    );
  }
}
