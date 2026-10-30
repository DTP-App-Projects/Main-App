import 'dart:math';

import '../utils/services/local_services/cache_helper.dart';

/// A stable per-install UUID, sent as `X-Device-Id` on every request.
///
/// The backend stores it as legal evidence next to every acceptance
/// (`DeviceFingerprint::from`), so it must survive restarts and logouts and
/// only change when the app is reinstalled.
class DeviceIdentity {
  DeviceIdentity._();

  static const _key = 'tajer_device_id';

  static String? _id;

  /// `null` until [ensure] has run — the interceptor then sends nothing rather
  /// than a value that would change on the next start.
  static String? get id => _id;

  /// Reads the persisted id, minting one on first launch. Needs
  /// `CacheHelper.init()` to have run.
  static Future<String> ensure() async {
    final existing = _id ?? CacheHelper.getData(key: _key);
    if (existing is String && existing.isNotEmpty) {
      _id = existing;
      return existing;
    }
    final minted = uuidV4();
    await CacheHelper.saveData(key: _key, value: minted);
    _id = minted;
    return minted;
  }

  /// RFC 4122 version-4 UUID from a CSPRNG.
  static String uuidV4([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
