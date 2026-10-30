import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/workspace_shell.dart';
import '../../../features/shared/auth/presentation/views/login_view.dart';
import '../../../features/shared/auth/presentation/views/password_reset_view.dart';
import '../../../features/shared/auth/presentation/views/verify_email_view.dart';
import '../../../data/models/auth/auth_user.dart';
import '../../../features/shared/auth/presentation/views/register_owner_view.dart';
import '../../../features/shared/advanced/views/account_views.dart';
import '../../../features/shared/advanced/views/contracts_views.dart';
import '../../../features/shared/advanced/views/finance_views.dart';
import '../../../features/shared/advanced/views/ratings_view.dart';
import '../../../features/shared/advanced/views/shelf_views.dart';
import '../../../data/models/compliance/legal.dart';
import '../../../features/shared/compliance/compliance_widgets.dart';
import '../../../features/shared/compliance/terms/terms_views.dart';
import '../../../features/shared/compliance/views/account_legal_views.dart';
import '../../../features/shared/compliance/views/agreement_views.dart';
import '../../../features/shared/compliance/views/document_views.dart';
import '../../../features/shared/compliance/views/evidence_views.dart';
import '../../../features/shared/compliance/views/marketer_views.dart';
import '../../../features/shared/compliance/views/quotation_views.dart';
import '../../../features/shared/notifications/presentation/views/notifications_view.dart';
import '../../../features/shop/views/shop_browse_views.dart';
import '../../../features/shop/views/shop_cart_views.dart';
import '../../../features/shop/views/shop_chat_views.dart';
import '../../../features/shop/views/shop_product_view.dart';
import '../../../features/trader/catalog/views/catalog_views.dart';
import '../../../features/trader/drafts/views/draft_editor_view.dart';
import '../../../features/trader/drafts/views/new_order_view.dart';
import '../../../features/shared/advanced/views/approvals_view.dart';
import '../../../features/shared/advanced/views/consignment_view.dart';
import '../../../features/shared/organization/public_profile_view.dart';
import '../../../features/shared/organization/team_view.dart';
import '../../../features/shared/orders/views/order_detail_view.dart';
import '../../../features/trader/orders/views/orders_views.dart';
import '../../../features/trader/payables/views/payables_views.dart';
import '../../../features/trader/receipts/views/goods_receipt_form_view.dart';
import '../../../features/trader/shipments/views/shipments_views.dart';
import '../../../features/trader/suppliers/views/supplier_detail_view.dart';
import '../../../features/supplier/views/invoicing_views.dart';
import '../../../features/supplier/views/money_views.dart';
import '../../../features/supplier/views/orders_inbox_view.dart';
import '../../../features/supplier/views/outbound_views.dart';
import '../../../features/supplier/views/pricing_views.dart';
import '../../../features/supplier/views/relationships_views.dart';
import '../../../features/supplier/views/supplier_catalog_views.dart';
import '../../../features/supplier/views/traders_directory_view.dart';
import '../../../features/supplier/views/delivery_note_form_view.dart';
import '../../../features/supplier/views/delivery_contracts_view.dart';
import '../../../features/supplier/views/internal_transfers_views.dart';
import '../../../features/supplier/views/van_sales_views.dart';
import '../../../features/trader/suppliers/views/suppliers_view.dart';
import '../../../features/shared/onboarding/presentation/views/bank_accounts_view.dart';
import '../../../features/shared/onboarding/presentation/views/branches_view.dart';
import '../../../features/shared/onboarding/presentation/views/documents_view.dart';
import '../../../features/shared/onboarding/presentation/views/onboarding_wizard_view.dart';
import '../../../features/shared/onboarding/presentation/views/organization_details_view.dart';
import '../../../data/models/onboarding/onboarding_bootstrap.dart';
import '../../../features/shared/onboarding/presentation/views/profile_form_view.dart';
import '../../../features/splash/presentation/views/splash_view.dart';
import '../../session/session_cubit.dart';
import '../../session/session_state.dart';
import '../../workspace/workspace.dart';
import '../../workspace/workspace_cubit.dart';
import '../services/remote_services/service_locator.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// Confirm a new account's email. Needs its challenge as `extra`.
  static const verifyEmail = '/verify-email';
  static const notifications = '/notifications';

  // ------------------------------------------------------- shared advanced
  static const contracts = '/contracts';
  static const shelf = '/shelf';
  static const shelfAdjustments = '/shelf/adjustments';
  static const settlements = '/settlements';
  static const wallet = '/wallet';
  static const subscription = '/subscription';
  static const accountSettings = '/account';

  static String contractDetailFor(int id) => '$contracts/$id';

  /// «صندوق الموافقات» — pending contract and purchase-order approvals.
  static const approvals = '/approvals';

  /// «التوريد الأماني»: consignment shipments, sales reports, stock counts.
  static const consignment = '/consignment';

  /// «الفريق والصلاحيات» and the public «بروفايل».
  static const team = '/team';
  static const publicProfile = '/public-profile';

  // ------------------------------------------------ compliance: legal
  static const terms = '/terms';
  static const termsGate = '/terms/accept';
  static const termsHistory = '/terms/history';

  static String termsDocumentFor(int termsVersionId) => '/terms/doc/$termsVersionId';

  // ------------------------------------------- compliance documents (v1.5)
  // Shared by both shells: each document says which side is looking
  // (`my_role`) and what that side may do (`can_*`).
  static const compliance = '/compliance';
  static const relationshipRequests = '$compliance/relationship-requests';
  static const quotations = '$compliance/quotations';
  static const quotationNew = '$compliance/quotations/new';
  static const returnNotes = '$compliance/returns';
  static const custodyLedger = '$compliance/custody';
  static const goodsReceipts = '$compliance/receipts';
  static const latePaymentNotices = '$compliance/late-notices';
  static const disputePacks = '$compliance/dispute-packs';
  static const marketerHome = '$compliance/marketer';
  static const supplierMarketers = '$compliance/marketers';
  static const serviceInvoices = '$compliance/service-invoices';
  static const complaints = '$compliance/complaints';
  static const complaintNew = '$compliance/complaints/new';
  static const signatories = '$compliance/signatories';

  static String relationshipRequestFor(int id) => '$relationshipRequests/$id';

  static String agreementsFor(AgreementKind kind) => '$compliance/agreements/${kind.path}';

  static String agreementFor(AgreementKind kind, int id) => '${agreementsFor(kind)}/$id';

  static String quotationFor(int id) => '$quotations/$id';

  static String returnNoteFor(int id) => '$returnNotes/$id';

  static String returnNoteNewFor(int purchaseOrderId, {int? invoiceId}) =>
      '$returnNotes/new?po=$purchaseOrderId${invoiceId == null ? '' : '&invoice=$invoiceId'}';

  static String goodsReceiptDetailFor(int id) => '$goodsReceipts/$id';

  static String invoiceComplianceFor(int id) => '$compliance/invoices/$id';

  static String latePaymentNoticeFor(int id) => '$latePaymentNotices/$id';

  static String disputePackFor(int id) => '$disputePacks/$id';

  static String complaintFor(int id) => '$complaints/$id';

  static String shelfCountFor(int contractId, {int branchId = 0}) =>
      '$shelf/$contractId/count?branch=$branchId';

  static String ratingsFor(int relationshipId) => '/ratings/$relationshipId';

  // ------------------------------------------------------- v1 marketplace
  // The shop belongs to neither workspace: it is the account's own buying
  // and selling surface, reached from the More tab on both shells.
  static const shop = '/shop';
  static const shopSearch = '/shop/search';
  static const shopCategories = '/shop/categories';
  static const shopFavorites = '/shop/favorites';
  static const shopCart = '/shop/cart';
  static const shopOrders = '/shop/orders';
  static const shopChat = '/shop/chat';

  static String shopFeedFor(String type) => '/shop/feed/$type';

  static String shopProductFor(int productId) => '/shop/products/$productId';

  static String shopCategoryFor(int categoryId) => '/shop/categories/$categoryId';

  static String shopOrderFor(int orderId) => '/shop/orders/$orderId';

  static String shopChatWith(int userId) => '/shop/chat/$userId';

  static const onboarding = '/onboarding';
  static const onboardingOrganization = '/onboarding/organization';
  static const onboardingBranches = '/onboarding/branches';
  static const onboardingBankAccounts = '/onboarding/bank-accounts';
  static const onboardingDocuments = '/onboarding/documents';

  /// One profile per workspace — `/onboarding/profile/trader`.
  static String onboardingProfileFor(Workspace workspace) =>
      '/onboarding/profile/${workspace.api}';
  static const traderHome = '/trader';
  static const supplierHome = '/supplier';

  /// The home path for a workspace. Every trader screen lives under
  /// `/trader` and every supplier screen under `/supplier`, which is what
  /// makes a wrong-workspace call unreachable by navigation.
  static String homeFor(Workspace workspace) =>
      workspace == Workspace.trader ? traderHome : supplierHome;

  // ------------------------------------------------------------ trader track
  static const traderSuppliers = '$traderHome/suppliers';
  static const traderCatalog = '$traderHome/catalog';
  static const traderOrders = '$traderHome/orders';
  static const traderShipments = '$traderHome/shipments';
  static const traderInvoices = '$traderHome/invoices';

  static String supplierDetailFor(int id) => '$traderSuppliers/$id';

  /// The trader's «العلاقات التجارية».
  static const traderRelationships = '$traderHome/relationships';

  static String productDetailFor(int id) => '$traderCatalog/products/$id';

  static String draftForSupplier(int supplierOrganizationId, {int? relationshipId}) =>
      '$traderHome/drafts/new?supplier=$supplierOrganizationId'
      '${relationshipId == null ? '' : '&relationship=$relationshipId'}';

  static String draftFor(int draftId, int supplierOrganizationId, {int? relationshipId}) =>
      '$traderHome/drafts/$draftId?supplier=$supplierOrganizationId'
      '${relationshipId == null ? '' : '&relationship=$relationshipId'}';

  /// «أمر شراء جديد» — the guided order; `supplier` preselects one.
  static String newOrder({int? supplierOrganizationId}) =>
      '$traderHome/order-entry${supplierOrganizationId == null ? '' : '?supplier=$supplierOrganizationId'}';

  static String orderDetailFor(int id) => '$traderOrders/$id';

  static String shipmentDetailFor(int id) => '$traderShipments/$id';

  static String goodsReceiptFor(int deliveryNoteId) =>
      '$traderHome/receipts/new?delivery_note=$deliveryNoteId';

  static String invoiceDetailFor(int id, {int? paymentNoticeId}) =>
      paymentNoticeId == null ? '$traderInvoices/$id' : '$traderInvoices/$id?notice=$paymentNoticeId';


  // ---------------------------------------------------------- supplier track
  static const supplierOrders = '$supplierHome/orders';
  static const supplierOutbound = '$supplierHome/outbound';
  static const supplierInvoices = '$supplierHome/invoices';
  static const supplierIssueInvoice = '$supplierHome/invoices/issue';
  static const supplierCollections = '$supplierHome/collections';
  static const supplierReturns = '$supplierHome/returns';
  static const supplierCatalog = '$supplierHome/catalog';
  static const supplierPricing = '$supplierHome/pricing';
  static const supplierRelationships = '$supplierHome/relationships';

  /// «دليل التجار»: where a supplier starts a relationship.
  static const supplierTraders = '$supplierHome/traders';

  static String supplierOrderDetailFor(int id) => '$supplierOrders/$id';

  /// «إنشاء إذن تسليم» for one order.
  static String deliveryNoteNewFor(int orderId) => '$supplierOrders/$orderId/deliver';

  static String outboundDetailFor(int id) => '$supplierOutbound/$id';

  static String skuRulesFor(int productId) => '$supplierCatalog/$productId';

  static String creditFor(int relationshipId) =>
      '$supplierRelationships/$relationshipId/credit';

  // Catalog & stock (web «الكتالوج والمخزون»): the fleet side of supplying.
  /// «البيع المتجول».
  static const vanSales = '$supplierHome/van_sales';
  static const vanSalesNew = '$vanSales/new';

  /// «عقود التوصيل».
  static const deliveryContracts = '$supplierHome/delivery_contracts';

  /// «النقل الداخلي».
  static const internalTransfers = '$supplierHome/internal_transfers';
  static const internalTransfersNew = '$internalTransfers/new';

  static String vanTripFor(int id) => '$vanSales/$id';

  static String internalTransferFor(int id) => '$internalTransfers/$id';
}

