import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../core/ui/ui.dart';
import '../../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../../data/models/common/branch.dart';
import '../../../../../../data/repositories/places_repository.dart';

/// «موقع الفرع على الخريطة» (guide Part 5.1), the way the website's branch
/// form does it: search a place or paste a map link, use the current
/// location, tap the map or drag the pin, or clear it. Optional — a branch
/// can be saved without a pin.
///
/// [onChanged] gets both coordinates or both `null`; the form sends exactly
/// that, since omitting them keeps the old pin on the server.
class BranchLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final void Function(double? lat, double? lng) onChanged;

  /// Filled from the pin's address, but only while it is empty.
  final TextEditingController? addressController;

  /// The server's `latitude` / `longitude` message.
  final String? error;

  const BranchLocationPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.onChanged,
    this.addressController,
    this.error,
  });

  @override
  State<BranchLocationPicker> createState() => _BranchLocationPickerState();
}

class _BranchLocationPickerState extends State<BranchLocationPicker> {
  /// Riyadh at country zoom, when the branch has no pin yet — the website's
  /// fallback (there are no city coordinates to center on).
  static const _fallback = LatLng(24.7136, 46.6753);
  static const _fallbackZoom = 6.0;
  static const _pinZoom = 16.0;

  final _places = getIt<PlacesRepository>();
  final _search = TextEditingController();
  late final _lat = TextEditingController(text: _fmt(_pin?.latitude));
  late final _lng = TextEditingController(text: _fmt(_pin?.longitude));

  late LatLng? _pin = BranchPin.isValid(widget.initialLat, widget.initialLng)
      ? LatLng(widget.initialLat!, widget.initialLng!)
      : null;
  GoogleMapController? _map;

  Timer? _searchDebounce;
  Timer? _reverseDebounce;

  /// Drops answers to searches the user has already typed past.
  int _searchSeq = 0;
  bool _searching = false;
  bool _searchFailed = false;
  List<Place>? _results;

  bool _locating = false;
  String? _notice;
  bool _manualInvalid = false;

  String get _language => context.locale.languageCode;

