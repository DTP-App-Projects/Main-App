import '../../../core/network/coerce.dart';

/// A product in the v1 marketplace.
///
/// The list item and the detail share a model; the detail simply fills more
/// of it. **Products are scoped to the caller's country** — asking for one
/// from another country is `401 product_not_same_country_as_user`.
class ShopProduct {
  final int id;

  /// `static` | `variable`. A variable product needs a variation id on the
  /// add-to-cart call; a static one takes `0`.
  final String type;

  final String name;
  final String image;
  final PriceMeta price;
  final bool isFavorite;
  final bool isCart;

  // ---- detail only --------------------------------------------------------
  final double rate;
  final String description;
  final String custom;
  final bool isNegotiated;
  final NamedCategory? category;
  final List<String> images;
  final List<ProductVariation> variations;

  const ShopProduct({
    required this.id,
    required this.type,
    required this.name,
    required this.image,
    required this.price,
    required this.isFavorite,
    required this.isCart,
    this.rate = 0,
    this.description = '',
    this.custom = '',
    this.isNegotiated = false,
    this.category,
    this.images = const [],
    this.variations = const [],
  });

  factory ShopProduct.fromJson(Map<String, dynamic> j) => ShopProduct(
        id: asInt(j['id']),
        type: asStr(j['type']),
        name: unwrap(j['name']),
        // v1 images are absolute URLs already.
        image: asStr(j['image']),
        price: PriceMeta.fromJson(asMap(j['price_meta'])),
        isFavorite: asBool(j['is_favorite']),
        isCart: asBool(j['is_cart']),
        rate: asNum(j['rate']),
        description: unwrap(j['desc']),
        custom: unwrap(j['custom']),
        isNegotiated: asBool(j['is_negotiated']),
        category:
            j['category'] is Map ? NamedCategory.fromJson(asMap(j['category'])) : null,
        images: (j['images'] is List)
            ? (j['images'] as List)
                .whereType<Map>()
                .map((row) => asStr(row['image']))
                .where((url) => url.isNotEmpty)
                .toList()
            : const [],
        variations: asList(j['variations'], ProductVariation.fromJson),
      );

  bool get isVariable => type == 'variable';

  /// A static product takes `0`; a variable one needs a real variation.
  int variationIdFor(ProductVariation? variation) =>
      isVariable ? (variation?.id ?? 0) : 0;

  ShopProduct withFavorite(bool value) => ShopProduct(
        id: id,
        type: type,
        name: name,
        image: image,
        price: price,
        isFavorite: value,
        isCart: isCart,
        rate: rate,
        description: description,
        custom: custom,
        isNegotiated: isNegotiated,
        category: category,
        images: images,
        variations: variations,
      );
}

class PriceMeta {
  final double price;
  final double salePrice;
  final DateTime? saleTill;
  final bool onSale;

  /// Stock. `401 insufficient_product_count` when a cart line exceeds it.
  final int count;

  const PriceMeta({
    required this.price,
    required this.salePrice,
    required this.saleTill,
    required this.onSale,
    required this.count,
  });

  factory PriceMeta.fromJson(Map<String, dynamic> j) => PriceMeta(
        price: asNum(j['price']),
        salePrice: asNum(j['sale_price']),
        // `""` means no end date rather than the epoch.
        saleTill: asDate(j['sale_till']),
        onSale: asBool(j['sale']),
        count: asInt(j['count']),
      );

  static const empty = PriceMeta(
    price: 0,
    salePrice: 0,
    saleTill: null,
    onSale: false,
    count: 0,
  );

  /// What the buyer actually pays.
  double get effective => onSale && salePrice > 0 ? salePrice : price;

  bool get inStock => count > 0;
}

class ProductVariation {
  final int id;
  final String name;
  final double price;
  final int count;
  final Map<String, dynamic> raw;

  const ProductVariation({
    required this.id,
    required this.name,
    required this.price,
    required this.count,
    required this.raw,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> j) => ProductVariation(
        id: asInt(j['id']),
        name: unwrap(j['name'] ?? j['title'] ?? j['options_str']),
        price: asNum(j['price']),
        count: asInt(j['count']),
        raw: j,
      );

  String get label => name.isNotEmpty ? name : '#$id';
}

class NamedCategory {
  final int id;
  final String name;
  final String image;

