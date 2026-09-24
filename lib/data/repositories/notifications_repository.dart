import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/notifications/app_notification.dart';

class NotificationsRepository {
  final ApiClient _client;

  NotificationsRepository(this._client);

  /// Notifications are the one list that pages with **`per_page`** (default
  /// 20, max 100) rather than `limit`, and the only one whose paginator also
  /// carries a top-level `unread_count`.
  ///
  /// Rows here are plain objects, not the `data[].formatted` wrapper the
  /// document lists use.
  Future<ApiResult<Paged<AppNotification>>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) =>
      _client.get<Paged<AppNotification>>(
        ApiPaths.notifications,
        query: {
          ...PageParams.perPage(page, size: perPage),
          if (unreadOnly) 'unread': 1,
        },
        parse: (body) => Paged.fromJson(
          asMap(body),
          AppNotification.fromJson,
          formattedKey: false,
        ),
      );

  Future<ApiResult<void>> markRead(int id) =>
      _client.patch<void>(ApiPaths.notificationRead(id));

  /// `{msg, updated, unread_count}`.
  Future<ApiResult<int>> markAllRead() => _client.patch<int>(
        ApiPaths.notificationsReadAll,
        parse: (body) => asInt(asMap(body)['unread_count']),
      );
}
