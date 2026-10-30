import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/live/live_tracking_service.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/push/driver_trip_events.dart';
import '../../../../core/ui/paged_cubit.dart';
import '../../../../core/workspace/workspace.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/models/trade/live_tracking.dart';
import '../../../../data/repositories/shipments_repository.dart';

/// Incoming shipments. `?role=trader` is always sent — without it a hybrid
/// organization sees its own outbound deliveries in the same list.
class ShipmentsCubit extends PagedCubit<DeliveryNote> {
  final ShipmentsRepository _repo;
  final Workspace role;

  Set<String> statuses = {};

  ShipmentsCubit(this._repo, {this.role = Workspace.trader});

  @override
  Future<ApiResult<Paged<DeliveryNote>>> fetchPage(int page) =>
      _repo.deliveryNotes(role: role, page: page, statuses: statuses.toList());

  Future<void> toggleStatus(String status) => applyFilter(() {
        if (!statuses.remove(status)) statuses.add(status);
      });

  Future<void> clearStatuses() => applyFilter(statuses.clear);
}

@immutable
class TrackingState {
  final bool loading;
  final DeliveryNote? note;
  final String? errorMessage;
  final bool offline;

  /// True while the screen is polling, so the UI can say "live".
  final bool live;

  /// The handoff code as a push delivered it — only a stand-in until the
  /// tracking snapshot has loaded.
  final ReceiverOtp? pushOtp;

  /// True while the Firebase listener is attached: the driver's position
  /// then comes from [livePosition] and the poll slows down.
  final bool following;

  /// The last position the driver shared. Kept when the node goes empty, so
  /// the marker stays where it was last seen.
  final LivePosition? livePosition;

  /// False when the driver's node is empty: they are not sharing right now.
  final bool driverSharing;

  const TrackingState({
    this.loading = true,
    this.note,
    this.errorMessage,
    this.offline = false,
    this.live = false,
    this.pushOtp,
    this.following = false,
    this.livePosition,
    this.driverSharing = true,
  });

  /// The server's answer wins, including its `null` once the code is used or
  /// the driver has left; the push's code only fills the gap before it.
  ReceiverOtp? get handoffOtp {
    final loaded = note;
    if (loaded != null) return loaded.receiverOtp;
    final pushed = pushOtp;
    return (pushed == null || pushed.isExpired) ? null : pushed;
  }

  TrackingState copyWith({
    bool? loading,
    DeliveryNote? note,
    String? errorMessage,
    bool? offline,
    bool? live,
    ReceiverOtp? pushOtp,
    bool? following,
    LivePosition? livePosition,
    bool? driverSharing,
    bool clearError = false,
  }) =>
      TrackingState(
        loading: loading ?? this.loading,
        note: note ?? this.note,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        live: live ?? this.live,
        pushOtp: pushOtp ?? this.pushOtp,
        following: following ?? this.following,
        livePosition: livePosition ?? this.livePosition,
        driverSharing: driverSharing ?? this.driverSharing,
      );
}

/// Live tracking for one delivery.
///
/// **Polling is bounded and cancelled on dispose**: 5 s while the screen is
/// visible, 30 s once it is backgrounded, and stopped entirely once the
/// shipment is no longer moving. The whole app shares a 60 requests/minute
/// budget.
///
/// When the snapshot carries a `live` grant, the driver's position streams
/// from Firebase instead and the poll drops to every 2 minutes (it still
/// feeds status, ETA and the handoff code). Any Firebase failure falls back
/// to the plain poll.
class TrackingCubit extends Cubit<TrackingState> {
  static const foregroundInterval = Duration(seconds: 5);
  static const backgroundInterval = Duration(seconds: 30);
  static const followingInterval = Duration(minutes: 2);

  /// Renew the grant this long before it runs out.
  static const renewLead = Duration(minutes: 5);

  /// How long to leave Firebase alone after giving up on it.
  static const liveBackoff = Duration(minutes: 5);

  final ShipmentsRepository _repo;
  final int deliveryNoteId;
  final LiveTrackingService _live;

  Timer? _timer;
  bool _foreground = true;
  StreamSubscription<DriverTripPush>? _tripSub;
  void Function()? _unwatch;

  LiveSession? _liveSession;
  Timer? _renewTimer;
  DateTime? _liveBackoffUntil;

  /// Set when a permission error triggered a renewal; a second denial before
  /// any event arrives gives up instead of looping.
  bool _renewedAfterDenial = false;

  TrackingCubit(
    this._repo,
    this.deliveryNoteId, {
    DriverTripEvents? driverTrips,
    LiveTrackingService? live,
  })  : _live = live ?? LiveTrackingService(),
        super(TrackingState(
          pushOtp: driverTrips?.latestOtpFor(deliveryNoteId: deliveryNoteId),
        )) {
    final trips = driverTrips;
    if (trips == null) return;
    _unwatch = trips.watch(_owns);
    _tripSub = trips.stream.where(_owns).listen(_onDriverTrip);
  }

  /// A push belongs here when it names this delivery, or — lacking that —
  /// this delivery's route stop.
  bool _owns(DriverTripPush push) {
    if (push.deliveryNoteId != null) return push.deliveryNoteId == deliveryNoteId;
    final stop = state.note?.routeStop?.id;
    return stop != null && push.routeStopId == stop;
  }

