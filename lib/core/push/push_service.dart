import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/bootstrap/organization.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/bootstrap_repository.dart';
import '../../features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import '../deeplink/deep_link.dart';
import '../deeplink/deep_link_router.dart';
import '../session/session_store.dart';
import '../workspace/workspace.dart';

/// FCM token plumbing.
///
/// Both registrations are required: v1 writes `tokens`, v2 writes
/// `push_tokens`, and they are separate tables feeding separate senders.
class PushService {
  final AuthRepository _auth;
  final BootstrapRepository _bootstrap;
  final SessionStore _store;

  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  /// Set once the router exists — see the service locator.
  DeepLinkRouter? deepLinks;
  NotificationsCubit? notifications;

  PushService(this._auth, this._bootstrap, this._store);

  String? get token => _store.deviceToken;

  /// Fetch the device token once per cold start and keep it current.
  Future<void> initialize() async {
    final fresh = await _readToken();
    if (fresh != null) await _store.setDeviceToken(fresh);

    _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((value) async {
      await _store.setDeviceToken(value);
      await registerWithBackend();
    });
  }

  /// The three entry paths a push can take. All of them end in [openLink], so
  /// a notification behaves the same however the app was reached.
  Future<void> attachTapHandlers() async {
    // Background tap.
    _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => openLink(DeepLink.fromData(message.data)),
    );

    // Terminated cold start.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) await openLink(DeepLink.fromData(initial.data));
  }

  /// Foreground arrival: the banner is shown by the caller, the badge here.
  void onForegroundMessage(RemoteMessage message) =>
      notifications?.onPushReceived();

  Future<void> openLink(DeepLink link) async {
    final router = deepLinks;
    if (router == null) {
      debugPrint('Deep link arrived before the router was wired: ${link.clickAction}');
      return;
    }
    await router.open(link);
  }

  /// Safe to call whenever the session or the organization changes; both calls
  /// are idempotent upserts server-side.
  Future<void> registerWithBackend({Organization? workspaceHint}) async {
    if (!_store.hasSession) return;
    final value = _store.deviceToken;
    if (value == null || value.isEmpty) return;

    final variant = _appVariant(workspaceHint);
    await _auth.updateDeviceToken(fcmToken: value, appVariant: variant);
    await _bootstrap.registerPushToken(
      token: value,
      appVariant: variant,
      locale: _store.locale,
    );
  }

  /// Called on logout, while the token is still valid — the server needs an
  /// authenticated call to know which device to drop.
  Future<void> unregister() async {
    final value = _store.deviceToken;
    if (value == null || value.isEmpty) return;

    if (_store.hasSession) await _bootstrap.unregisterPushToken(value);

    // Best effort — a failed FCM delete must never block logout.
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM deleteToken failed: $e');
    }
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
    _refreshSub = null;
    _openedSub = null;
  }

  /// `owner` wins, because an owner acts across both workspaces. Otherwise the
  /// variant follows the workspace the org actually operates in.
  static String _appVariant(Organization? org) {
    if (org == null) return 'trader';
    if (org.isOwner) return 'owner';
    return org.workspaces.contains(Workspace.supplier) ? 'supplier' : 'trader';
  }

  /// On iOS the APNs token has to land before FCM will hand one over.
  Future<String?> _readToken() async {
    try {
      if (Platform.isIOS) {
        var apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null) {
          await Future<void>.delayed(const Duration(seconds: 3));
          apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null) return null;
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }
}
