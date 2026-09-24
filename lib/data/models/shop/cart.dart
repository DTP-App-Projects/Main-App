import '../../../core/network/coerce.dart';
import 'shop_product.dart';

/// The cart, as every cart endpoint returns it.
///
/// **Buyers only** — `type,buyer` is in the validation rule, so a seller
/// account gets a `400 validation_error` rather than an empty cart.
class Cart {
  final List<CartLine> lines;
  final CartTotals totals;
  final List<CartAddress> addresses;

  const Cart({required this.lines, required this.totals, required this.addresses});

  factory Cart.fromJson(Map<String, dynamic> j) {
    // `carts` is a paginator; only its rows matter here.
    final rows = asMap(j['carts'])['data'];
    return Cart(
      lines: asList(rows, CartLine.fromJson),
      totals: CartTotals.fromJson(asMap(j['totals'])),
      addresses: asList(j['addresses'], CartAddress.fromJson),
    );
  }

  static const empty = Cart(lines: [], totals: CartTotals.zero, addresses: []);

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, line) => sum + line.count);

  // The cart payload carries no seller per line, so how many orders checkout
  // will create is not knowable here — the screen says that it may be more
  // than one rather than guessing a number.
}

class CartLine {
  final int id;
  final int productId;

  /// `0` for a static product.
  final int productVariationId;

  final int count;
  final double price;
  final ShopProduct? product;

  const CartLine({
    required this.id,
    required this.productId,
    required this.productVariationId,
    required this.count,
    required this.price,
    required this.product,
  });

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        id: asInt(j['id']),
        productId: asInt(j['product_id']),
        productVariationId: asInt(j['product_variation_id']),
        count: asInt(j['count']),
        price: asNum(j['price']),
        product: j['product'] is Map ? ShopProduct.fromJson(asMap(j['product'])) : null,
      );

  String get name => product?.name ?? '#$productId';
}

/// `total` is the **gross**, tax-inclusive sum; `cart` is `total - tax`.
/// None of it is recomputed here.
class CartTotals {
  final double total;
  final double tax;
  final double net;

  const CartTotals({required this.total, required this.tax, required this.net});

  factory CartTotals.fromJson(Map<String, dynamic> j) => CartTotals(
        total: asNum(j['total']),
        tax: asNum(j['tax']),
        net: asNum(j['cart']),
      );

  static const zero = CartTotals(total: 0, tax: 0, net: 0);
}

class CartAddress {
  final int id;
  final String text;

  const CartAddress({required this.id, required this.text});

  factory CartAddress.fromJson(Map<String, dynamic> j) => CartAddress(
        id: asInt(j['id']),
        // Addresses are `m_p`-guarded.
        text: unwrap(j['text']),
      );
}

/// What checkout answers with.
///
/// ⚠️ It describes **only the last seller processed**. Checkout splits the
/// cart by seller, creates one order each, and empties the cart — so this is
/// never the whole picture and the orders list has to be re-read.
class CheckoutResult {
  final double total;
  final double tax;
  final int items;
  final ShopSeller? lastSeller;

  const CheckoutResult({
    required this.total,
    required this.tax,
    required this.items,
    required this.lastSeller,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> j) {
    final totals = asMap(j['totals']);
    return CheckoutResult(
      total: asNum(totals['total']),
      tax: asNum(totals['tax']),
      items: asInt(totals['items']),
      lastSeller:
          j['seller_info'] is Map ? ShopSeller.fromJson(asMap(j['seller_info'])) : null,
    );
  }
}

/// A marketplace order.
///
/// The list auto-detects the caller's side from `users.type`, and `merchant`
/// is always **the other party** — the seller to a buyer, the buyer to a
/// seller.
class ShopOrder {
  final int id;
  final String status;
  final String statusLabel;

  /// Order codes are all digits and arrive as numbers.
  final String code;

  final String address;
  final int itemsCount;
  final double itemsFee;
  final double taxFee;
  final double totalFee;
  final DateTime? placedAt;
  final String image;
  final OrderMerchant? merchant;

  /// ⚠️ The controller builds per-line `price`/`count` and then pushes only
  /// the product, so these rows carry **no quantity**. Quantities come from
  /// the buyer's own cart state, not from here.
  final List<ShopProduct> items;

  const ShopOrder({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.code,
    required this.address,
    required this.itemsCount,
    required this.itemsFee,
    required this.taxFee,
    required this.totalFee,
    required this.placedAt,
    required this.image,
    required this.merchant,
    required this.items,
  });

  factory ShopOrder.fromJson(Map<String, dynamic> j) => ShopOrder(
        id: asInt(j['id']),
        status: asStr(j['status']),
        // Already localized by the server from `Accept-Language`.
        statusLabel: unwrap(j['status_lang']),
        code: asStr(j['code']),
        address: unwrap(j['address']),
        itemsCount: asInt(j['items_count']),
        itemsFee: asNum(j['items_fee']),
        taxFee: asNum(j['tax_fee']),
        totalFee: asNum(j['total_fee']),
        placedAt: asDate(j['timestamp']),
        image: asStr(j['image']),
        merchant:
            j['merchant'] is Map ? OrderMerchant.fromJson(asMap(j['merchant'])) : null,
        items: asList(j['items'], ShopProduct.fromJson),
      );

  /// The statuses `GET /api/orders` accepts. `status` is **required**, and
  /// `all` is how you ask for everything.
  static const filters = [
    'all',
    'pending',
    'confirmed',
    'processing',
    'delivered',
    'declined',
  ];

  /// The transitions a **seller** may make.
  static const sellerTransitions = ['confirmed', 'processing', 'delivered', 'declined'];

  bool get awaitingPayment => status == 'pending';
}

class OrderMerchant {
  final int id;
  final String firstName;
  final String lastName;
  final String image;
  final String bankInfo;

  const OrderMerchant({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.image,
    required this.bankInfo,
  });

  factory OrderMerchant.fromJson(Map<String, dynamic> j) => OrderMerchant(
        id: asInt(j['id']),
        firstName: unwrap(j['first_name']),
        lastName: unwrap(j['last_name']),
        image: asStr(j['image']),
        bankInfo: unwrap(j['bank_info']),
      );

  String get displayName =>
      [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
}

/// A conversation in the v1 chat.
class ChatThread {
  final int id;
  final String firstName;
  final String lastName;
  final String image;
  final ChatMessage? latest;

  const ChatThread({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.image,
    required this.latest,
  });

  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        id: asInt(j['id']),
        firstName: unwrap(j['first_name']),
        lastName: unwrap(j['last_name']),
        image: asStr(j['image']),
        latest: j['message'] is Map ? ChatMessage.fromJson(asMap(j['message'])) : null,
      );

  String get displayName =>
      [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
}

class ChatMessage {
  final int id;
  final int senderId;

  /// **`m_p`-prefixed on the wire** — the guard has to come off or every
  /// message reads `m_pHello`.
  final String text;

  final DateTime? sentAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: asInt(j['id']),
        senderId: asInt(j['sender_id']),
        text: unwrap(j['text']),
        // v1 chat timestamps are UNIX seconds on some rows and a date string
        // on others.
        sentAt: _time(j['timestamp']),
      );

  bool isMine(int? userId) => userId != null && senderId == userId;

  static DateTime? _time(dynamic raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000);
    }
    return asDate(raw);
  }
}
