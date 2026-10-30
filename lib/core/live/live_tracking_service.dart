import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/trade/live_tracking.dart';

/// How an attempt to follow the driver ended.
enum LiveFailure {
  /// The grant was refused — sign-in rejected the token, or the database
  /// denied the read. Worth one renewal.
  permissionDenied,

  /// Anything else: not configured, network, plugin. Fall back to polling.
  other,
}

/// The Firebase side of live tracking, kept out of widgets and cubits.
///
/// **Every Firebase call is wrapped**: whatever goes wrong surfaces as a
/// [LiveFailure] and the caller carries on polling. The Firebase Auth user
/// here exists only to read the driver's node — the app's own session is a
/// backend token and is never touched by [stop].
class LiveTrackingService {
  StreamSubscription<DatabaseEvent>? _sub;
  bool _signedIn = false;

  /// Bumped on every [listen] / [stop], so a slow sign-in that finishes after
  /// the screen moved on does not attach a stale listener.
  int _generation = 0;

  bool get isListening => _sub != null;

  /// Signs in with [session]'s token and follows its node.
  ///
  /// [onPosition] gets `null` when the node is empty (the driver is not
  /// sharing). [onFailure] is called at most once per [listen], for a failure
  /// to start or for the listener dying later.
  Future<void> listen(
    LiveSession session, {
    required void Function(LivePosition? position) onPosition,
    required void Function(LiveFailure failure) onFailure,
  }) async {
    final generation = ++_generation;
    await _cancel();

    try {
      await FirebaseAuth.instance.signInWithCustomToken(session.token);
      _signedIn = true;
      if (generation != _generation) return;

      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: session.databaseUrl,
      );
      _sub = database.ref(session.path).onValue.listen(
        (event) {
          if (generation != _generation) return;
          onPosition(LivePosition.tryParse(event.snapshot.value));
        },
        onError: (Object error) {
          debugPrint('Live tracking listener failed: $error');
          if (generation != _generation) return;
          _sub = null;
          onFailure(_classify(error));
        },
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('Live tracking could not start: $error');
      await _cancel();
      if (generation == _generation) onFailure(_classify(error));
    }
  }

  /// Stops following. [signOut] drops the Firebase Auth user as well — only
  /// Firebase's; the backend session is not involved.
  Future<void> stop({bool signOut = false}) async {
    _generation++;
    await _cancel();
    if (!signOut || !_signedIn) return;
    _signedIn = false;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Live tracking sign-out failed: $error');
    }
  }

  Future<void> _cancel() async {
    final sub = _sub;
    _sub = null;
    try {
      await sub?.cancel();
    } catch (error) {
      debugPrint('Live tracking cancel failed: $error');
    }
  }

  static LiveFailure _classify(Object error) {
    if (error is FirebaseAuthException) {
      // A dead network is not the token's fault.
      return error.code == 'network-request-failed'
          ? LiveFailure.other
          : LiveFailure.permissionDenied;
    }
    final text = error is FirebaseException
        ? '${error.code} ${error.message ?? ''}'
        : error.toString();
    final lower = text.toLowerCase();
    return (lower.contains('permission') || lower.contains('denied'))
        ? LiveFailure.permissionDenied
        : LiveFailure.other;
  }
}
