import '../../../core/network/coerce.dart';
import '../trade/supplier_summary.dart';

/// A settlement run: what the shelf sold, less what came back, less fees.
///
/// Every figure here is the server's arithmetic. The client displays it.
class Settlement {
  final int id;
  final int contractId;
  final int? branchId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String status;

  final double grossSales;
  final double returnsTotal;
  final double damageTotal;
  final double expiryTotal;
  final double shelfFees;
  final double serviceFees;
  final double netPayableSupplier;

  final String notes;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final List<Payout> payouts;

  const Settlement({
    required this.id,
    required this.contractId,
    required this.branchId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.grossSales,
    required this.returnsTotal,
    required this.damageTotal,
    required this.expiryTotal,
    required this.shelfFees,
    required this.serviceFees,
    required this.netPayableSupplier,
    required this.notes,
    required this.approvedAt,
    required this.paidAt,
    required this.payouts,
  });

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        id: asInt(j['id']),
        contractId: asInt(j['contract_id']),
        branchId: asIntOrNull(j['branch_id']),
        periodStart: asDate(j['period_start']),
        periodEnd: asDate(j['period_end']),
        status: asStr(j['status']),
        grossSales: asNum(j['gross_sales']),
        returnsTotal: asNum(j['returns_total']),
        damageTotal: asNum(j['damage_total']),
        expiryTotal: asNum(j['expiry_total']),
        shelfFees: asNum(j['shelf_fees']),
        serviceFees: asNum(j['service_fees']),
        netPayableSupplier: asNum(j['net_payable_supplier']),
        notes: unwrap(j['notes']),
        approvedAt: asDate(j['approved_at']),
        paidAt: asDate(j['paid_at']),
        payouts: asList(j['payouts'], Payout.fromJson),
      );

  static const statuses = ['draft', 'calculated', 'reviewed', 'approved', 'paid', 'closed'];

  bool get isPaid => status == 'paid' || paidAt != null;
}

class Payout {
  final int id;
  final int? bankAccountId;
  final double amount;
  final DateTime? paidAt;
  final String referenceNo;
  final String status;
  final String notes;

  const Payout({
    required this.id,
    required this.bankAccountId,
    required this.amount,
    required this.paidAt,
    required this.referenceNo,
    required this.status,
    required this.notes,
  });

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: asInt(j['id']),
        bankAccountId: asIntOrNull(j['bank_account_id']),
        amount: asNum(j['amount']),
        paidAt: asDate(j['paid_at']),
        referenceNo: asStr(j['reference_no']),
        status: asStr(j['status']),
        notes: unwrap(j['notes']),
      );

  static const statuses = ['pending', 'completed', 'failed'];
}

/// The organization wallet. The payload is not published field by field, so
/// the common names are read and the row is kept.
class Wallet {
  final double balance;
  final double pendingBalance;
  final String currencyCode;
  final Map<String, dynamic> raw;

  const Wallet({
    required this.balance,
    required this.pendingBalance,
    required this.currencyCode,
    required this.raw,
  });

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        balance: asNum(j['balance'] ?? j['available_balance'] ?? j['amount']),
        pendingBalance: asNum(j['pending_balance'] ?? j['pending']),
        currencyCode: asStr(j['currency_code'] ?? j['currency']),
        raw: j,
      );
}

class WalletTransaction {
  final int id;
  final String type;
  final double amount;
  final String description;
  final String status;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        id: asInt(j['id']),
        type: asStr(j['type'] ?? j['direction']),
        amount: asNum(j['amount']),
        description: unwrap(j['description'] ?? j['note'] ?? j['reason']),
        status: asStr(j['status']),
        createdAt: asDate(j['created_at']),
      );

  /// A credit adds to the balance; anything else is read as a debit.
  bool get isCredit =>
      amount > 0 && (type.contains('credit') || type.contains('in') || type.isEmpty);
}

/// A way to top the wallet up. Which ones appear depends on
/// `platform_flags` — a gateway that is switched off must not be offered.
class TopupMethod {
  final String code;
  final String labelAr;
  final String labelEn;
  final bool enabled;

  const TopupMethod({
    required this.code,
    required this.labelAr,
    required this.labelEn,
    required this.enabled,
  });

  factory TopupMethod.fromJson(Map<String, dynamic> j) => TopupMethod(
        code: asStr(j['code'] ?? j['method'] ?? j['key']),
        labelAr: unwrap(j['label_ar'] ?? j['name_ar']),
        labelEn: unwrap(j['label_en'] ?? j['name_en'] ?? j['name']),
        enabled: j['enabled'] == null ? true : asBool(j['enabled']),
      );

  static const bankTransfer = 'bank_transfer';
  static const hyperpay = 'hyperpay';
  static const applePay = 'apple_pay';

  String label(String locale) {
    final localized = pickLocalized(locale: locale, ar: labelAr, en: labelEn);
    return localized.isNotEmpty ? localized : code;
  }
}

/// A subscription plan. Field names are not published, so the usual ones are
/// read and the row kept for whatever else a plan carries.
class SubscriptionPlan {
  final int id;
  final String nameAr;
  final String nameEn;
  final double monthlyPrice;
  final double yearlyPrice;
  final String currencyCode;
  final Map<String, dynamic> raw;

