import 'dart:io' show Platform;

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/advanced/contract.dart';
import '../models/advanced/finance.dart';
import '../models/advanced/shelf.dart';

/// Settlements, wallet, subscription, ratings, and the account-level screens
/// both app stores require.
class AccountRepository {
  final ApiClient _client;

  AccountRepository(this._client);

  // ------------------------------------------------------------ settlements

  Future<ApiResult<Paged<Settlement>>> settlements({
    int page = 1,
    String? status,
    int? contractId,
    int limit = 15,
  }) =>
      _client.get<Paged<Settlement>>(
        ApiPaths.settlements,
        query: {
          ...PageParams.limit(page, size: limit),
          'status': ?status,
          'contract_id': ?contractId,
        },
        parse: (body) => Paged.fromJson(asMap(body), Settlement.fromJson),
      );

  Future<ApiResult<Settlement>> settlement(int id) => _client.get<Settlement>(
        ApiPaths.settlement(id),
        parse: (body) => Settlement.fromJson(asMap(asMap(body)['settlement'])),
      );

  Future<ApiResult<Settlement>> setSettlementStatus({
    required int id,
    required String status,
  }) =>
      _client.patch<Settlement>(
        ApiPaths.settlementStatus(id),
        body: {'status': status},
        parse: (body) => Settlement.fromJson(asMap(asMap(body)['settlement'])),
      );

  Future<ApiResult<Payout>> createPayout({
    required int settlementId,
    int? bankAccountId,
    double? amount,
    DateTime? paidAt,
    String? referenceNo,
    String? status,
    String? notes,
  }) =>
      _client.post<Payout>(
        ApiPaths.settlementPayouts(settlementId),
        body: {
          'bank_account_id': ?bankAccountId,
          'amount': ?amount,
          if (paidAt != null) 'paid_at': _day(paidAt),
          'reference_no': ?referenceNo,
          'status': ?status,
          'notes': ?notes,
        },
        parse: (body) => Payout.fromJson(asMap(asMap(body)['payout'])),
      );

  // ------------------------------------------------------ internal transfers

  Future<ApiResult<Paged<InternalTransfer>>> internalTransfers({
    int page = 1,
    int limit = 15,
  }) =>
      _client.get<Paged<InternalTransfer>>(
        ApiPaths.internalTransfers,
        query: PageParams.limit(page, size: limit),
        parse: (body) => Paged.fromJson(asMap(body), InternalTransfer.fromJson),
      );

  Future<ApiResult<InternalTransfer>> createInternalTransfer({
    required int sourceBranchId,
    required int destinationBranchId,
    required List<TransferLineInput> lines,
    DateTime? requiredByDate,
    String? priority,
  }) =>
      _client.post<InternalTransfer>(
        ApiPaths.internalTransfers,
        body: {
          'source_branch_id': sourceBranchId,
          'destination_branch_id': destinationBranchId,
          if (requiredByDate != null) 'required_by_date': _day(requiredByDate),
          'priority': ?priority,
          'lines': lines.map((line) => line.toJson()).toList(),
        },
        parse: (body) =>
            InternalTransfer.fromJson(asMap(asMap(body)['internal_transfer'])),
      );

  // ----------------------------------------------------------------- wallet

  Future<ApiResult<Wallet>> wallet() => _client.get<Wallet>(
        ApiPaths.wallet,
        parse: (body) => Wallet.fromJson(asMap(asMap(body)['wallet'])),
      );

  Future<ApiResult<Paged<WalletTransaction>>> walletTransactions({int page = 1}) =>
      _client.get<Paged<WalletTransaction>>(
        ApiPaths.walletTransactions,
        query: PageParams.limit(page),
        parse: (body) =>
            Paged.fromJson(asMap(body), WalletTransaction.fromJson, formattedKey: false),
      );

  Future<ApiResult<List<TopupMethod>>> topupMethods() => _client.get<List<TopupMethod>>(
        ApiPaths.walletTopupMethods,
        parse: (body) => asList(asMap(body)['methods'], TopupMethod.fromJson),
      );

  /// `transfer_proof_path` is an upload path, not a file.
  Future<ApiResult<void>> requestTopup({
    required double amount,
    required String method,
    String? bankReference,
    String? transferProofPath,
    String? gatewayPaymentId,
  }) =>
      _client.post<void>(
        ApiPaths.walletTopupRequests,
        body: {
          'amount': amount,
          'method': method,
          'bank_reference': ?bankReference,
          'transfer_proof_path': ?transferProofPath,
          'gateway_payment_id': ?gatewayPaymentId,
        },
      );

  // ----------------------------------------------------------- subscription

  Future<ApiResult<List<SubscriptionPlan>>> plans() => _client.get<List<SubscriptionPlan>>(
        ApiPaths.subscriptionPlans,
        parse: (body) => asList(asMap(body)['plans'], SubscriptionPlan.fromJson),
      );

  Future<ApiResult<SubscriptionSummary>> currentSubscription() =>
      _client.get<SubscriptionSummary>(
        ApiPaths.subscriptionCurrent,
        parse: (body) => SubscriptionSummary.fromJson(asMap(asMap(body)['summary'])),
      );

  Future<ApiResult<void>> setBillingMode(String mode) =>
      _client.put<void>(ApiPaths.subscriptionBillingMode, body: {'mode': mode});

  /// `422 already_subscribed` when a trial has been used — a real answer, not
  /// a failure to retry.
  Future<ApiResult<void>> startTrial() => _client.post<void>(ApiPaths.subscriptionTrial);

