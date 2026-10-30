import 'package:dio/dio.dart';

import '../../core/network/coerce.dart';

/// A Nominatim search hit.
class Place {
  final String name;
  final double lat;
  final double lng;

  const Place({required this.name, required this.lat, required this.lng});
}

/// OpenStreetMap's Nominatim, as the website's branch map uses it — not our
/// backend, so it has its own client and none of the auth headers.
///
/// Like the other repositories it never throws: a failure is `null`.
class PlacesRepository {
  /// Nominatim's usage policy requires an identifying User-Agent.
  static const userAgent = 'TajerID/1.0 (com.dtp.sa)';

  final Dio _dio;

  PlacesRepository([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'User-Agent': userAgent},
            ),
          );

  /// Up to six places for [query]. [viewbox] (`west,north,east,south`) ranks
  /// what is near the visible map first, without excluding the rest.
  Future<List<Place>?> search(String query, {required String language, String? viewbox}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/search',
        queryParameters: {
          'format': 'jsonv2',
          'addressdetails': 0,
          'limit': 6,
          'accept-language': language,
          'q': query,
          'viewbox': ?viewbox,
        },
      );
      // `lat`/`lon` come back as strings.
      return [
        for (final row in asList(response.data, (j) => j))
          if (double.tryParse(asStr(row['lat'])) case final lat?)
            if (double.tryParse(asStr(row['lon'])) case final lng?)
              Place(name: asStr(row['display_name']), lat: lat, lng: lng),
      ];
    } on DioException {
      return null;
    }
  }

  /// The address at a pin, for an empty address field.
  Future<String?> reverse(double lat, double lng, {required String language}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'zoom': 18,
          'lat': lat,
          'lon': lng,
          'accept-language': language,
        },
      );
      final name = asStr(asMap(response.data)['display_name']).trim();
      return name.isEmpty ? null : name;
    } on DioException {
      return null;
    }
  }

  /// Where a short share link (`maps.app.goo.gl/…`) lands; its final URL is
  /// what carries the coordinates.
  Future<String?> resolveLink(String url) async {
    try {
      final response = await _dio.getUri<dynamic>(
        Uri.parse(url.trim()),
        options: Options(followRedirects: true, responseType: ResponseType.plain),
      );
      return response.realUri.toString();
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
