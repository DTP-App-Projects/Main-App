import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCacheHelper {
  static const storage = FlutterSecureStorage();

  static Future<void> saveData({required String key, required dynamic value}) async {
    return await storage.write(key: key, value: value);
  }

  static Future getData({required String key}) async {
    return await storage.read(key: key);
  }

  static Future removeData({required String key}) async {
    return await storage.delete(key: key);
  }
}
