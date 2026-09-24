/// Every path the app calls, relative to `Env.apiBase` (`https://host/api`).
///
/// Two surfaces live here: v1 (`/auth/...`, the marketplace) and v2
/// (`/v2/...`, the B2B platform). Login only exists on v1, so every session
/// starts there and then calls `/v2/bootstrap`.
class ApiPaths {
  ApiPaths._();

  // ---------------------------------------------------------------- v1 auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const deviceToken = '/auth/device_token';
  static const profile = '/auth/profile';
  static const password = '/auth/password';
  static const forgotPassword = '/auth/password/forgot';
  static const verifyResetCode = '/auth/password/verify_code';
  static const resetPassword = '/auth/password/reset';

  // --------------------------------------------------------- v1 marketplace
  static const shopHome = '/home';
  static const shopSearch = '/search';
  static const shopCategories = '/categories';
  static const shopProducts = '/products';
  static const shopFavorites = '/favorites';
  static const shopCart = '/cart';
  static const shopCheckout = '/cart/checkout';
  static const shopOrders = '/orders';
  static const shopChat = '/chat';
  static const shopPacks = '/packs';

  static String shopCategoryProducts(int categoryId) => '/categories/$categoryId/products';

  static String shopProduct(int productId) => '/products/$productId';

  static String shopFavoriteToggle(int productId) => '/favorites/$productId/toggle';

  static String shopCartLine(int cartId) => '/cart/$cartId';

  static String shopOrder(int orderId) => '/orders/$orderId';

  static String shopOrderReceipt(int orderId) => '/orders/$orderId/receipt';

  static String shopOrderStatus(int orderId) => '/orders/$orderId/status';

  static String shopChatWith(int withId) => '/chat/$withId';

  // ------------------------------------------------------------ v1 settings
  static const countries = '/countries';
  static const support = '/support';
  static const terms = '/terms';
  static const privacy = '/privacy';

  // ---------------------------------------------------------------- v2 core
  static const bootstrap = '/v2/bootstrap';
  static const platformFlags = '/v2/platform/flags';
  static const organizations = '/v2/organizations';
  static const organization = '/v2/organization';

  // --------------------------------------------------------- v2 onboarding
  static const registerOwner = '/v2/onboarding/register_owner';
  static const onboardingBootstrap = '/v2/onboarding/bootstrap';
  static const onboardingOrganization = '/v2/onboarding/organization';
  static const onboardingProfile = '/v2/onboarding/profile';
  static const onboardingProfileSubmit = '/v2/onboarding/profile/submit';
  static const onboardingBranches = '/v2/onboarding/branches';
  static const onboardingBankAccounts = '/v2/onboarding/bank_accounts';
  static const onboardingDocuments = '/v2/onboarding/documents';
  static const requestWorkspace = '/v2/b2b/owner-console/request_workspace';
  static const submitForReview = '/v2/b2b/owner-console/submit_for_review';

  /// The owner-console mirror of the onboarding writes, with `GET` listings
  /// the onboarding namespace does not expose.
  static const consoleBranches = '/v2/b2b/owner-console/branches';
  static const consoleBankAccounts = '/v2/b2b/owner-console/bank_accounts';
  static const consoleDocuments = '/v2/b2b/owner-console/documents';
  static const consoleEmployees = '/v2/b2b/owner-console/employees';

  // ---------------------------------------------------------------- v2 push
  static const pushRegister = '/v2/push/register';
  static const pushUnregister = '/v2/push/unregister';

  // ----------------------------------------------------------------- v2 ops
  static const opsPanel = '/v2/ops/panel';
  static const opsQuickActions = '/v2/ops/quick_actions';
  static const opsDocuments = '/v2/ops/documents';
  static const actionCenter = '/v2/action_center';

  // ------------------------------------------------------------- v2 catalog
  static const catalogSuppliers = '/v2/catalog/suppliers';
  static const catalogProducts = '/v2/catalog/products';
  static const relationships = '/v2/relationships';
  static const followingSuppliers = '/v2/suppliers/following';

  static String catalogSupplier(int id) => '/v2/catalog/suppliers/$id';

