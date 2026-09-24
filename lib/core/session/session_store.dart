import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../network/auth_context.dart';
import '../utils/services/local_services/cache_helper.dart';
import '../utils/services/local_services/cache_keys.dart';
import '../utils/services/local_services/secure_cache_helper.dart';
import '../workspace/workspace.dart';

/// Owns the token, the active organization and the remembered workspace.
///
/// Values are mirrored in memory so the Dio interceptor can read them without
/// awaiting secure storage on every request.
class SessionStore implements AuthContext {
  String? _jwt;
  int? _userId;
  int? _organizationId;
  String _locale = 'ar';

  @override
  String? get jwt => _jwt;

  @override
  int? get organizationId => _organizationId;

  @override
  String get locale => _locale;

  int? get userId => _userId;

  bool get hasSession => (_jwt ?? '').isNotEmpty;

  /// Call once, before the first request.
  Future<void> restore() async {
    final stored = await SecureCacheHelper.getData(key: CacheKeys.jwt);
    _jwt = (stored is String && stored.isNotEmpty) ? stored : null;
    _userId = _readInt(CacheKeys.userId);
    _organizationId = _readInt(CacheKeys.organizationId);
    final lang = CacheHelper.getData(key: CacheKeys.language);
    _locale = (lang is String && lang.isNotEmpty) ? lang : 'ar';
    CacheKeysManger.setLanguage(_locale);
  }

  Future<void> saveSession({required String jwt, required int userId}) async {
    _jwt = jwt;
    _userId = userId;
    await SecureCacheHelper.saveData(key: CacheKeys.jwt, value: jwt);
    await CacheHelper.saveData(key: CacheKeys.userId, value: userId);
  }

  /// Holds a token **in memory only**, for a flow that has to authenticate a
  /// request without signing anybody in.
  ///
  /// Password reset is the only caller: step two returns the user's real `jwt`
  /// and step three needs it on the wire. Persisting it — which is what
  /// [saveSession] does — meant that abandoning the flow at "choose a new
  /// password", or having the OS kill the app there, left a live session on
  /// disk that the next cold start restored, with the *old* password still
  /// valid. In memory it dies with the process, which is the correct lifetime
  /// for a token nobody has finished earning.
  void useEphemeralJwt(String jwt) {
    // Never over-write an earned session. `hasSession` is the wrong question
    // here: it asks only whether a token is present, and a borrowed one is —
    // so it cannot tell the two apart. A signed-in user always has a
    // `userId`; a borrowed token never does.
    if (_userId != null) return;
    _jwt = jwt;
  }

  /// Drops an [useEphemeralJwt] token. Safe to call when there is none, and
  /// deliberately does not touch persisted state.
  void clearEphemeralJwt() {
    if (_userId != null) return;
    _jwt = null;
  }

  /// Hard logout. There is no refresh flow, so this is the only recovery from
  /// a dead token.
  Future<void> clear() async {
    _jwt = null;
    _userId = null;
    _organizationId = null;
    await SecureCacheHelper.removeData(key: CacheKeys.jwt);
    await CacheHelper.removeData(key: CacheKeys.userId);
    await CacheHelper.removeData(key: CacheKeys.organizationId);
    await CacheHelper.removeData(key: CacheKeys.bootstrapCache);
  }

  Future<void> setOrganizationId(int? id) async {
    _organizationId = id;
    if (id == null) {
      await CacheHelper.removeData(key: CacheKeys.organizationId);
    } else {
      await CacheHelper.saveData(key: CacheKeys.organizationId, value: id);
    }
  }

  Future<void> setLocale(String locale) async {
    _locale = locale.isEmpty ? 'ar' : locale;
    CacheKeysManger.setLanguage(_locale);
    await CacheHelper.saveData(key: CacheKeys.language, value: _locale);
  }

  Workspace? rememberedWorkspace(int organizationId) =>
      Workspace.tryParse(CacheHelper.getData(key: CacheKeys.workspaceFor(organizationId)));

  Future<void> rememberWorkspace(int organizationId, Workspace workspace) =>
      CacheHelper.saveData(key: CacheKeys.workspaceFor(organizationId), value: workspace.api);

  /// Last known server palette for this organization and workspace.
  ThemeTokens? cachedTheme(int organizationId, Workspace workspace) {
    final raw = CacheHelper.getData(key: CacheKeys.themeFor(organizationId, workspace.api));
    if (raw is! String || raw.isEmpty) return null;
    try {
      return ThemeTokens.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
        workspace: workspace,
      );
    } catch (e) {
      debugPrint('theme cache read failed: $e');
      return null;
    }
  }

  Future<void> cacheTheme(int organizationId, Workspace workspace, ThemeTokens theme) =>
      CacheHelper.saveData(
        key: CacheKeys.themeFor(organizationId, workspace.api),
        value: jsonEncode(theme.toJson()),
      );

  String? get deviceToken {
    final value = CacheHelper.getData(key: CacheKeys.deviceToken);
    return (value is String && value.isNotEmpty) ? value : null;
  }

  Future<void> setDeviceToken(String token) =>
      CacheHelper.saveData(key: CacheKeys.deviceToken, value: token);

  static int? _readInt(String key) {
    final value = CacheHelper.getData(key: key);
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
