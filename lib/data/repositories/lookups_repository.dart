import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../api_paths.dart';
import '../models/lookups/lookup_item.dart';

/// Read-only pickers. They are cheap and already scoped to the caller's
/// organization, so a screen reads one rather than filtering a full list
/// client-side.
class LookupsRepository {
  final ApiClient _client;

  LookupsRepository(this._client);

  /// [name] comes from [Lookup]. [query] carries the lookup's own filters —
  /// `search`, `status`, `my_role`, `supplier_organization_id`, …
  ///
  /// Search is debounced by the caller (≥ 400 ms); the global budget is 60
  /// requests a minute per IP.
  Future<ApiResult<List<LookupItem>>> items(
    String name, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _client.get<List<LookupItem>>(
        ApiPaths.lookup(name),
        query: query,
        cancelToken: cancelToken,
        parse: (body) => asList(asMap(body)['items'], LookupItem.fromJson),
      );
}
