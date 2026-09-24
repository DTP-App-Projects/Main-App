import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/workspace_shell.dart';
import '../../../features/shared/auth/presentation/views/login_view.dart';
import '../../../features/shared/auth/presentation/views/password_reset_view.dart';
import '../../../features/shared/auth/presentation/views/register_owner_view.dart';
import '../../../features/shared/advanced/views/account_views.dart';
import '../../../features/shared/advanced/views/contracts_views.dart';
import '../../../features/shared/advanced/views/finance_views.dart';
import '../../../features/shared/advanced/views/ratings_view.dart';
import '../../../features/shared/advanced/views/shelf_views.dart';
import '../../../features/shared/notifications/presentation/views/notifications_view.dart';
import '../../../features/shop/views/shop_browse_views.dart';
import '../../../features/shop/views/shop_cart_views.dart';
import '../../../features/shop/views/shop_chat_views.dart';
import '../../../features/shop/views/shop_product_view.dart';
import '../../../features/trader/catalog/views/catalog_views.dart';
import '../../../features/trader/drafts/views/draft_editor_view.dart';
import '../../../features/shared/orders/views/order_detail_view.dart';
import '../../../features/trader/orders/views/orders_views.dart';
import '../../../features/trader/payables/views/payables_views.dart';
import '../../../features/trader/receipts/views/goods_receipt_form_view.dart';
import '../../../features/trader/returns/views/return_form_view.dart';
import '../../../features/trader/shipments/views/shipments_views.dart';
import '../../../features/trader/suppliers/views/supplier_detail_view.dart';
import '../../../features/supplier/views/invoicing_views.dart';
import '../../../features/supplier/views/money_views.dart';
import '../../../features/supplier/views/orders_inbox_view.dart';
import '../../../features/supplier/views/outbound_views.dart';
import '../../../features/supplier/views/pricing_views.dart';
import '../../../features/supplier/views/relationships_views.dart';
import '../../../features/supplier/views/supplier_catalog_views.dart';
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

  static String productDetailFor(int id) => '$traderCatalog/products/$id';

  static String draftForSupplier(int supplierOrganizationId, {int? relationshipId}) =>
      '$traderHome/drafts/new?supplier=$supplierOrganizationId'
      '${relationshipId == null ? '' : '&relationship=$relationshipId'}';

  static String draftFor(int draftId, int supplierOrganizationId) =>
      '$traderHome/drafts/$draftId?supplier=$supplierOrganizationId';

  static String orderDetailFor(int id) => '$traderOrders/$id';

  static String shipmentDetailFor(int id) => '$traderShipments/$id';

  static String goodsReceiptFor(int deliveryNoteId) =>
      '$traderHome/receipts/new?delivery_note=$deliveryNoteId';

  static String invoiceDetailFor(int id) => '$traderInvoices/$id';

  static String returnFor(int invoiceId) => '$traderHome/returns/new?invoice=$invoiceId';

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

  static String supplierOrderDetailFor(int id) => '$supplierOrders/$id';

  static String outboundDetailFor(int id) => '$supplierOutbound/$id';

  static String skuRulesFor(int productId) => '$supplierCatalog/$productId';

  static String creditFor(int relationshipId) =>
      '$supplierRelationships/$relationshipId/credit';
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
      GoRoute(path: AppRoutes.settlements, builder: (_, _) => const SettlementsView()),
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
                builder: (_, state) => InvoiceDetailView(invoiceId: _idOf(state, 'id')),
              ),
            ],
          ),
          GoRoute(
            path: 'returns/new',
            builder: (_, state) => ReturnFormView(
              invoiceId: _queryId(state, 'invoice') ?? 0,
            ),
          ),
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
          GoRoute(path: 'returns', builder: (_, _) => const ReturnsInboxView()),
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

    const publicRoutes = {AppRoutes.login, AppRoutes.register, AppRoutes.forgotPassword};

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
    location.startsWith(AppRoutes.contracts) ||
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
