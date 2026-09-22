class EndPoints {
  static const baseUrl = "https://lammat.laravel.cloud/api/";

  // static const baseUrl = "https://lamat.elzubair.com/api/";

  /////////////////////////// Auth /////////////////////////////
  static String login = "login";
  static String loginVerification = "login-verification";
  static String profile = "me";
  static String updateProfile = "profile";
  static String logout = "logout";
  static String invoices = "customer/invoices";

  /////////////////////////// General /////////////////////////////

  static String banners = "customer/banners";
  static String appSettings = "settings";
  static String eventPlans = "customer/event-plans";
  static String allCities = "cities";
  static String nationality = "nationality";
  static String topProviders = "topproviders";
  static String recommendedServices = "services/most-popular";
  static String allCategories = "categories/all-plugins";
  static String categoryServices = "services/by-category";
  static String providerServices = "services/by-provider";

  static String providerReviews(int providerId) => "providers/$providerId/reviews";
  static String notifications = "notifications";
  static String readNotifications = "notifications/mark-read";
  static String favorites = "customer/favorites";
  static String wallet = "customer/wallet";
  static String walletTopUp = "customer/wallet/transactions";
  static String search = "services/search";
  static String allStories = "customer/stories/by-provider";
  static String showStory = "customer/stories/views/show";
  static String packages = "customer/packages";

  //////////////////// Onboarding preferences //////////////////
  static String interests = "customer/interests";
  static String myInterests = "customer/my-interests";
  static String customerCities = "customer/cities";
  static String blocks = "customer/blocks";

  //////////////////// Addresses //////////////////
  static String addresses = "customer/addresses";
  static String checkAddressZone = "customer/addresses/check-coverage";

  static String pages(String slug) => "page/$slug";

  static String categories({required String pluginName}) => "${pluginName.toLowerCase()}/customer/categories";

  static String pluginServices({required String pluginName}) =>
      "${pluginName.toLowerCase()}/customer/${pluginName.toLowerCase() == "shop" ? "products" : "services"}";

  static String serviceDetails({required int serviceId, required String pluginName}) =>
      "${pluginName.toLowerCase()}/customer/${pluginName.toLowerCase() == "shop" ? "products" : "services"}/$serviceId";

  static String serviceReviews({required int serviceId}) => "services/$serviceId/reviews";

  static String cart = "customer/cart";
  static String coupon = "customer/cart/coupon";
  static String checkout = "customer/cart/checkout";
  static String shippingOptions = "customer/cart/shipping-options";
  static String selectShippingOption = "customer/cart/select-shipping";
  static String normalOrders = "customer/orders";
  static String privateOrders = "customer/private-orders";
  static String addRating = "customer/ratings";

  static String initNormalPayment = "payments";
  static String verifyApplePay = "payments/verify";
  static String initApplePay = "payments/apple-pay/init";
  static String updateEventDate = "customer/cart/event-date";

  static String initPrivatePayment(int id) => "customer/private-orders/$id/pay";

  static String orderProposals(int id) => "customer/private-orders/proposals/$id";

  static String rejectProposal(int id) => "customer/proposals/$id/reject";

  static String acceptProposal(int id) => "customer/proposals/$id/accept";

  //////////////////// Chat //////////////////

  static String conversations = "messages/conversations";

  static String sendMessage(int conversationId) => "$conversations/$conversationId/send";

  static String chatMessages(int conversationId) => "$conversations/$conversationId";
}