  static String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(6);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _search.dispose();
    _lat.dispose();
    _lng.dispose();
    _map?.dispose();
    super.dispose();
  }

  /// Every way of moving the pin ends here. [fillAddress] is false only for
  /// typed coordinates, as on the website.
  void _setPin(
    LatLng? point, {
    bool moveCamera = false,
    bool fillAddress = true,
    bool syncFields = true,
  }) {
    setState(() {
      _pin = point;
      _notice = null;
      _manualInvalid = false;
      if (syncFields) {
        _lat.text = _fmt(point?.latitude);
        _lng.text = _fmt(point?.longitude);
      }
    });
    widget.onChanged(point?.latitude, point?.longitude);
    if (point == null) return;
    if (moveCamera) _map?.animateCamera(CameraUpdate.newLatLngZoom(point, _pinZoom));
    if (fillAddress) _scheduleReverse(point);
  }

  /// Fills an empty address after 400 ms; never overwrites typed text.
  void _scheduleReverse(LatLng point) {
    final address = widget.addressController;
    if (address == null || address.text.trim().isNotEmpty) return;
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 400), () async {
      final name = await _places.reverse(point.latitude, point.longitude, language: _language);
      if (!mounted || name == null || address.text.trim().isNotEmpty || _pin != point) return;
      address.text = name;
    });
  }

  // ------------------------------------------------------------------ search

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () => _runSearch(text.trim()));
  }

  Future<void> _runSearch(String text) async {
    final seq = ++_searchSeq;
    if (text.isEmpty) {
      setState(() => _resetSearch());
      return;
    }

    // Coordinates or a map link jump straight there — no search.
    final parsed = BranchPin.parse(text);
    if (parsed != null) {
      setState(() => _resetSearch());
      _setPin(LatLng(parsed.lat, parsed.lng), moveCamera: true);
      return;
    }

    setState(() {
      _searching = true;
      _searchFailed = false;
      _results = null;
    });

    // A short share link carries no coordinates until its redirect lands.
    if (BranchPin.isShortLink(text)) {
      final resolved = await _places.resolveLink(text);
      if (!mounted || seq != _searchSeq) return;
      final pin = resolved == null ? null : BranchPin.parse(resolved);
      setState(() {
        _searching = false;
        _results = pin == null ? const [] : null;
      });
      if (pin != null) _setPin(LatLng(pin.lat, pin.lng), moveCamera: true);
      return;
    }

    final results = await _places.search(text, language: _language, viewbox: await _viewbox());
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _searching = false;
      _searchFailed = results == null;
      _results = results;
    });
  }

  void _resetSearch() {
    _searching = false;
    _searchFailed = false;
    _results = null;
  }

  /// The visible map padded by half its size on each side, so nearby places
  /// rank first: `west,north,east,south`.
  Future<String?> _viewbox() async {
    final map = _map;
    if (map == null) return null;
    try {
      final bounds = await map.getVisibleRegion();
      final padLat = (bounds.northeast.latitude - bounds.southwest.latitude).abs() / 2;
      final padLng = (bounds.northeast.longitude - bounds.southwest.longitude).abs() / 2;
      double clamp(double v, double max) => v.clamp(-max, max).toDouble();
      return [
        clamp(bounds.southwest.longitude - padLng, 180),
        clamp(bounds.northeast.latitude + padLat, 90),
        clamp(bounds.northeast.longitude + padLng, 180),
        clamp(bounds.southwest.latitude - padLat, 90),
      ].map((v) => v.toStringAsFixed(5)).join(',');
    } catch (_) {
      return null;
    }
  }

  void _pick(Place place) {
    FocusScope.of(context).unfocus();
    setState(() => _resetSearch());
    _setPin(LatLng(place.lat, place.lng), moveCamera: true);
  }

  // -------------------------------------------------------------- my location

  /// Permission is asked here, on tap — never when the form opens.
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _notice = null;
    });
    LatLng? point;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          point = LatLng(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      point = null;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (point == null) _notice = 'branch.map_geo_denied'.tr();
    });
    if (point != null) _setPin(point, moveCamera: true);
  }

  // ------------------------------------------------------------ manual entry

  void _onManualChanged(String _) {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (!BranchPin.isValid(lat, lng)) {
      setState(() => _manualInvalid = _lat.text.trim().isNotEmpty || _lng.text.trim().isNotEmpty);
      return;
    }
    _setPin(LatLng(lat!, lng!), moveCamera: true, fillAddress: false, syncFields: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final pin = _pin;
    final small = theme.textTheme.bodySmall?.copyWith(color: t.textSecondary);
    final results = _results;

    return AppFieldShell(
      label: 'branch.location'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: _search,
            label: 'branch.map_search'.tr(),
            icon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.url,
            onChanged: _onSearchChanged,
          ),
          if (_searching)
            _SearchLine(text: 'branch.map_searching'.tr(), busy: true)
          else if (_searchFailed)
            _SearchLine(text: 'branch.map_failed'.tr(), color: t.fieldError)
          else if (results != null && results.isEmpty)
            _SearchLine(text: 'branch.map_none'.tr())
          else if (results != null)
            AppCard(
              padding: EdgeInsetsDirectional.zero,
              child: Column(
                children: [
                  for (final place in results)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.place_outlined, color: t.iconMuted),
                      title: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _pick(place),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: AppTokens.mdRadius,
            child: SizedBox(
              height: 320,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pin ?? _fallback,
                  zoom: pin == null ? _fallbackZoom : _pinZoom,
                ),
                onMapCreated: (controller) => _map = controller,
                onTap: _setPin,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                // Inside the scrolling editor sheet, panning the map must
                // not scroll (or drag down) the sheet.
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
                },
                markers: {
                  if (pin != null)
                    Marker(
                      markerId: const MarkerId('branch'),
                      position: pin,
                      draggable: true,
                      onDragEnd: _setPin,
                    ),
                },
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          Text(pin == null ? 'branch.map_empty'.tr() : 'branch.location_hint'.tr(), style: small),
          if (pin != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: t.primary),
                  const SizedBox(width: AppTokens.space1),
                  // Coordinates stay LTR, even in Arabic.
                  Text(
                    '${_fmt(pin.latitude)}, ${_fmt(pin.longitude)}',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
              child: Text(widget.error!, style: TextStyle(color: t.fieldError, fontSize: 12)),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppTokens.space1),
              child: Text(_notice!, style: TextStyle(color: t.fieldError, fontSize: 12)),
            ),
          Wrap(
            spacing: AppTokens.space2,
            children: [
              AppButton.text(
                label: 'branch.map_locate'.tr(),
                icon: Icons.my_location_rounded,
                busy: _locating,
                onPressed: _locating ? null : _locate,
              ),
              if (pin != null)
                AppButton.text(
                  label: 'branch.map_clear'.tr(),
                  icon: Icons.location_off_outlined,
                  onPressed: () => _setPin(null),
                ),
              if (pin != null)
                AppButton.text(
                  label: 'branch.map_open'.tr(),
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => launchUrl(
                    Uri.parse(BranchPin.mapsUrl(pin.latitude, pin.longitude)),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('branch.map_manual'.tr(), style: theme.textTheme.bodyMedium),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _lat,
                        label: 'branch.latitude'.tr(),
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: _onManualChanged,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppField(
                        controller: _lng,
                        label: 'branch.longitude'.tr(),
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: _onManualChanged,
                      ),
                    ),
                  ],
                ),
                if (_manualInvalid)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'branch.location_invalid'.tr(),
                      style: TextStyle(color: t.fieldError, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Searching…", "No results" or the failure, under the search box.
class _SearchLine extends StatelessWidget {
  final String text;
  final bool busy;
  final Color? color;

  const _SearchLine({required this.text, this.busy = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: color ?? context.tokens.textSecondary);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
      child: Row(
        children: [
          if (busy) ...[
            const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppTokens.space2),
          ],
          Flexible(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
