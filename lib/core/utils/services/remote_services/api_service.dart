import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../local_services/cache_keys.dart';
import 'endpoints.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio) {

    // Add PrettyDioLogger interceptor only in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
    }
  }

  Future<Response> postData({
    required String endPoint,
    bool sendToken = false,
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    _dio.options.headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (sendToken) "Authorization": await CacheKeysManger.getToken(),
    };
    var response = await _dio.post(
      "${EndPoints.baseUrl}$endPoint",
      data: data,
      queryParameters: {"lang": CacheKeysManger.getUserLanguage(), if (query != null) ...query},
    );
    return response;
  }

  Future<Response> get({required String endPoint, bool sendToken = false, dynamic data, dynamic query}) async {
    _dio.options.headers = {
      "Accept": "*/*",
      "Content-Type": "application/json",
      if (sendToken) "Authorization": await CacheKeysManger.getToken(),
    };
    var response = await _dio.get(
      '${EndPoints.baseUrl}$endPoint',
      queryParameters: {"lang": CacheKeysManger.getUserLanguage(), if (query != null) ...query},
      data: data,
    );
    return response;
  }

  Future<Response> putData({required String endPoint, dynamic data, Map<String, dynamic>? query}) async {
    _dio.options.headers = {
      "accept": "*/*",
      "Content-Type": "application/json",
      "Authorization": await CacheKeysManger.getToken(),
    };
    var response = await _dio.put(
      '${EndPoints.baseUrl}$endPoint',
      data: data,
      queryParameters: {"lang": CacheKeysManger.getUserLanguage(), if (query != null) ...query},
    );
    return response;
  }

  Future<Response> deleteData({
    required String endPoint,
    bool sendToken = false,
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    _dio.options.headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (sendToken) "Authorization": await CacheKeysManger.getToken(),
    };
    var response = await _dio.delete(
      "${EndPoints.baseUrl}$endPoint",
      data: data,
      queryParameters: {"lang": CacheKeysManger.getUserLanguage(), if (query != null) ...query},
    );
    return response;
  }
}