  static String publicCatalog(int supplierOrgId) =>
      '/v2/suppliers/$supplierOrgId/public_catalog';

  static String followSupplier(int supplierOrgId) => '/v2/suppliers/$supplierOrgId/follow';

  static String catalogProduct(int id) => '/v2/catalog/products/$id';

  static String relationship(int id) => '/v2/relationships/$id';

  // ------------------------------------------------------------- v2 pricing
  static const pricingResolve = '/v2/pricing/resolve';
  static const paymentTerms = '/v2/pricing/payment_terms';
  static const priceLists = '/v2/pricing/price_lists';
  static const priceItems = '/v2/pricing/price_items';

  /// Supplier-only write: the SKU rules that produce the trader's order
  /// rejections.
  static String skuRules(int productId, int skuId) =>
      '/v2/catalog/products/$productId/skus/$skuId/rules';

  static String relationshipCredit(int id) => '/v2/relationships/$id/credit';

  static String relationshipStatus(int id) => '/v2/relationships/$id/status';

  // -------------------------------------------------- v2 drafts and orders
  static const purchaseDrafts = '/v2/purchase_drafts';
  static const purchaseOrders = '/v2/purchase_orders';

  static String purchaseDraft(int id) => '/v2/purchase_drafts/$id';

  static String purchaseDraftLines(int id) => '/v2/purchase_drafts/$id/lines';

  static String purchaseDraftLine(int draftId, int lineId) =>
      '/v2/purchase_drafts/$draftId/lines/$lineId';

  static String purchaseDraftSubmit(int id) => '/v2/purchase_drafts/$id/submit';

  static String purchaseOrder(int id) => '/v2/purchase_orders/$id';

  static String purchaseOrderStatus(int id) => '/v2/purchase_orders/$id/status';

  static String purchaseOrderTimeline(int id) => '/v2/purchase_orders/$id/timeline';

  static String purchaseOrderCancelRequest(int id) =>
      '/v2/purchase_orders/$id/cancel_request';

  static String purchaseOrderCancelDecision(int id) =>
      '/v2/purchase_orders/$id/cancel_request/decision';

  // ----------------------------------------------------------- v2 shipments
  static const deliveryNotes = '/v2/delivery_notes';
  static const goodsReceipts = '/v2/goods_receipts';

  static String deliveryNote(int id) => '/v2/delivery_notes/$id';

  static String deliveryNoteTracking(int id) => '/v2/delivery_notes/$id/tracking';

  static String deliveryNoteStatus(int id) => '/v2/delivery_notes/$id/status';

  static String deliveryNoteSeals(int id) => '/v2/delivery_notes/$id/seals';

  static String deliveryNoteCancel(int id) => '/v2/delivery_notes/$id/cancel';

  static String deliveryNoteReschedule(int id) => '/v2/delivery_notes/$id/reschedule';

  /// The supplier's dispatch board.
  static const supplierFleet = '/v2/delivery/tracking/supplier_fleet';

  static String goodsReceipt(int id) => '/v2/goods_receipts/$id';

  static String goodsReceiptDispute(int id) => '/v2/goods_receipts/$id/dispute';

  // --------------------------------------------------------- v2 receivables
  static const invoices = '/v2/invoices';
  static const collections = '/v2/collections';
  static const collectionsClaim = '/v2/collections/claim';
  static const postInvoiceReturns = '/v2/post_invoice_returns';
  static const invoicesProforma = '/v2/invoices/proforma';
  static const adjustments = '/v2/adjustments';

  static String dueSchedule(int id) => '/v2/invoices/due_schedules/$id';

  static String collectionStatus(int id) => '/v2/collections/$id/status';

  static String adjustmentStatus(int id) => '/v2/adjustments/$id/status';

  static String postInvoiceReturnStatus(int id) =>
      '/v2/post_invoice_returns/$id/status';

  static String invoice(int id) => '/v2/invoices/$id';

  static String postInvoiceReturn(int id) => '/v2/post_invoice_returns/$id';

  // ----------------------------------------------------------- v2 contracts
  static const contracts = '/v2/contracts';
  static const approvals = '/v2/approvals';
  static const ratings = '/v2/ratings';
  static const ratingsAggregate = '/v2/ratings/aggregate';

