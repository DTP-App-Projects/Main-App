import 'package:digital_trade_portal/core/utils/services/local_services/secure_cache_helper.dart';

import 'cache_helper.dart';

class CacheKeysManger {
  static Future<bool> saveCompleteProfile(bool value) async =>
      await CacheHelper.saveData(key: 'isCompleteProfile', value: value);

  static bool getCompleteProfile() => CacheHelper.getData(key: 'isCompleteProfile') ?? false;

  static Future<void> saveToken({required String token}) async =>
      await SecureCacheHelper.saveData(key: 'token', value: "Bearer $token");

  static Future<String> getToken() async => await SecureCacheHelper.getData(key: 'token') ?? "";

  static String getUserLanguage() => CacheHelper.getData(key: 'lang') ?? "";
}