abstract class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _SessionListenable(),
    redirect: _redirect,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashView()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterOwnerView()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, _) => const PasswordResetView()),
      GoRoute(
        path: AppRoutes.verifyEmail,
        // Only ever opened with its challenge; a cold link has no email to
        // confirm, and logging in mails a fresh code anyway.
        redirect: (_, state) =>
            state.extra is EmailVerificationChallenge ? null : AppRoutes.login,
        builder: (_, state) =>
            VerifyEmailView(challenge: state.extra! as EmailVerificationChallenge),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingWizardView(),
        routes: [
          GoRoute(path: 'organization', builder: (_, _) => const OrganizationDetailsView()),
          GoRoute(
            path: 'profile/:type',
            builder: (_, state) => ProfileFormView(
              workspace: Workspace.tryParse(state.pathParameters['type']) ?? Workspace.trader,
              // The wizard hands over the profile it already holds; a deep
              // link arrives with nothing and the editor fetches instead.
              known: state.extra is OnboardingProfile
                  ? state.extra! as OnboardingProfile
                  : null,
            ),
          ),
          GoRoute(path: 'branches', builder: (_, _) => const BranchesView()),
          GoRoute(path: 'bank-accounts', builder: (_, _) => const BankAccountsView()),
          GoRoute(path: 'documents', builder: (_, _) => const DocumentsView()),
        ],
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsView(showAppBar: true),
      ),
      GoRoute(
        path: AppRoutes.contracts,
        builder: (_, _) => const ContractsView(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => ContractDetailView(contractId: _idOf(state, 'id')),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.shelf,
        builder: (_, _) => const ShelfPanelView(),
        routes: [
          GoRoute(path: 'adjustments', builder: (_, _) => const ShelfAdjustmentsView()),
          GoRoute(
            path: ':id/count',
            builder: (_, state) => ShelfCountView(
              contractId: _idOf(state, 'id'),
              branchId: _queryId(state, 'branch') ?? 0,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.terms,
        // A page, not a redirect: go_router runs a parent's redirect for every
        // child too, with only the parent's own path — a redirect here sent
        // `/terms/doc/1` and `/terms/accept` back to the history list.
        builder: (_, _) => const TermsHistoryView(),
        routes: [
          GoRoute(path: 'accept', builder: (_, _) => const TermsGateView()),
          GoRoute(path: 'history', builder: (_, _) => const TermsHistoryView()),
          GoRoute(
            path: 'doc/:id',
            builder: (_, state) => TermsDocumentView(termsVersionId: _idOf(state, 'id')),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.compliance,
        // A page, not a redirect — see `/terms` above: a parent redirect sent
        // every compliance screen to the complaints list.
        builder: (_, _) => const ComplaintsView(),
        routes: [
          GoRoute(
            path: 'relationship-requests',
            builder: (_, _) => const RelationshipRequestsView(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => RelationshipRequestDetailView(requestId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(
            path: 'agreements/:kind',
            builder: (_, s) => AgreementsView(kind: AgreementKind.parse(s.pathParameters['kind'])),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => AgreementDetailView(
                  kind: AgreementKind.parse(s.pathParameters['kind']),
                  documentId: _idOf(s, 'id'),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'quotations',
            builder: (_, _) => const QuotationsView(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const QuotationFormView()),
              GoRoute(path: ':id', builder: (_, s) => QuotationDetailView(quotationId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(
            path: 'returns',
            builder: (_, _) => const ReturnNotesView(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, s) => ReturnNoteFormView(
                  purchaseOrderId: _queryId(s, 'po') ?? 0,
                  invoiceId: _queryId(s, 'invoice'),
                ),
              ),
              GoRoute(path: ':id', builder: (_, s) => ReturnNoteDetailView(returnNoteId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(path: 'custody', builder: (_, _) => const CustodyLedgerView()),
          GoRoute(
            path: 'receipts',
            builder: (_, _) => const GoodsReceiptsView(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => GoodsReceiptDetailView(receiptId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(path: 'invoices/:id', builder: (_, s) => InvoiceComplianceView(invoiceId: _idOf(s, 'id'))),
          GoRoute(
            path: 'late-notices',
            builder: (_, _) => const LatePaymentNoticesView(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => LatePaymentNoticeDetailView(noticeId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(
            path: 'dispute-packs',
            builder: (_, _) => const DisputePacksView(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => DisputePackDetailView(packId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(path: 'marketer', builder: (_, _) => const MarketerHomeView()),
          GoRoute(path: 'marketers', builder: (_, _) => const SupplierMarketersView()),
          GoRoute(path: 'service-invoices', builder: (_, _) => const ServiceInvoicesView()),
          GoRoute(
            path: 'complaints',
            builder: (_, _) => const ComplaintsView(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, s) => ComplaintFormView(
                  categories: s.extra is List<ComplaintCategory> ? s.extra! as List<ComplaintCategory> : const [],
                ),
              ),
              GoRoute(path: ':id', builder: (_, s) => ComplaintDetailView(ticketId: _idOf(s, 'id'))),
            ],
          ),
          GoRoute(path: 'signatories', builder: (_, _) => const SignatoriesView()),
        ],
      ),
      GoRoute(path: AppRoutes.settlements, builder: (_, _) => const SettlementsView()),
      GoRoute(path: AppRoutes.approvals, builder: (_, _) => const ApprovalsView()),
      GoRoute(path: AppRoutes.consignment, builder: (_, _) => const ConsignmentView()),
      GoRoute(path: AppRoutes.team, builder: (_, _) => const TeamView()),
      GoRoute(path: AppRoutes.publicProfile, builder: (_, _) => const PublicProfileView()),
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const WalletView()),
      GoRoute(path: AppRoutes.subscription, builder: (_, _) => const SubscriptionView()),
      GoRoute(
        path: AppRoutes.accountSettings,
        builder: (_, _) => const AccountSettingsView(),
      ),
      GoRoute(
        path: '/ratings/:id',
        builder: (_, state) => RatingsView(relationshipId: _idOf(state, 'id')),
      ),
      GoRoute(
        path: AppRoutes.shop,
        builder: (_, _) => const ShopHomeView(),
        routes: [
          GoRoute(
            path: 'search',
            builder: (_, _) => ProductListView(
              title: 'shop.search'.tr(),
              searchable: true,
            ),
          ),
          GoRoute(
            path: 'feed/:type',
            builder: (_, state) => ProductListView(
              title: 'shop.feed.${state.pathParameters['type']}'.tr(),
              feedType: state.pathParameters['type'],
            ),
          ),
          GoRoute(
            path: 'categories',
            builder: (_, _) => const ShopCategoriesView(),
            routes: [
              GoRoute(
                path: ':id',
                // The category name travels as `extra` so the screen has a
                // title without a second fetch.
                builder: (_, state) => ProductListView(
                  title: state.extra is String
                      ? state.extra! as String
                      : 'shop.categories'.tr(),
                  categoryId: _idOf(state, 'id'),
                ),
              ),
            ],
          ),
          GoRoute(path: 'favorites', builder: (_, _) => const FavoritesView()),
          GoRoute(path: 'cart', builder: (_, _) => const ShopCartView()),
          GoRoute(
            path: 'products/:id',
            builder: (_, state) => ShopProductView(productId: _idOf(state, 'id')),
          ),
          GoRoute(
            path: 'orders',
            builder: (_, _) => const ShopOrdersView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ShopOrderDetailView(orderId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'chat',
            builder: (_, _) => const ShopChatListView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => ShopChatRoomView(
                  withId: _idOf(state, 'id'),
                  title: state.extra is String ? state.extra! as String : null,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.traderHome,
        builder: (_, _) => const TraderShell(),
        routes: [
          GoRoute(
            path: 'relationships',
            builder: (_, _) => const RelationshipsView(side: Workspace.trader),
          ),
          GoRoute(
            path: 'suppliers',
            builder: (_, _) => const SuppliersView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => SupplierDetailView(
                  supplierOrganizationId: _idOf(state, 'id'),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'catalog',
            builder: (_, _) => const ProductsView(),
            routes: [
              GoRoute(
                path: 'products/:id',
                builder: (_, state) => ProductDetailView(productId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'order-entry',
            builder: (_, state) => NewOrderView(supplierOrganizationId: _queryId(state, 'supplier')),
          ),
          GoRoute(
            path: 'drafts/new',
            builder: (_, state) => DraftEditorView(
              supplierOrganizationId: _queryId(state, 'supplier') ?? 0,
              relationshipId: _queryId(state, 'relationship'),
            ),
          ),
          GoRoute(
            path: 'drafts/:id',
            builder: (_, state) => DraftEditorView(
              draftId: _idOf(state, 'id'),
              supplierOrganizationId: _queryId(state, 'supplier') ?? 0,
              relationshipId: _queryId(state, 'relationship'),
            ),
          ),
          GoRoute(
            path: 'orders',
            builder: (_, _) => const OrdersView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailView(orderId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'shipments',
            builder: (_, _) => const ShipmentsView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ShipmentTrackingView(deliveryNoteId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'receipts/new',
            builder: (_, state) => GoodsReceiptFormView(
              deliveryNoteId: _queryId(state, 'delivery_note') ?? 0,
            ),
          ),
          GoRoute(
            path: 'invoices',
            builder: (_, _) => const InvoicesView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => InvoiceDetailView(
                  invoiceId: _idOf(state, 'id'),
                  highlightNoticeId: int.tryParse(state.uri.queryParameters['notice'] ?? ''),
                ),
              ),
            ],
          ),
          // The legacy `post_invoice_returns` form, retired: a return is a
          // return note now (accepted with a code, credit note follows).
          GoRoute(path: 'returns/new', redirect: (_, _) => AppRoutes.returnNotes),
        ],
      ),
      GoRoute(
        path: AppRoutes.supplierHome,
        builder: (_, _) => const SupplierShell(),
        routes: [
          GoRoute(
            path: 'orders',
            builder: (_, _) => const OrdersInboxView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailView(orderId: _idOf(state, 'id')),
                routes: [
                  GoRoute(
                    path: 'deliver',
                    builder: (_, state) => DeliveryNoteFormView(orderId: _idOf(state, 'id')),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'outbound',
            builder: (_, _) => const OutboundShipmentsView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    OutboundDetailView(deliveryNoteId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'invoices',
            builder: (_, _) => const SupplierInvoicesView(),
            routes: [
              GoRoute(path: 'issue', builder: (_, _) => const IssueInvoiceView()),
            ],
          ),
          GoRoute(
            path: 'collections',
            builder: (_, _) => const CollectionsInboxView(),
          ),
          // The legacy returns inbox approved without a code; retired.
          GoRoute(path: 'returns', redirect: (_, _) => AppRoutes.returnNotes),
          GoRoute(
            path: 'catalog',
            builder: (_, _) => const SupplierCatalogView(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => SkuRulesView(productId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(path: 'pricing', builder: (_, _) => const PriceListsView()),
          GoRoute(
            path: 'traders',
            builder: (_, _) => const TradersDirectoryView(),
          ),
          // `new` before `:id`, or it would be read as an id.
          GoRoute(
            path: 'van_sales',
            builder: (_, _) => const VanTripsView(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const VanLoadSheetView()),
              GoRoute(
                path: ':id',
                builder: (_, state) => VanTripDetailView(tripId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'delivery_contracts',
            builder: (_, _) => const DeliveryContractsView(),
          ),
          GoRoute(
            path: 'internal_transfers',
            builder: (_, _) => const InternalTransfersView(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const InternalTransferFormView()),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    InternalTransferDetailView(transferId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'relationships',
            builder: (_, _) => const RelationshipsView(),
            routes: [
              GoRoute(
                path: ':id/credit',
                builder: (_, state) => CreditView(relationshipId: _idOf(state, 'id')),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// Everything routes off the session and the active workspace. No screen
  /// decides where the user goes next.
  static String? _redirect(BuildContext context, GoRouterState state) {
    final session = getIt<SessionCubit>().state;
    final workspace = getIt<WorkspaceCubit>().state;
    final location = state.matchedLocation;

    const publicRoutes = {
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.verifyEmail,
    };

    switch (session.status) {
      case SessionStatus.unknown:
      case SessionStatus.loading:
        // Sign-up and password reset own their own progress; bouncing them
        // back to the splash would drop a half-filled form.
        return publicRoutes.contains(location) ? null : AppRoutes.splash;

      case SessionStatus.error:
        return location == AppRoutes.splash ? null : AppRoutes.splash;

      case SessionStatus.unauthenticated:
        return publicRoutes.contains(location) ? null : AppRoutes.login;

      case SessionStatus.authenticated:
        // The terms gate can fire from the onboarding wizard too (its writes
        // are gated like any other), so it is reachable before a workspace.
        if (location.startsWith(AppRoutes.terms)) return null;
        final inOnboarding = location.startsWith(AppRoutes.onboarding);
        // An unfinished organization is *held* in the wizard.
        if (session.needsOnboarding || workspace == null) {
          return inOnboarding ? null : AppRoutes.onboarding;
        }
        // A finished one may still walk back into it on purpose — to edit a
        // branch, or to request the second workspace.
        if (inOnboarding || _isSharedRoute(location)) return null;
        // Every screen of a workspace lives under its home path, so this one
        // check keeps the other side's routes unreachable.
        final home = AppRoutes.homeFor(workspace.active);
        return location.startsWith(home) ? null : home;
    }
  }
}

/// Screens that belong to neither workspace: the account-level and
/// cross-cutting ones, reachable from both shells.
bool _isSharedRoute(String location) =>
    location == AppRoutes.notifications ||
    location.startsWith(AppRoutes.compliance) ||
    location.startsWith(AppRoutes.contracts) ||
    location.startsWith(AppRoutes.approvals) ||
    location.startsWith(AppRoutes.consignment) ||
    location.startsWith(AppRoutes.team) ||
    location.startsWith(AppRoutes.publicProfile) ||
    location.startsWith(AppRoutes.shelf) ||
    location.startsWith(AppRoutes.settlements) ||
    location.startsWith(AppRoutes.wallet) ||
    location.startsWith(AppRoutes.subscription) ||
    location.startsWith(AppRoutes.accountSettings) ||
    location.startsWith(AppRoutes.shop) ||
    location.startsWith('/ratings');

/// Path parameters are always digits (the router constrains them), but a
/// malformed deep link should land somewhere harmless rather than throw.
int _idOf(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '') ?? 0;

int? _queryId(GoRouterState state, String name) =>
    int.tryParse(state.uri.queryParameters[name] ?? '');

/// Bridges the two cubits the redirect reads into a `Listenable` go_router can
/// watch. A workspace switch is a route change, so it has to be in here too.
class _SessionListenable extends ChangeNotifier {
  final List<StreamSubscription<Object?>> _subscriptions = [];

  _SessionListenable() {
    _subscriptions
      ..add(getIt<SessionCubit>().stream.listen((_) => notifyListeners()))
      ..add(getIt<WorkspaceCubit>().stream.listen((_) => notifyListeners()));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
