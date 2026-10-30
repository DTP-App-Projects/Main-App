import 'package:dio/dio.dart';
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
}) => {
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
      final cubit = cubitWith(FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [])));
      await cubit.load();

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.errorMessage, isNull);
    });
  });

  group('staying fresh', () {
    test('a quiet refresh picks up new rows without a skeleton', () async {
      var ids = [1, 2];
      final cubit = cubitWith(
        FakeAdapter((_) async => jsonBody(_page(currentPage: 1, lastPage: 1, ids: ids, unread: 2))),
      );
      await cubit.load();

      ids = [3, 1, 2];
      final seen = <bool>[];
      final sub = cubit.stream.listen((s) => seen.add(s.loading));
      await cubit.refresh(quiet: true);
      await Future<void>.delayed(Duration.zero);

      // A list of one or two rows used to stay as it was until pulled.
      expect(cubit.state.items.map((n) => n.id), [3, 1, 2]);
      expect(seen, isNot(contains(true)), reason: 'the old rows stay on screen');
      await sub.cancel();
      await cubit.close();
    });

    test('a failed quiet refresh keeps the rows and shows no error', () async {
      var offline = false;
      final cubit = cubitWith(
        FakeAdapter((options) async {
          if (offline) throw DioException.connectionError(requestOptions: options, reason: 'x');
          return jsonBody(_page(currentPage: 1, lastPage: 1, ids: [1]));
        }),
      );
      await cubit.load();

      offline = true;
      await cubit.refresh(quiet: true);

      expect(cubit.state.items.map((n) => n.id), [1]);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test('a push bumps the badge and then re-reads the list once', () async {
      final adapter = FakeAdapter(
        (_) async => jsonBody(_page(currentPage: 1, lastPage: 1, ids: [9, 1], unread: 3)),
      );
      final (client, _) = clientWith(adapter);
      final cubit = NotificationsCubit(NotificationsRepository(client));

      cubit
        ..onPushReceived()
        ..onPushReceived();
      expect(cubit.state.unreadCount, 2, reason: 'the badge moves at once');

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(adapter.requests.length, 1, reason: 'a burst is one request');
      expect(cubit.state.items.map((n) => n.id), [9, 1]);
      expect(cubit.state.unreadCount, 3);
      await cubit.close();
    });
  });

  group('paging', () {
    test('a second page is appended, not replaced', () async {
      var call = 0;
      final cubit = cubitWith(
        FakeAdapter((options) async {
          call++;
          return FakeAdapter.json(
            call == 1
                ? _page(currentPage: 1, lastPage: 2, ids: [1, 2])
                : _page(currentPage: 2, lastPage: 2, ids: [3, 4]),
          ).handler(options);
        }),
      );

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
      final cubit = cubitWith(
        FakeAdapter((options) async {
          call++;
          return call == 1
              ? FakeAdapter.json(
                  _page(currentPage: 1, lastPage: 1, ids: [1], unread: 2),
                ).handler(options)
              : FakeAdapter.json({'msg': 'notification_not_found'}, status: 404).handler(options);
        }),
      );
      await cubit.load();

      await cubit.markRead(cubit.state.items.first);

      expect(cubit.state.items.first.isRead, isFalse);
      expect(cubit.state.unreadCount, 2);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('an already-read row costs no request', () async {
      final adapter = FakeAdapter.json(_page(currentPage: 1, lastPage: 1, ids: [1], read: true));
      final cubit = cubitWith(adapter);
      await cubit.load();

      await cubit.markRead(cubit.state.items.first);

      expect(adapter.requests.length, 1);
    });

    test('mark-all flips every row and takes the server unread count', () async {
      var call = 0;
      final cubit = cubitWith(
        FakeAdapter((options) async {
          call++;
          return call == 1
              ? FakeAdapter.json(
                  _page(currentPage: 1, lastPage: 1, ids: [1, 2], unread: 2),
                ).handler(options)
              : FakeAdapter.json({'msg': 'ok', 'updated': 2, 'unread_count': 0}).handler(options);
        }),
      );
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
