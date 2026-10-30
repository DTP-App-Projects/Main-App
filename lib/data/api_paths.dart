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

  /// Sign-up email confirmation: a 6-digit code, valid 10 minutes.
  static const verifyEmail = '/auth/email/verify';
  static const resendEmailCode = '/auth/email/resend';
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
  static const organizationLogo = '/v2/organization/logo';
  static const organizationCover = '/v2/organization/cover';
  static const organizationBio = '/v2/organization/bio';
  static const organizationPosts = '/v2/organization/posts';
  static String organizationPost(int id) => '/v2/organization/posts/$id';
  static String organizationBranch(int id) => '/v2/organization/branches/$id';

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

  /// The trader's window to correct received quantities after a handoff.
  /// These three answer errors as `{status, message: <code>}`, not `{msg}`.
  static String deliveryNoteEditWindow(int id) => '/v2/delivery_notes/$id/edit_window';

  static String deliveryNoteEditWindowAdjust(int id) =>
      '/v2/delivery_notes/$id/edit_window/adjust';

  static String deliveryNoteEditWindowClose(int id) => '/v2/delivery_notes/$id/edit_window/close';

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

  /// «إشعار سداد»: the trader's "I paid", reviewed by the supplier — the
  /// website's flow. Confirming one creates the collection receipt.
  static const paymentNotices = '/v2/payment_notices';

  static String paymentNotice(int id) => '/v2/payment_notices/$id';

  static String paymentNoticeStatus(int id) => '/v2/payment_notices/$id/status';

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

  /// Active trader organizations with this supplier's relationship status —
  /// the app's «دليل التجار». `{items}`; `search`, `limit`.
  static const lookupTraders = '/v2/lookups/traders';

  /// Every read-only picker lives under the same prefix and answers
  /// `{items}` — see [Lookup] for the names.
  static String lookup(String name) => '/v2/lookups/$name';

  // ------------------------------------------------- v2 compliance (v1.5)
  // Contract-compliance release: `docs/compliance-implementation.md`.

  /// Level-2 one-time code. Throttled to 6/min.
  static const acceptanceChallenges = '/v2/acceptance_challenges';

  // Stream A: terms, complaints, signatories.
  static const termsStatus = '/v2/terms_status';
  static const termsVersions = '/v2/terms_versions';
  static const termsAcceptances = '/v2/terms_acceptances';
  static const complaintTickets = '/v2/complaint_tickets';
  static const signatories = '/v2/signatories';

  static String termsVersion(int id) => '/v2/terms_versions/$id';

  static String complaintTicket(int id) => '/v2/complaint_tickets/$id';

  static String complaintMessages(int id) => '/v2/complaint_tickets/$id/messages';

  static String complaintStatus(int id) => '/v2/complaint_tickets/$id/status';

  static String complaintAttachment(int id) => '/v2/complaint_tickets/$id/attachment';

  static String signatory(int membershipId) => '/v2/signatories/$membershipId';

  // Stream B: relationship request → framework → quotation → PO.
  static const relationshipRequests = '/v2/relationship_requests';
  static const frameworkAgreements = '/v2/framework_agreements';
  static const addenda = '/v2/addenda';
  static const quotations = '/v2/quotations';
  static const creditAcknowledgments = '/v2/credit_acknowledgments';

  static String relationshipRequest(int id) => '/v2/relationship_requests/$id';

  static String relationshipRequestStatus(int id) => '/v2/relationship_requests/$id/status';

  static String relationshipRequestCreditTerms(int id) =>
      '/v2/relationship_requests/$id/credit_terms';

  static String frameworkAgreement(int id) => '/v2/framework_agreements/$id';

  static String frameworkAgreementStatus(int id) => '/v2/framework_agreements/$id/status';

  static String addendum(int id) => '/v2/addenda/$id';

  static String addendumStatus(int id) => '/v2/addenda/$id/status';

  static String quotation(int id) => '/v2/quotations/$id';

  static String quotationStatus(int id) => '/v2/quotations/$id/status';

  static String creditAcknowledgment(int id) => '/v2/credit_acknowledgments/$id';

  static String creditAcknowledgmentStatus(int id) => '/v2/credit_acknowledgments/$id/status';

  // Stream C: receipt → invoice → returns → consignment.
  static const returnNotes = '/v2/return_notes';
  static const custodyLedger = '/v2/consignment/custody_ledger';

  static String goodsReceiptConfirmation(int id) => '/v2/goods_receipts/$id/confirmation';

  static String goodsReceiptPdf(int id) => '/v2/goods_receipts/$id/pdf';

  static String invoicePdf(int id) => '/v2/invoices/$id/pdf';

  static String creditNotePdf(int id) => '/v2/credit_notes/$id/pdf';

  static String returnNote(int id) => '/v2/return_notes/$id';

  static String returnNoteStatus(int id) => '/v2/return_notes/$id/status';

  static String returnNotePdf(int id) => '/v2/return_notes/$id/pdf';

  static String returnableQuantities(int purchaseOrderId) =>
      '/v2/purchase_orders/$purchaseOrderId/returnable_quantities';

  static String consignmentTerms(int purchaseOrderId) =>
      '/v2/purchase_orders/$purchaseOrderId/consignment_terms';

  static String consignmentSaleInvoices(int contractId) =>
      '/v2/contracts/$contractId/consignment_sale_invoices';

  // Stream D: late payment, dispute pack, marketer, Nafith, service invoices.
  static const latePaymentNotices = '/v2/late_payment_notices';
  static const disputePacks = '/v2/dispute_packs';
  static const marketer = '/v2/marketer';
  static const marketerOwnAssignments = '/v2/marketer/assignments';
  static const marketerOwnCommissions = '/v2/marketer/commissions';
  static const marketerAssignments = '/v2/marketer_assignments';
  static const marketerCommissions = '/v2/marketer_commissions';
  static const serviceInvoices = '/v2/service_invoices';

  static String latePaymentNotice(int id) => '/v2/late_payment_notices/$id';

  static String invoiceLatePayment(int invoiceId) => '/v2/invoices/$invoiceId/late_payment';

  static String invoiceLatePaymentNotices(int invoiceId) =>
      '/v2/invoices/$invoiceId/late_payment_notices';

  static String relationshipSupplyStatus(int relationshipId) =>
      '/v2/relationships/$relationshipId/supply/status';

  static String disputePack(int id) => '/v2/dispute_packs/$id';

  static String disputePackFile(int id) => '/v2/dispute_packs/$id/file';

  static String marketerOwnAssignmentStatus(int id) => '/v2/marketer/assignments/$id/status';

  static String marketerAssignmentStatus(int id) => '/v2/marketer_assignments/$id/status';

  static String marketerAssignmentPurchaseOrders(int id) =>
      '/v2/marketer_assignments/$id/purchase_orders';

  static String invoicePromissoryNotes(int invoiceId) =>
      '/v2/invoices/$invoiceId/promissory_notes';

  static String serviceInvoice(int id) => '/v2/service_invoices/$id';

  // -------------------------------------------------------- v2 document flow

  /// The chain around one document (PO → shipment → receipt → invoice →
  /// payments). `404 document_flow_not_found` for an unknown document.
  static String documentFlow(String entityType, int entityId) =>
      '/v2/document_flow/$entityType/$entityId';

  // ------------------------------------------------------ v2 fleet (supplier)
  // Van sales, delivery contracts and internal transfers all want
  // `organization_id` themselves — in the query on GET, in the body otherwise.

  /// «البيع المتجول»: load sheets on a driver's van.
  static const vanTrips = '/v2/fleet/van_trips';
  static const vanTripFormOptions = '/v2/fleet/van_trips/form_options';

  static String vanTrip(int id) => '/v2/fleet/van_trips/$id';

  /// The light poll while a van is on the road.
  static String vanTripFigures(int id) => '/v2/fleet/van_trips/$id/figures';

  static String vanTripCancel(int id) => '/v2/fleet/van_trips/$id/cancel';

  static String vanTripReconcile(int id) => '/v2/fleet/van_trips/$id/reconcile';

  /// «عقود التوصيل»: the supplier's contracts with delivery companies.
  static const fleetContracts = '/v2/fleet/contracts';

  static String fleetContractEnd(int id) => '/v2/fleet/contracts/$id/end';

  /// «النقل الداخلي»: stock between the organization's own branches.
  /// (`internalTransfers`, `internalTransfer` and `internalTransferStatus`
  /// sit with the settlements above.)
  static const internalTransferFormOptions = '/v2/internal_transfers/form_options';

  static String internalTransferLines(int id) => '/v2/internal_transfers/$id/lines';

  static String internalTransferLine(int id, int lineId) =>
      '/v2/internal_transfers/$id/lines/$lineId';

  // ------------------------------------------------------------- v2 uploads
  static const uploads = '/v2/uploads';
}
