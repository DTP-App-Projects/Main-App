import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/ui.dart';
import '../../../../data/models/trade/live_tracking.dart';

/// The driver's live position on a map, streamed from Firebase.
///
/// The truck glides between fixes over roughly the time between them and
/// turns the short way round to its heading. The camera follows it until the
/// user touches the map; the re-center button resumes following. Once the
/// last fix is over two minutes old, or the driver stops sharing, the marker
/// greys out and stays where it was last seen.
///
/// Only built while the live listener is attached.
class LiveDriverMap extends StatefulWidget {
  final LivePosition? position;

  /// False when the driver's node is empty; the last position is kept.
  final bool sharing;

  const LiveDriverMap({super.key, required this.position, required this.sharing});

  static const staleAfter = Duration(minutes: 2);
  static const mapHeight = 260.0;
  static const _zoom = 15.0;

  @override
  State<LiveDriverMap> createState() => _LiveDriverMapState();
}

class _LiveDriverMapState extends State<LiveDriverMap> with SingleTickerProviderStateMixin {
  static const _markerId = MarkerId('driver');

  late final AnimationController _glide = AnimationController(vsync: this)
    ..addListener(_onGlide);
  Timer? _ticker;
  GoogleMapController? _map;

  LatLng? _from;
  LatLng? _to;
  LatLng? _shown;

  /// Unwrapped degrees, so 350° -> 10° turns 20° rather than 340° back.
  double _headingFrom = 0;
  double _headingTo = 0;
  double _heading = 0;

  bool _following = true;