  static String contract(int id) => '/v2/contracts/$id';

  static String contractStatus(int id) => '/v2/contracts/$id/status';

  static String contractApproval(int contractId, int approvalId) =>
      '/v2/contracts/$contractId/approvals/$approvalId';

  static String purchaseOrderApproval(int approvalId) =>
      '/v2/approvals/purchase_orders/$approvalId';

  // --------------------------------------------------------------- v2 shelf
  static const consignmentShipments = '/v2/consignment_shipments';
  static const salesReports = '/v2/sales_reports';
  static const stockCounts = '/v2/stock_counts';
  static const shelfAdjustments = '/v2/shelf_adjustments';
  static const shelfPreviousCount = '/v2/shelf_adjustments/previous_count';
  static const shelfContracts = '/v2/shelf/contracts';

  static String consignmentShipmentStatus(int id) =>
      '/v2/consignment_shipments/$id/status';

  static String salesReportStatus(int id) => '/v2/sales_reports/$id/status';

  static String stockCountStatus(int id) => '/v2/stock_counts/$id/status';

  static String shelfAdjustmentStatus(int id) => '/v2/shelf_adjustments/$id/status';

  static String shelfContractVisits(int id) => '/v2/shelf/contracts/$id/visits';

  static String shelfVisit(int id) => '/v2/shelf/visits/$id';

  // --------------------------------------------------------- v2 settlements
  static const settlements = '/v2/settlements';
  static const internalTransfers = '/v2/internal_transfers';

  static String settlement(int id) => '/v2/settlements/$id';

  static String settlementStatus(int id) => '/v2/settlements/$id/status';

  static String settlementPayouts(int id) => '/v2/settlements/$id/payouts';

  static String payoutStatus(int id) => '/v2/payouts/$id/status';

  static String internalTransfer(int id) => '/v2/internal_transfers/$id';

  static String internalTransferStatus(int id) => '/v2/internal_transfers/$id/status';

  // ---------------------------------------------------- v2 wallet, billing
  static const wallet = '/v2/wallet';
  static const walletTransactions = '/v2/wallet/transactions';
  static const walletTopupMethods = '/v2/wallet/topup_methods';
  static const walletTopupRequests = '/v2/wallet/topup_requests';
  static const subscriptionPlans = '/v2/subscription/plans';
  static const subscriptionCurrent = '/v2/subscription/current';
  static const subscriptionBillingMode = '/v2/subscription/billing_mode';
  static const subscriptionTrial = '/v2/subscription/trial';
  static const hyperpayCheckout = '/v2/payment/hyperpay/checkout';
  static const hyperpayStatus = '/v2/payment/hyperpay/status';
  static const applePayProcess = '/v2/payment/apple_pay/process';

  // -------------------------------------------------------------- v2 account
  static const accountDeletionRequest = '/v2/account/deletion_request';
  static const biometricCredentials = '/v2/biometric/credentials';
  static const nafathInitiate = '/v2/nafath/initiate';
  static const webBridge = '/v2/mobile/web_bridge';

  static String biometricCredential(int id) => '/v2/biometric/credentials/$id';

  /// The one path segment that is **not** digits-only.
  static String nafathTransaction(String transactionId) =>
      '/v2/nafath/transactions/$transactionId';

  static String nafathCancel(String transactionId) =>
      '/v2/nafath/transactions/$transactionId/cancel';

  // -------------------------------------------------------- v2 notifications
  static const notifications = '/v2/notifications';
  static const notificationsReadAll = '/v2/notifications/read_all';

  static String notificationRead(int id) => '/v2/notifications/$id/read';

  // ------------------------------------------------------------- v2 lookups
  static const lookupBusinessSectors = '/v2/lookups/business_sectors';
  static const lookupBranches = '/v2/lookups/branches';
  static const lookupBankAccounts = '/v2/lookups/bank_accounts';

  /// Every read-only picker lives under the same prefix and answers
  /// `{items}` — see [Lookup] for the names.
  static String lookup(String name) => '/v2/lookups/$name';

  // ------------------------------------------------------------- v2 uploads
  static const uploads = '/v2/uploads';
}