  const SubscriptionPlan({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.currencyCode,
    required this.raw,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        id: asInt(j['id']),
        nameAr: unwrap(j['name_ar'] ?? j['name']),
        nameEn: unwrap(j['name_en'] ?? j['name']),
        monthlyPrice: asNum(j['monthly_price'] ?? j['price_monthly'] ?? j['price']),
        yearlyPrice: asNum(j['yearly_price'] ?? j['price_yearly']),
        currencyCode: asStr(j['currency_code'] ?? j['currency']),
        raw: j,
      );

  String label(String locale) => pickLocalized(locale: locale, ar: nameAr, en: nameEn);

  /// Quotas a plan grants, which is what the `plan.quota:` middleware
  /// enforces on relationships, drafts, invoices and contracts.
  Map<String, dynamic> get quotas => asMap(raw['quotas'] ?? raw['limits']);
}

/// `GET /v2/subscription/current` → `{summary}`.
class SubscriptionSummary {
  final String status;

  /// `subscription` | `commission`.
  final String billingMode;

  final int? planId;
  final String planName;
  final DateTime? trialEndsAt;
  final DateTime? renewsAt;
  final Map<String, dynamic> raw;

  const SubscriptionSummary({
    required this.status,
    required this.billingMode,
    required this.planId,
    required this.planName,
    required this.trialEndsAt,
    required this.renewsAt,
    required this.raw,
  });

  factory SubscriptionSummary.fromJson(Map<String, dynamic> j) => SubscriptionSummary(
        status: asStr(j['status']),
        billingMode: asStr(j['billing_mode'] ?? j['mode']),
        planId: asIntOrNull(j['plan_id']),
        planName: unwrap(j['plan_name'] ?? j['plan']),
        trialEndsAt: asDate(j['trial_ends_at']),
        renewsAt: asDate(j['renews_at'] ?? j['next_billing_at']),
        raw: j,
      );

  static const billingModes = ['subscription', 'commission'];

  bool get onTrial => status == 'trial' || trialEndsAt != null;
}

/// The in-app delete path both app stores require.
class DeletionRequest {
  final int? id;
  final String status;
  final String reason;
  final DateTime? requestedAt;
  final DateTime? scheduledFor;

  const DeletionRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.requestedAt,
    required this.scheduledFor,
  });

  factory DeletionRequest.fromJson(Map<String, dynamic> j) => DeletionRequest(
        id: asIntOrNull(j['id']),
        status: asStr(j['status']),
        reason: unwrap(j['reason']),
        requestedAt: asDate(j['requested_at'] ?? j['created_at']),
        scheduledFor: asDate(j['scheduled_for'] ?? j['delete_at']),
      );

  bool get isActive => id != null && status != 'canceled' && status != 'completed';
}

/// A Nafath identity check. Polled until it resolves.
class NafathTransaction {
  final String transactionId;
  final String status;
  final String randomText;
  final DateTime? expiresAt;

  const NafathTransaction({
    required this.transactionId,
    required this.status,
    required this.randomText,
    required this.expiresAt,
  });

  factory NafathTransaction.fromJson(Map<String, dynamic> j) => NafathTransaction(
        // Nafath ids are the one path segment that is not numeric-only.
        transactionId: asStr(j['transaction_id'] ?? j['id']),
        status: asStr(j['status']),
        // The number the user must match in the Nafath app.
        randomText: asStr(j['random_text'] ?? j['random'] ?? j['code']),
        expiresAt: asDate(j['expires_at']),
      );

  bool get isPending => status.isEmpty || status == 'pending' || status == 'waiting';
  bool get isApproved => status == 'approved' || status == 'completed';
  bool get isRejected => status == 'rejected' || status == 'expired' || status == 'failed';
}

/// A device enrolled for biometric sign-in.
class BiometricCredential {
  final int id;
  final String deviceId;
  final String deviceName;
  final String devicePlatform;
  final String biometricType;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  const BiometricCredential({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.devicePlatform,
    required this.biometricType,
    required this.createdAt,
    required this.lastUsedAt,
  });

  factory BiometricCredential.fromJson(Map<String, dynamic> j) => BiometricCredential(
        id: asInt(j['id']),
        deviceId: asStr(j['device_id']),
        deviceName: unwrap(j['device_name']),
        devicePlatform: asStr(j['device_platform']),
        biometricType: asStr(j['biometric_type']),
        createdAt: asDate(j['created_at']),
        lastUsedAt: asDate(j['last_used_at']),
      );
}

/// `POST /v2/mobile/web_bridge` → a short-lived signed URL for a screen the
/// native app does not implement.
class WebBridgeLink {
  final String url;
  final String target;
  final int expiresInSeconds;

  const WebBridgeLink({
    required this.url,
    required this.target,
    required this.expiresInSeconds,
  });

  factory WebBridgeLink.fromJson(Map<String, dynamic> j) => WebBridgeLink(
        url: asStr(j['url']),
        target: asStr(j['target']),
        expiresInSeconds: asInt(j['expires_in_seconds']),
      );

  bool get isValid => url.isNotEmpty;

  /// When to fetch a fresh one, with a margin so a slow page load does not
  /// land on an expired link.
  Duration get refreshAfter =>
      Duration(seconds: (expiresInSeconds * 0.8).round().clamp(10, 3600));
}

/// Everything about a counterparty the ratings screen needs.
class RatedCounterparty {
  final int organizationId;
  final String displayName;
  final BusinessRelationship? relationship;

  const RatedCounterparty({
    required this.organizationId,
    required this.displayName,
    required this.relationship,
  });
}