  BitmapDescriptor? _liveIcon;
  BitmapDescriptor? _staleIcon;
  double? _iconRatio;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    if (p != null) {
      _shown = _to = _from = LatLng(p.lat, p.lng);
      _heading = _headingTo = _headingFrom = p.heading ?? 0;
    }
    // "Updated Xs ago" and the stale check have to count between fixes.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (_iconRatio == ratio) return;
    _iconRatio = ratio;
    final t = context.tokens;
    unawaited(_buildIcons(ratio, live: t.primary, stale: Colors.grey.shade600));
  }

  @override
  void didUpdateWidget(covariant LiveDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.position;
    if (p == null || identical(p, oldWidget.position)) return;
    final target = LatLng(p.lat, p.lng);
    if (_shown == null) {
      _shown = _to = _from = target;
      _heading = _headingTo = _headingFrom = p.heading ?? 0;
      _follow(target, animate: false);
      return;
    }

    _from = _shown;
    _to = target;
    _headingFrom = _heading;
    final heading = p.heading;
    if (heading != null) {
      var delta = (heading - _heading) % 360;
      if (delta > 180) delta -= 360;
      _headingTo = _heading + delta;
    }

    // Glide over about as long as the gap between the two fixes.
    final previous = oldWidget.position?.at;
    final current = p.at;
    var gap = const Duration(seconds: 2);
    if (previous != null && current != null) gap = current.difference(previous);
    final ms = gap.inMilliseconds.clamp(500, 5000);
    _glide.duration = Duration(milliseconds: ms);
    _glide.forward(from: 0);
    _follow(target);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _glide.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _onGlide() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final v = Curves.easeInOut.transform(_glide.value);
    setState(() {
      _shown = LatLng(
        from.latitude + (to.latitude - from.latitude) * v,
        from.longitude + (to.longitude - from.longitude) * v,
      );
      _heading = _headingFrom + (_headingTo - _headingFrom) * v;
    });
  }

  void _follow(LatLng target, {bool animate = true}) {
    final map = _map;
    if (!_following || map == null) return;
    final update = CameraUpdate.newLatLng(target);
    // Maps failing (no key, no services) must never take the screen down.
    unawaited((animate ? map.animateCamera(update) : map.moveCamera(update)).catchError((_) {}));
  }

  void _recenter() {
    setState(() => _following = true);
    final target = _to ?? _shown;
    if (target != null) _follow(target);
  }

  /// A truck in a disc, with a pointer on top that the marker's rotation
  /// turns towards the heading. Falls back to hued default pins.
  Future<void> _buildIcons(double ratio, {required Color live, required Color stale}) async {
    try {
      final liveIcon = await _truckIcon(ratio, live);
      final staleIcon = await _truckIcon(ratio, stale);
      if (!mounted) return;
      setState(() {
        _liveIcon = liveIcon;
        _staleIcon = staleIcon;
      });
    } catch (error) {
      debugPrint('Truck marker icon failed: $error');
    }
  }

  static Future<BitmapDescriptor> _truckIcon(double ratio, Color color) async {
    const logical = 48.0;
    final size = logical * ratio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size * 0.32;

    final pointer = Path()
      ..moveTo(center.dx, size * 0.04)
      ..lineTo(center.dx - radius * 0.5, center.dy - radius * 0.8)
      ..lineTo(center.dx + radius * 0.5, center.dy - radius * 0.8)
      ..close();
    canvas.drawPath(pointer, Paint()..color = color);
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius * 0.84, Paint()..color = color);

    const icon = Icons.local_shipping_rounded;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: radius * 1.05,
          color: Colors.white,
        ),
      ),
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));

    final image = await recorder.endRecording().toImage(size.ceil(), size.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('marker encoding failed');
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      imagePixelRatio: ratio,
      bitmapScaling: MapBitmapScaling.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final position = widget.position;
    final shown = _shown;
    final at = position?.at;
    final age = at == null ? null : DateTime.now().difference(at);
    final lost = !widget.sharing || (age != null && age > LiveDriverMap.staleAfter);

    return AppCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTokens.radiusXl),
            ),
            child: SizedBox(
              height: LiveDriverMap.mapHeight,
              child: shown == null
                  ? ColoredBox(
                      color: t.neutralTint,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.all(AppTokens.space4),
                          child: Text(
                            'shipment.live_waiting'.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                          ),
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        // A touch means the user wants to look around: stop
                        // dragging the camera back to the truck.
                        Listener(
                          onPointerDown: (_) {
                            if (_following) setState(() => _following = false);
                          },
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: shown,
                              zoom: LiveDriverMap._zoom,
                            ),
                            // The map sits in a scrolling list; let it keep
                            // its own pans and pinches.
                            gestureRecognizers: {
                              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
                            },
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            zoomControlsEnabled: false,
                            compassEnabled: false,
                            onMapCreated: (controller) {
                              _map = controller;
                              final target = _to ?? _shown;
                              if (target != null) _follow(target, animate: false);
                            },
                            markers: {
                              Marker(
                                markerId: _markerId,
                                position: shown,
                                rotation: position?.heading == null ? 0 : _heading % 360,
                                flat: true,
                                anchor: const Offset(0.5, 0.5),
                                alpha: lost ? 0.5 : 1,
                                icon: (lost ? _staleIcon : _liveIcon) ??
                                    BitmapDescriptor.defaultMarkerWithHue(
                                      lost ? 0 : BitmapDescriptor.hueAzure,
                                    ),
                              ),
                            },
                          ),
                        ),
                        if (!_following)
                          PositionedDirectional(
                            end: AppTokens.space3,
                            bottom: AppTokens.space3,
                            child: FloatingActionButton.small(
                              heroTag: null,
                              tooltip: 'shipment.live_recenter'.tr(),
                              onPressed: _recenter,
                              child: const Icon(Icons.my_location_rounded),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lost) ...[
                  AppBanner(
                    message: 'shipment.live_lost'.tr(),
                    tone: AppTone.warning,
                    icon: Icons.signal_wifi_bad_outlined,
                    margin: EdgeInsetsDirectional.zero,
                  ),
                  const SizedBox(height: AppTokens.space3),
                ],
                if (age != null)
                  Text(
                    'shipment.live_updated_ago'.tr(
                      namedArgs: {'seconds': '${age.inSeconds < 0 ? 0 : age.inSeconds}'},
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                  ),
                if (position?.speedKmh != null && !lost) ...[
                  const SizedBox(height: AppTokens.space1),
                  Text(
                    'shipment.live_speed'.tr(
                      namedArgs: {'speed': position!.speedKmh!.round().toString()},
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ],
                if (position != null) ...[
                  const SizedBox(height: AppTokens.space2),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.text(
                      label: 'shipment.live_open_map'.tr(),
                      icon: Icons.open_in_new_rounded,
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://www.google.com/maps/search/?api=1'
                          '&query=${position.lat},${position.lng}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
