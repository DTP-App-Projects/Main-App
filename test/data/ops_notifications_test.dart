import 'package:digital_trade_portal/core/network/paged.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal/core/workspace/workspace.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/models/bootstrap/organization.dart';
import 'package:digital_trade_portal/data/models/lookups/lookup_item.dart';
import 'package:digital_trade_portal/data/models/notifications/app_notification.dart';
import 'package:digital_trade_portal/data/models/ops/quick_action.dart';
import 'package:digital_trade_portal/data/repositories/notifications_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fake_backend.dart';

void main() {
  group('quick actions + theme', () {
    const payload = {
      'workspace': 'supplier',
      'theme': {
        'primary_color': '#1E56A0',
        'primary_on': '#FFFFFF',
        'secondary_color': '#F26A1F',
        'accent_color': '#0C2D57',
        'surface_color': '#F5F8FB',
      },
      'quick_actions': [
        {
          'key': 'issue_invoice',
          'label_ar': 'إصدار فاتورة',
          'label_en': 'Issue invoice',
          'icon': 'receipt',
          'workspace': 'supplier',
          'permission': 'invoices.manage',
          'permission_alts': [],
          'route': '/v2/invoice/store',
          'group': 'money',
          'priority': 90,
        },
      ],
    };

    test('parses the server palette and the action catalogue', () {
      final response =
          QuickActionsResponse.fromJson(payload, requested: Workspace.supplier);

      expect(response.workspace, Workspace.supplier);
      expect(response.theme.primary, const Color(0xFF1E56A0));
      expect(response.actions.single.key, 'issue_invoice');
      expect(response.actions.single.label('ar'), 'إصدار فاتورة');
      expect(response.actions.single.allPermissions, ['invoices.manage']);
    });

    test('the echoed workspace wins, and its absence falls back to the request', () {
      final echoed = QuickActionsResponse.fromJson(payload, requested: Workspace.trader);
      expect(echoed.workspace, Workspace.supplier);

      final silent = QuickActionsResponse.fromJson(
        const {'theme': {}, 'quick_actions': []},
        requested: Workspace.trader,
      );
      expect(silent.workspace, Workspace.trader);
      expect(silent.theme, ThemeTokens.traderFallback);
    });

    test('the RPC route is parsed but is not a navigation target', () {
      final response =
          QuickActionsResponse.fromJson(payload, requested: Workspace.supplier);
      // Still the pre-REST path — navigation keys off `key`.
      expect(response.actions.single.route, startsWith('/v2/'));
      expect(response.actions.single.key, isNotEmpty);
    });

    test('theme tokens survive a cache round trip', () {
      final original = ThemeTokens.supplierFallback;
      final restored =
          ThemeTokens.fromJson(original.toJson(), workspace: Workspace.supplier);
      expect(restored, original);
    });
  });

  group('WorkspaceCubit theme', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CacheHelper.init();
    });

    final org = Organization.fromJson(const {
      'id': 3,
      'display_name': 'Test',
      'business_mode': 'hybrid',
      'approved_workspaces': ['trader', 'supplier'],
    });

    test('adopts the server palette and caches it for next time', () async {
      final store = SessionStore();
      final (client, _) = clientWith(FakeAdapter.json(const {
        'workspace': 'trader',
        'theme': {'primary_color': '#123456'},
        'quick_actions': [],
      }));
      final cubit = WorkspaceCubit(store, OpsRepository(client));

      await cubit.hydrate(org);

      expect(cubit.state?.theme.primary, const Color(0xFF123456));
      // Cached per organization *and* workspace — the two sides differ.
      expect(store.cachedTheme(3, Workspace.trader)?.primary, const Color(0xFF123456));
      expect(store.cachedTheme(3, Workspace.supplier), isNull);
    });

    test('a failed theme read leaves a correct fallback, not an error', () async {
      final (client, _) = clientWith(FakeAdapter.offline());
      final cubit = WorkspaceCubit(SessionStore(), OpsRepository(client));

      await cubit.hydrate(org);

      expect(cubit.state?.theme, ThemeTokens.traderFallback);
    });

    test('a cold start repaints from cache before the server answers', () async {
      final store = SessionStore();
      await store.cacheTheme(3, Workspace.trader, ThemeTokens.supplierFallback);

      final (client, _) = clientWith(FakeAdapter.offline());
      final cubit = WorkspaceCubit(store, OpsRepository(client));
      await cubit.hydrate(org);

      // Not the compile-time trader fallback: the palette last seen.
      expect(cubit.state?.theme, ThemeTokens.supplierFallback);
    });
  });

  group('notifications', () {
    test('rows are plain objects, not the formatted wrapper', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {
        'current_page': 1,
        'last_page': 2,
        'per_page': 20,
        'total': 24,
        'unread_count': 3,
        'data': [
          {
            'id': 981,
            'event_code': 'purchase_order.rejected',
            'entity_type': 'purchase_order',
            'entity_id': 1234,
            'title': 'Order rejected',
            'body': 'Out of stock',
            'click_action': 'purchase_order',
            'is_read': false,
            'created_at': '2026-09-19 14:02:11',
          },
        ],
      }));
      final repo = NotificationsRepository(client);

      final result = await repo.list();
      final page = (result.dataOrNull as Paged<AppNotification>);

      expect(page.items.single.id, 981);
      expect(page.items.single.entityId, 1234);
      expect(page.unreadCount, 3);
      expect(page.hasMore, isTrue);

      // This list pages with per_page, not limit.
      final query = adapter.requests.single.queryParameters;
      expect(query['per_page'], 20);
      expect(query.containsKey('limit'), isFalse);
    });

    test('unread=1 is only sent when the filter is on', () async {
      final (client, adapter) = clientWith(FakeAdapter.json(const {'data': []}));
      final repo = NotificationsRepository(client);

      await repo.list(unreadOnly: false);
      await repo.list(unreadOnly: true);

      expect(adapter.requests.first.queryParameters.containsKey('unread'), isFalse);
      expect(adapter.requests.last.queryParameters['unread'], 1);
    });

    test('the headline falls back through the localized pair', () {
      final withTitle = AppNotification.fromJson(const {
        'id': 1,
        'title': 'Invoice issued',
        'text_ar': 'صدرت فاتورة',
        'text_en': 'Invoice issued',
      });
      final withoutTitle = AppNotification.fromJson(const {
        'id': 2,
        'text_ar': 'صدرت فاتورة',
        'text_en': 'Invoice issued',
      });

      expect(withTitle.headline('en'), 'Invoice issued');
      expect(withoutTitle.headline('ar'), 'صدرت فاتورة');
      // `text` repeats the headline, so it is not shown twice.
      expect(withoutTitle.detail('ar'), '');
    });

    test('marking read is a copy, not a mutation', () {
      final unread = AppNotification.fromJson(const {'id': 1, 'is_read': false});
      final read = unread.markedRead();

      expect(unread.isRead, isFalse);
      expect(read.isRead, isTrue);
      expect(read.id, unread.id);
    });
  });

  group('LookupItem', () {
    test('reads whichever label the row happens to carry', () {
      expect(
        LookupItem.fromJson(const {'id': 1, 'display_name': 'Al Rajhi'}).label('en'),
        'Al Rajhi',
      );
      expect(
        LookupItem.fromJson(const {'id': 2, 'name': 'Riyadh Branch'}).label('en'),
        'Riyadh Branch',
      );
      expect(
        LookupItem.fromJson(const {'id': 3, 'name_ar': 'الرياض', 'name_en': 'Riyadh'})
            .label('ar'),
        'الرياض',
      );
    });

    test('a nameless row falls back to its code, then its id', () {
      expect(LookupItem.fromJson(const {'id': 9, 'code': 'PO-20260919'}).label('en'),
          'PO-20260919');
      expect(LookupItem.fromJson(const {'id': 9}).label('en'), '#9');
    });

    test('an all-digit code stays text', () {
      expect(LookupItem.fromJson(const {'id': 1, 'code': 20260919}).code, '20260919');
    });

    test('the untouched row is kept for the fields a picker needs', () {
      final item = LookupItem.fromJson(const {
        'id': 1,
        'name': 'SKU-1',
        'resolved_price': 12.5,
        'available_qty': 40,
      });
      expect(item.raw['resolved_price'], 12.5);
    });

    test('client-side filtering matches the label and the code', () {
      final item = LookupItem.fromJson(const {'id': 1, 'name': 'Riyadh', 'code': 'RYD-1'});
      expect(item.matches('riy', 'en'), isTrue);
      expect(item.matches('RYD', 'en'), isTrue);
      expect(item.matches('jeddah', 'en'), isFalse);
      expect(item.matches('', 'en'), isTrue);
    });
  });
}
