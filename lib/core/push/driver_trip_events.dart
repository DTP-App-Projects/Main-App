import 'dart:async';

import '../../data/models/trade/delivery_note.dart';
import '../network/coerce.dart';

/// A `data.type = "driver_trip"` push. The two that matter here: the fleet
/// driver is at the trader's door (`arrived`) or asked for the handoff code
/// again (`otp_code`); any other event still refreshes an open screen.
class DriverTripPush {
  static const type = 'driver_trip';

  final String event;
  final int? routeStopId;

  /// Read from `delivery_note_id`, or from `entity_id` / `click_id` when the
  /// push names a delivery note as its entity. `null` when the push does not
  /// say which delivery it belongs to.
  final int? deliveryNoteId;

  /// Only on `arrived` (when push is enabled) and `otp_code`.
  final String otpCode;
  final DateTime? otpExpiresAt;

  const DriverTripPush({
    required this.event,
    required this.routeStopId,
    required this.deliveryNoteId,
    required this.otpCode,
    required this.otpExpiresAt,
  });

  /// `null` for any push that is not a driver-trip event.
  static DriverTripPush? tryParse(Map<String, dynamic> data) {
    if (asStr(data['type']) != type) return null;
    final namesDeliveryNote = asStr(data['entity_type']) == 'delivery_note' ||
        asStr(data['click_action']) == 'delivery_note';
    return DriverTripPush(
      event: asStr(data['event']),
      routeStopId: asIntOrNull(data['route_stop_id']),
      deliveryNoteId: asIntOrNull(data['delivery_note_id']) ??
          (namesDeliveryNote ? asIntOrNull(data['entity_id'] ?? data['click_id']) : null),
      otpCode: ReceiverOtp.normalizeCode(data['otp_code']),
      otpExpiresAt: asDate(data['otp_expires_at']),
    );
  }

  /// The handoff code as the push carried it. The QR text is rebuilt locally;
  /// the tracking endpoint's `qr_payload` replaces it as soon as it loads.
  ReceiverOtp? get otp {
    final stop = routeStopId;
    if (otpCode.isEmpty || stop == null) return null;
    final value = ReceiverOtp(
      code: otpCode,
      expiresAt: otpExpiresAt,
      attemptsRemaining: null,
      qrPayload: 'TJD1:$stop:$otpCode',
    );
    return value.isExpired ? null : value;
  }
}

/// The in-app channel for driver-trip pushes.
///
/// Open tracking screens listen on [stream] and say, through [watch], which
/// pushes they own — so a tap on a push for a screen that is already open
/// refreshes it instead of stacking a second copy.
class DriverTripEvents {
  final _controller = StreamController<DriverTripPush>.broadcast();
  final _watchers = <bool Function(DriverTripPush push)>{};

  /// The last code each route stop was sent, for a screen opened by the tap.
  final _latest = <int, DriverTripPush>{};

  Stream<DriverTripPush> get stream => _controller.stream;

  void add(DriverTripPush push) {
    final stop = push.routeStopId;
    if (stop != null && push.otpCode.isNotEmpty) {
      _latest.remove(stop); // keep insertion order newest-last
      _latest[stop] = push;
    }
    _controller.add(push);
  }

  /// The freshest unexpired code pushed for [routeStopId] or [deliveryNoteId].
  ReceiverOtp? latestOtpFor({int? routeStopId, int? deliveryNoteId}) {
    for (final push in _latest.values.toList().reversed) {
      final matches = (routeStopId != null && push.routeStopId == routeStopId) ||
          (deliveryNoteId != null && push.deliveryNoteId == deliveryNoteId);
      if (matches) return push.otp;
    }
    return null;
  }

  /// Registers an open screen; call the returned function when it closes.
  void Function() watch(bool Function(DriverTripPush push) owns) {
    _watchers.add(owns);
    return () => _watchers.remove(owns);
  }

  bool isWatched(DriverTripPush push) => _watchers.any((owns) => owns(push));
}
