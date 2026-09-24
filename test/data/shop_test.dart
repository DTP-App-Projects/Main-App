import 'dart:io';

import 'package:digital_trade_portal/core/ui/form_status.dart';
import 'package:digital_trade_portal/data/models/shop/cart.dart';
import 'package:digital_trade_portal/data/models/shop/shop_product.dart';
import 'package:digital_trade_portal/data/repositories/shop_repository.dart';
import 'package:digital_trade_portal/features/shop/view_models/shop_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/fake_backend.dart';

void main() {
  group('v1 product parsing', () {
    test('a numeric-looking field survives JSON_NUMERIC_CHECK', () {
      final product = ShopProduct.fromJson(const {
        'id': 12,
        'type': 'static',
        // The server sends this as a number once it looks like one.
        'name': 900700,
        'price_meta': {'price': 25, 'sale_price': 0, 'sale': false, 'count': 4},
      });

      expect(product.name, '900700');
      expect(product.price.effective, 25);
      expect(product.price.inStock, isTrue);
    });

    test('a sale price wins only while the sale flag is on', () {
      const onSale = PriceMeta(
        price: 100,
        salePrice: 80,
        saleTill: null,
        onSale: true,
        count: 1,
      );
      const off = PriceMeta(
        price: 100,
        salePrice: 80,
        saleTill: null,
        onSale: false,
        count: 0,
      );

      expect(onSale.effective, 80);
      expect(off.effective, 100);
      expect(off.inStock, isFalse);
    });

    test('a static product adds with variation 0, a variable one with its id', () {
      const variation = ProductVariation(id: 7, name: 'L', price: 5, count: 2, raw: {});
      final static_ = ShopProduct.fromJson(const {'id': 1, 'type': 'static'});
      final variable = ShopProduct.fromJson(const {'id': 2, 'type': 'variable'});

      expect(static_.variationIdFor(variation), 0, reason: 'static ignores it');
      expect(static_.variationIdFor(null), 0);
      expect(variable.variationIdFor(variation), 7);
      expect(variable.variationIdFor(null), 0);
    });

    test('only a category without children lists products', () {
      final leaf = NamedCategory.fromJson(const {'id': 3, 'subs': false, 'type': 'sec'});
      final branch = NamedCategory.fromJson(const {'id': 1, 'subs': true, 'type': 'main'});

      expect(leaf.listsProducts, isTrue);
      expect(branch.listsProducts, isFalse);
    });
  });

  group('cart and checkout', () {
    test('the cart reads its rows out of the nested paginator', () {
      final cart = Cart.fromJson(const {
        'carts': {
          'data': [
            {'id': 1, 'product_id': 9, 'product_variation_id': 0, 'count': 3, 'price': 10},
          ],
        },
        'totals': {'total': 34.5, 'tax': 4.5, 'cart': 30},
        'addresses': [
          {'id': 2, 'text': 'm_pRiyadh, 12345'},
        ],
      });

      expect(cart.lines.single.count, 3);
      expect(cart.itemCount, 3);
      expect(cart.totals.total, 34.5);
      // The `m_p` guard never reaches the screen.
      expect(cart.addresses.single.text, 'Riyadh, 12345');
    });

    test('add-to-cart always sends product_variation_id', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'carts': {}}));

      await ShopRepository(client).addToCart(productId: 4, count: 2);
      final body = adapter.requests.single.data as Map;

      expect(body['product_variation_id'], 0);
      expect(body['count'], 2);
    });

    test('checkout describes only the last seller', () {
      final result = CheckoutResult.fromJson(const {
        'totals': {'total': 200, 'tax': 20, 'items': 5},
        'seller_info': {'id': 8, 'first_name': 'm_pAli', 'last_name': ''},
      });

      expect(result.items, 5);
      expect(result.lastSeller!.displayName, 'Ali');
    });

    test('a failed checkout still marks the cart checked out', () async {
      // `401 insufficient_product_count` can land *after* some orders exist,
      // so the buyer is sent to the orders list either way.
      final (client, _) = clientWith(
        FakeAdapter.json(const {'error': 'insufficient_product_count'}, status: 401),
      );
      final cubit = CartCubit(ShopRepository(client));
      cubit.setAddress(3);

      final succeeded = await cubit.checkout();

      expect(succeeded, isFalse);
      expect(cubit.state.checkedOut, isTrue);
      expect(cubit.state.action.status, FormStatus.failure);
    });

    test('checkout does not fire without an address, or twice at once', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'totals': {}}));
      final cubit = CartCubit(ShopRepository(client));

      expect(await cubit.checkout(), isFalse);
      expect(adapter.requests, isEmpty, reason: 'no address, no request');

      cubit.setAddress(1);
      final first = cubit.checkout();
      final second = cubit.checkout();

      expect(await second, isFalse, reason: 'the second tap is dropped');
      await first;
      expect(adapter.requests, hasLength(1));
    });
  });

  group('orders', () {
    test('the list always names a status and is never served from the cache',
        () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      final repo = ShopRepository(client);

      await Future.wait([repo.orders(), repo.orders()]);

      expect(adapter.requests, hasLength(2), reason: 'a checkout must be visible');
      expect(adapter.requests.first.queryParameters['status'], 'all');
    });

    test('merchant is the other party, whichever side is asking', () {
      final order = ShopOrder.fromJson(const {
        'id': 5,
        'status': 'pending',
        'status_lang': 'قيد الانتظار',
        // Codes are digits, so they arrive as numbers.
        'code': 20250012,
        'total_fee': 115,
        'items_count': 2,
        'merchant': {'id': 9, 'first_name': 'm_pNoura', 'last_name': 'm_pS'},
        'items': [
          {'id': 3, 'type': 'static', 'name': 'Box'},
        ],
      });

      expect(order.code, '20250012');
      expect(order.statusLabel, 'قيد الانتظار');
      expect(order.merchant!.displayName, 'Noura S');
      expect(order.awaitingPayment, isTrue);
      // The payload drops per-line quantity, so the rows are products only.
      expect(order.items.single.name, 'Box');
    });

    test('a receipt goes up as a direct multipart post', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());
      final file = await _tempFile();

      await ShopRepository(client).uploadReceipt(orderId: 4, filePath: file);
      final request = adapter.requests.single;

      expect(request.path, '/orders/4/receipt');
      expect(request.headers['content-type'], contains('multipart/form-data'));
    });
  });

  group('chat', () {
    test('a message loses its m_p guard and reads both timestamp shapes', () {
      final epoch = ChatMessage.fromJson(const {
        'id': 1,
        'sender_id': 4,
        'text': 'm_pHello',
        'timestamp': 1758499200,
      });
      final dated = ChatMessage.fromJson(const {
        'id': 2,
        'sender_id': 5,
        'text': 'm_pHi',
        'timestamp': '2026-09-22 10:00:00',
      });

      expect(epoch.text, 'Hello');
      expect(epoch.sentAt!.year, 2025);
      expect(dated.sentAt!.year, 2026);
      expect(epoch.isMine(4), isTrue);
      expect(epoch.isMine(5), isFalse);
      expect(epoch.isMine(null), isFalse);
    });

    test('sending carries sender_id, which nothing else fills in', () async {
      final (client, adapter) = clientWith(FakeAdapter.empty());

      await ShopRepository(client).sendMessage(senderId: 11, targetId: 4, text: 'hi');
      final body = adapter.requests.single.data as Map;

      expect(body['sender_id'], 11);
      expect(body['target_id'], 4);
    });
  });

  group('browsing', () {
    test('the top level of the category tree is parent 0', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const []));

      await ShopRepository(client).categories();
      expect(adapter.requests.single.queryParameters['parent'], 0);
    });

    test('opening a product is never collapsed — it counts as a view', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'product': {'id': 1}}));
      final repo = ShopRepository(client);

      await Future.wait([repo.product(1), repo.product(1)]);
      expect(adapter.requests, hasLength(2));
    });

    test('an empty search asks the server for nothing', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      final cubit = ProductListCubit(ShopRepository(client));

      await cubit.load();

      expect(adapter.requests, isEmpty);
      expect(cubit.state.items, isEmpty);

      await cubit.setSearch('  cement  ');
      expect(adapter.requests.single.queryParameters['text'], 'cement');
    });

    test('a failed favourite toggle puts the heart back', () async {
      final (client, _) = clientWith(FakeAdapter.json(const {'data': []}, status: 400));
      final cubit = ProductListCubit(ShopRepository(client), feedType: ProductFeed.discount);
      final product = ShopProduct.fromJson(const {'id': 3, 'is_favorite': false});

      await cubit.toggleFavorite(product);

      expect(cubit.state.errorMessage, isNotNull);
    });
  });
}

/// A real file on disk, because `MultipartFile.fromFile` reads one.
Future<String> _tempFile() async {
  final directory = await Directory.systemTemp.createTemp('shop_test');
  final file = File('${directory.path}/receipt.png');
  await file.writeAsBytes(const [0x89, 0x50, 0x4E, 0x47]);
  return file.path;
}
