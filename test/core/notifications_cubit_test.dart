import 'package:digital_trade_portal/data/repositories/notifications_repository.dart';
import 'package:digital_trade_portal/features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Map<String, dynamic> _page({
  required int currentPage,
  required int lastPage,
  required List<int> ids,
  int unread = 0,
  bool read = false,
}) =>
    {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': 20,
      'total': 40,
      'unread_count': unread,
      'data': [
        for (final id in ids)
          {'id': id, 'title': 'Event $id', 'click_action': 'invoice', 'is_read': read},
      ],
    };

void main() {
  NotificationsCubit cubitWith(FakeAdapter adapter) {
    final (client, _) = clientWith(adapter);
    return NotificationsCubit(NotificationsRepository(client));
  }

  group('loading', () {
    test('a first page fills the list and the badge', () async {
      final cubit = cubitWith(
        FakeAdapter.json(_page(currentPage: 1, lastPage: 2, ids: [1, 2], unread: 5)),
      );

      await cubit.load();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.items.map((n) => n.id), [1, 2]);
      expect(cubit.state.unreadCount, 5);
      expect(cubit.state.hasMore, isTrue);
    });

    test('offline is its own state, not an error', () async {
      final cubit = cubitWith(FakeAdapter.offline());
      await cubit.load();

      expect(cubit.state.offline, isTrue);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('an empty list is empty, not an error', () async {
      final cubit = cubitWith(
        FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [])),
      );
      await cubit.load();

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.errorMessage, isNull);
    });
  });

  group('paging', () {
    test('a second page is appended, not replaced', () async {
      var call = 0;
      final cubit = cubitWith(FakeAdapter((options) async {
        call++;
        return FakeAdapter.json(
          call == 1
              ? _page(currentPage: 1, lastPage: 2, ids: [1, 2])
              : _page(currentPage: 2, lastPage: 2, ids: [3, 4]),
        ).handler(options);
      }));

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.items.map((n) => n.id), [1, 2, 3, 4]);
      expect(cubit.state.hasMore, isFalse);
    });

    test('the last page does not fire another request', () async {
      final adapter = FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1]));
      final cubit = cubitWith(adapter);

      await cubit.load();
      await cubit.loadMore();

      expect(adapter.requests.length, 1);
    });

    test('a fast scroller cannot queue three pages at once', () async {
      final adapter = FakeAdapter.json(_page(currentPage: 1, lastPage: 5, ids: [1]));
      final cubit = cubitWith(adapter);
      await cubit.load();

      await Future.wait([cubit.loadMore(), cubit.loadMore(), cubit.loadMore()]);

      // One list request plus one page request — not four.
      expect(adapter.requests.length, 2);
    });
  });

  group('marking read', () {
    test('the row flips immediately and the badge drops', () async {
      final cubit = cubitWith(
        FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1], unread: 2)),
      );
      await cubit.load();

      await cubit.markRead(cubit.state.items.first);

      expect(cubit.state.items.first.isRead, isTrue);
      expect(cubit.state.unreadCount, 1);
    });

    test('a rejected mark is rolled back rather than left lying', () async {
      var call = 0;
      final cubit = cubitWith(FakeAdapter((options) async {
        call++;
        return call == 1
            ? FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1], unread: 2))
                .handler(options)
            : FakeAdapter.json({'msg': 'notification_not_found'}, status: 404)
                .handler(options);
      }));
      await cubit.load();

      await cubit.markRead(cubit.state.items.first);

      expect(cubit.state.items.first.isRead, isFalse);
      expect(cubit.state.unreadCount, 2);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('an already-read row costs no request', () async {
      final adapter =
          FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1], read: true));
      final cubit = cubitWith(adapter);
      await cubit.load();

      await cubit.markRead(cubit.state.items.first);

      expect(adapter.requests.length, 1);
    });

    test('mark-all flips every row and takes the server unread count', () async {
      var call = 0;
      final cubit = cubitWith(FakeAdapter((options) async {
        call++;
        return call == 1
            ? FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1, 2], unread: 2))
                .handler(options)
            : FakeAdapter.json({'msg': 'ok', 'updated': 2, 'unread_count': 0})
                .handler(options);
      }));
      await cubit.load();

      await cubit.markAllRead();

      expect(cubit.state.items.every((n) => n.isRead), isTrue);
      expect(cubit.state.unreadCount, 0);
    });
  });

  test('a push arriving in the foreground bumps the badge without a fetch', () async {
    final adapter = FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1], unread: 1));
    final cubit = cubitWith(adapter);
    await cubit.load();

    cubit.onPushReceived();

    expect(cubit.state.unreadCount, 2);
    expect(adapter.requests.length, 1);
  });
}