  /// True when this category has children — the list drills down instead of
  /// showing products.
  final bool hasSubs;

  final String type;

  const NamedCategory({
    required this.id,
    required this.name,
    required this.image,
    required this.hasSubs,
    required this.type,
  });

  factory NamedCategory.fromJson(Map<String, dynamic> j) => NamedCategory(
        id: asInt(j['id']),
        name: unwrap(j['name']),
        image: asStr(j['image']),
        hasSubs: asBool(j['subs']),
        type: asStr(j['type']),
      );

  /// Only a third-level (`sec`) category lists products.
  bool get listsProducts => !hasSubs;
}

/// The seller behind a product.
class ShopSeller {
  final int id;
  final String firstName;
  final String lastName;
  final String image;

  /// `m_p`-guarded so the leading zero survives.
  final String phone;
  final String whatsapp;

  final String companyName;
  final String bankInfo;

  const ShopSeller({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.image,
    required this.phone,
    required this.whatsapp,
    required this.companyName,
    required this.bankInfo,
  });

  factory ShopSeller.fromJson(Map<String, dynamic> j) => ShopSeller(
        id: asInt(j['id']),
        firstName: unwrap(j['first_name']),
        lastName: unwrap(j['last_name']),
        image: asStr(j['image']),
        phone: unwrap(j['phone']),
        whatsapp: unwrap(j['whatsapp']),
        companyName: unwrap(j['company_name']),
        bankInfo: unwrap(j['bank_info']),
      );

  String get displayName {
    final name = [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : companyName;
  }
}

/// `GET /api/products/{id}` — product, seller and a couple of similars.
class ShopProductDetail {
  final ShopProduct product;
  final ShopSeller? seller;
  final List<ShopProduct> similars;

  const ShopProductDetail({
    required this.product,
    required this.seller,
    required this.similars,
  });

  factory ShopProductDetail.fromJson(Map<String, dynamic> j) => ShopProductDetail(
        product: ShopProduct.fromJson(asMap(j['product'])),
        seller: j['seller'] is Map ? ShopSeller.fromJson(asMap(j['seller'])) : null,
        similars: asList(j['similars'], ShopProduct.fromJson),
      );
}

/// `GET /api/home` — the shop landing page in one call.
class ShopHome {
  final List<HomeSlider> sliders;
  final List<NamedCategory> categories;
  final List<ShopProduct> bestSelling;
  final List<ShopProduct> mostViewed;
  final List<ShopProduct> discounted;
  final int cartCount;

  const ShopHome({
    required this.sliders,
    required this.categories,
    required this.bestSelling,
    required this.mostViewed,
    required this.discounted,
    required this.cartCount,
  });

  factory ShopHome.fromJson(Map<String, dynamic> j) => ShopHome(
        sliders: asList(j['sliders'], HomeSlider.fromJson),
        categories: asList(j['categories'], NamedCategory.fromJson),
        bestSelling: asList(j['best_selling'], ShopProduct.fromJson),
        mostViewed: asList(j['most_viewed'], ShopProduct.fromJson),
        discounted: asList(j['discount'], ShopProduct.fromJson),
        cartCount: asInt(j['cart_count']),
      );

  bool get isEmpty =>
      sliders.isEmpty &&
      categories.isEmpty &&
      bestSelling.isEmpty &&
      mostViewed.isEmpty &&
      discounted.isEmpty;
}

class HomeSlider {
  final String url;
  final String image;

  const HomeSlider({required this.url, required this.image});

  factory HomeSlider.fromJson(Map<String, dynamic> j) =>
      HomeSlider(url: asStr(j['url']), image: asStr(j['image']));
}

/// The three feeds `/api/products?type=` serves.
class ProductFeed {
  ProductFeed._();

  static const bestSelling = 'best_selling';
  static const mostViewed = 'most_viewed';
  static const discount = 'discount';
}