  /// The driver is at the door or resent the code: show it now, then let the
  /// snapshot confirm it.
  void _onDriverTrip(DriverTripPush push) {
    if (isClosed) return;
    final otp = push.otp;
    if (otp != null) emit(state.copyWith(pushOtp: otp));
    unawaited(refresh());
  }

  Future<void> start() async {
    await _fetch(initial: true);
    _schedule();
  }

  /// Called when the app goes to the background or comes back.
  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _schedule();
  }

  Future<void> refresh() => _fetch(initial: false);

  Future<void> _fetch({required bool initial, bool renewLive = false}) async {
    if (initial) emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.tracking(deliveryNoteId);
    if (isClosed) return;

    if (result case Ok(:final data)) {
      emit(state.copyWith(loading: false, note: data, clearError: true, offline: false));
      await _syncLive(data.live, renew: renewLive);
      if (isClosed) return;
      // A delivered or cancelled shipment will not change again.
      if (!data.isInTransit) {
        if (_liveSession != null) await _stopLive(signOut: true);
        if (isClosed) return;
        _stop();
      }
      return;
    }
    // A failed renewal keeps the current listener and tries again shortly.
    if (renewLive && _liveSession != null) {
      _renewTimer?.cancel();
      _renewTimer = Timer(const Duration(minutes: 1), _renew);
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
      // Losing connectivity should not spin the poller; it resumes on retry.
      live: false,
    ));
    if (result.isOffline) _stop();
  }

  void _schedule() {
    _timer?.cancel();
    final note = state.note;
    if (note != null && !note.isInTransit) {
      emit(state.copyWith(live: false));
      return;
    }
    emit(state.copyWith(live: true));
    final interval = state.following
        ? followingInterval
        : (_foreground ? foregroundInterval : backgroundInterval);
    _timer = Timer.periodic(interval, (_) => _fetch(initial: false));
  }

  // ------------------------------------------------------------ live (RTDB)

  /// Follows, re-attaches or stops according to the snapshot's `live` block.
  /// [renew] forces a fresh sign-in with the new token.
  Future<void> _syncLive(LiveSession? session, {bool renew = false}) async {
    if (session == null) {
      // Nothing to follow any more (delivered, or not configured). The
      // snapshot that said so has just been emitted, so the screen already
      // shows the new state.
      if (_liveSession != null || state.following) await _stopLive(signOut: true);
      return;
    }

    final backoff = _liveBackoffUntil;
    if (!renew && backoff != null && DateTime.now().isBefore(backoff)) return;

    final current = _liveSession;
    // A snapshot may carry a fresh token every time; while the same node is
    // being followed, only a renewal signs in again.
    if (!renew &&
        current != null &&
        current.path == session.path &&
        current.databaseUrl == session.databaseUrl &&
        current.uid == session.uid) {
      return;
    }

    _liveSession = session;
    _scheduleRenewal(session);
    if (!state.following) {
      emit(state.copyWith(following: true, driverSharing: true));
      if (_timer != null) _schedule();
    }
    await _live.listen(session, onPosition: _onLivePosition, onFailure: _onLiveFailure);
  }

  void _onLivePosition(LivePosition? position) {
    if (isClosed) return;
    // Any event at all means the grant works.
    _renewedAfterDenial = false;
    if (position == null) {
      emit(state.copyWith(driverSharing: false));
    } else {
      emit(state.copyWith(livePosition: position, driverSharing: true));
    }
  }

  void _onLiveFailure(LiveFailure failure) {
    if (isClosed) return;
    if (failure == LiveFailure.permissionDenied && !_renewedAfterDenial) {
      _renewedAfterDenial = true;
      unawaited(_renew());
      return;
    }
    // Denied again right after a renewal, or a failure a renewal cannot fix:
    // back to the plain poll for a while.
    _liveBackoffUntil = DateTime.now().add(liveBackoff);
    _renewedAfterDenial = false;
    unawaited(_stopLive(signOut: true));
  }

  Future<void> _renew() async {
    if (isClosed) return;
    await _fetch(initial: false, renewLive: true);
  }

  void _scheduleRenewal(LiveSession session) {
    _renewTimer?.cancel();
    _renewTimer = null;
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;
    var delay = expiresAt.difference(DateTime.now()) - renewLead;
    if (delay < const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _renewTimer = Timer(delay, _renew);
  }

  Future<void> _stopLive({required bool signOut}) async {
    _renewTimer?.cancel();
    _renewTimer = null;
    _liveSession = null;
    await _live.stop(signOut: signOut);
    if (isClosed || !state.following) return;
    emit(state.copyWith(following: false));
    // Back to the normal cadence, unless polling had already stopped.
    if (_timer != null) _schedule();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (!isClosed) emit(state.copyWith(live: false));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    _renewTimer?.cancel();
    _renewTimer = null;
    _liveSession = null;
    unawaited(_live.stop(signOut: true));
    _unwatch?.call();
    _tripSub?.cancel();
    return super.close();
  }
}