  /// Returns a `checkout_id` for the HyperPay widget. Gate the entry point on
  /// `platform_flags.payment_gateway_enabled` first.
  Future<ApiResult<String>> hyperpayCheckout({
    required int planId,
    required String brand,
    String? billingCycle,
  }) =>
      _client.post<String>(
        ApiPaths.hyperpayCheckout,
        body: {
          'plan_id': planId,
          'brand': brand,
          'billing_cycle': ?billingCycle,
        },
        parse: (body) => asStr(asMap(body)['checkout_id']),
      );

  // ---------------------------------------------------------------- ratings

  Future<ApiResult<List<Rating>>> ratings({
    required int businessRelationshipId,
    String? dimension,
  }) =>
      _client.get<List<Rating>>(
        ApiPaths.ratings,
        query: {
          'business_relationship_id': businessRelationshipId,
          'dimension': ?dimension,
        },
        parse: (body) {
          final map = asMap(body);
          return asList(map['ratings'] ?? map['data'] ?? map['items'], Rating.fromJson);
        },
      );

  /// The dimension vocabulary is server-side and unreadable from the
  /// validators, so the picker is built from what comes back here.
  Future<ApiResult<RatingAggregate>> ratingAggregate({
    int? businessRelationshipId,
    int? organizationIdTarget,
  }) =>
      _client.get<RatingAggregate>(
        ApiPaths.ratingsAggregate,
        query: {
          'business_relationship_id': ?businessRelationshipId,
          'organization_id_target': ?organizationIdTarget,
        },
        parse: (body) => RatingAggregate.fromJson(asMap(body)),
      );

  Future<ApiResult<Rating>> rate({
    required int businessRelationshipId,
    required String dimension,
    required int score,
    String? note,
  }) =>
      _client.post<Rating>(
        ApiPaths.ratings,
        body: {
          'business_relationship_id': businessRelationshipId,
          'dimension': dimension,
          'score': score.clamp(1, 5),
          'note': ?note,
        },
        parse: (body) => Rating.fromJson(asMap(asMap(body)['rating'])),
      );

  // -------------------------------------------------------- account deletion

  /// **Both app stores require this path to exist in the app.**
  /// `409 request_already_exists` when one is already open.
  Future<ApiResult<DeletionRequest>> requestDeletion({String? reason}) =>
      _client.post<DeletionRequest>(
        ApiPaths.accountDeletionRequest,
        body: {'reason': ?reason},
        parse: (body) => DeletionRequest.fromJson(asMap(asMap(body)['request'])),
      );

  Future<ApiResult<DeletionRequest>> deletionRequest() => _client.get<DeletionRequest>(
        ApiPaths.accountDeletionRequest,
        parse: (body) => DeletionRequest.fromJson(asMap(asMap(body)['request'])),
      );

  /// `404 no_active_request` when there is nothing to cancel.
  Future<ApiResult<void>> cancelDeletion() =>
      _client.delete<void>(ApiPaths.accountDeletionRequest);

  // ----------------------------------------------------------------- Nafath

  /// Check `platform_flags.nafath_enabled` before showing the entry point:
  /// when the feature is off this answers **200** with `nafath_disabled`,
  /// which the normalizer turns into a failure rather than a success.
  Future<ApiResult<NafathTransaction>> startNafath({
    required String nationalId,
    String purpose = 'login',
  }) =>
      _client.post<NafathTransaction>(
        ApiPaths.nafathInitiate,
        body: {'national_id': nationalId, 'purpose': purpose},
        parse: (body) {
          final map = asMap(body);
          return NafathTransaction.fromJson(asMap(map['transaction'] ?? map));
        },
      );

  /// Polled until it resolves. Not de-duplicated: a poll must see fresh state.
  Future<ApiResult<NafathTransaction>> nafathStatus(String transactionId) =>
      _client.get<NafathTransaction>(
        ApiPaths.nafathTransaction(transactionId),
        dedupe: false,
        parse: (body) =>
            NafathTransaction.fromJson(asMap(asMap(body)['transaction'])),
      );

  Future<ApiResult<void>> cancelNafath(String transactionId) =>
      _client.post<void>(ApiPaths.nafathCancel(transactionId));

  // -------------------------------------------------------------- biometric

  Future<ApiResult<List<BiometricCredential>>> biometricCredentials() =>
      _client.get<List<BiometricCredential>>(
        ApiPaths.biometricCredentials,
        parse: (body) {
          final map = asMap(body);
          return asList(
            map['credentials'] ?? map['items'] ?? map['data'],
            BiometricCredential.fromJson,
          );
        },
      );

  /// Revoking a device is the half of biometric sign-in that needs no
  /// keystore work — see the repository docs for what enrolment still needs.
  Future<ApiResult<void>> revokeBiometricCredential({
    required int id,
    String? reason,
  }) =>
      _client.delete<void>(
        ApiPaths.biometricCredential(id),
        body: {'reason': ?reason},
      );

  // ------------------------------------------------------------- web bridge

  /// A short-lived signed URL for a screen the native app does not implement.
  /// Refresh it before [WebBridgeLink.refreshAfter] elapses.
  Future<ApiResult<WebBridgeLink>> webBridge({
    required String target,
    int? organizationId,
    String? workspace,
    String? lang,
  }) =>
      _client.post<WebBridgeLink>(
        ApiPaths.webBridge,
        body: {
          'target': target,
          'organization_id': ?organizationId,
          'workspace': ?workspace,
          'lang': ?lang,
        },
        parse: (body) => WebBridgeLink.fromJson(asMap(body)),
      );

  static String get platform => Platform.isIOS ? 'ios' : 'android';

  static String _day(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class TransferLineInput {
  final int skuId;
  final double requestedQty;

  const TransferLineInput({required this.skuId, required this.requestedQty});

  Map<String, dynamic> toJson() => {'sku_id': skuId, 'requested_qty': requestedQty};
}
