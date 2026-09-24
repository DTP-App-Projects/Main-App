import 'package:easy_localization/easy_localization.dart';

/// Server error codes are stable snake_case keys. Users never see one.
///
/// The awkward exception is v1: for credential-style `401`s the backend puts
/// **already-localized prose** in `msg` rather than a code, so a value that
/// does not look like a key is passed through instead of being flattened to a
/// generic message.
class ErrorMessages {
  ErrorMessages._();

  /// Codes we ship copy for. Anything else falls back to the generic message,
  /// so a new backend code degrades quietly instead of leaking.
  static const _translated = <String>{
    // context / transport
    'validation_error',
    'permission_denied',
    'organization_membership_not_found',
    'organization_workspace_not_allowed',
    'unexpected_error',
    'parse_error',
    'offline',
    'rate_limited',
    'request_failed',
    'request_canceled',
    // v1 credentials
    'invalid_email',
    'invalid_password',
    'invalid_code',
    'email_exists',
    'phone_exists',
    'company_name_exists',
    'old_password_incorrect',
    'suspended_user',
    // onboarding / org
    'branch_name_required',
    'organization_not_accessible',
    'nafath_disabled',
    // trade flow
    'sku_not_belong_to_draft_supplier',
    'qty_less_than_min_order_qty',
    'qty_not_matching_order_step',
    'insufficient_supplier_inventory',
    'pricing_not_found_for_sku',
    'draft_has_no_lines',
    'draft_not_found_or_not_open',
    'relationship_is_blacklisted',
    'approved_business_relationship_required_before_submit',
    'relationship_must_be_approved_before_submit',
    'purchase_order_not_found',
    'reason_required',
    'credit_manage_permission_required_for_override',
    'goods_receipt_edit_window_closed',
    'delivery_note_not_found',
    'invoice_not_found',
    'invoice_or_due_schedule_required',
    'post_invoice_return_not_found',
    'supplier_organization_not_found',
    'cannot_follow_self',
    'product_not_accessible',
    // supplier flow
    'price_list_name_required',
    'scope_id_required_for_selected_scope',
    'max_qty_must_be_greater_than_or_equal_min_qty',
    'seals_can_only_be_set_before_dispatch',
    'pickup_seals_required_before_dispatch',
    'supplier_or_trader_branch_missing',
    'credit_profile_can_only_be_managed_by_supplier_side',
    'sku_not_belong_to_current_organization',
    'post_invoice_return_transition_not_allowed_for_role',
    'invoice_issue_failed',
    'purchase_order_not_found_for_invoice_issue',
    'purchase_order_not_found_for_supplier',
    'delivery_note_not_found_for_supplier',
    'price_list_not_found',
    'relationship_not_found',
    'invalid_counterparty_organization',
    // advanced
    'request_already_exists',
    'no_active_request',
    'already_subscribed',
    'plan_not_available',
    'contract_not_found',
    'settlement_not_found',
    'shelf_contract_not_found_or_not_accessible',
    'relationship_not_accessible',
    'no_shared_relationship_to_view_ratings',
    'target_organization_id_required',
    'contract_approval_not_found',
    'approval_actor_not_allowed',
  };

  static String forCode(String? code, {int status = 0}) {
    final normalized = normalize(code);
    if (normalized.isEmpty) return 'errors.generic'.tr();
    if (_translated.contains(normalized)) return 'errors.$normalized'.tr();

    // v1 hands back translated prose for credential failures. A value with
    // spaces and no underscores is a sentence, not a key.
    final raw = code!.trim();
    if (status == 401 && raw.contains(' ') && !raw.contains('_')) return raw;

    return 'errors.generic'.tr();
  }

  /// `"suspended user"` → `suspended_user`. The login endpoint is the only
  /// place that sends a code with a space in it.
  static String normalize(String? code) =>
      (code ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
