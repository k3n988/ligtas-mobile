import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../map/marker_icons.dart';

/// Full-screen map picker — user taps to place a pin, then confirms.
/// Returns a [LatLng] when confirmed, or null if cancelled.
class MapPickerSheet extends StatefulWidget {
  /// Pre-selected coordinates (e.g. previously captured GPS).
  final LatLng? initial;

  const MapPickerSheet({super.key, this.initial});

  @override
  State<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<MapPickerSheet> {
  static const _center = LatLng(10.6765, 122.9509);

  final _completer = Completer<GoogleMapController>();
  LatLng? _picked;
  BitmapDescriptor? _pinIcon;
  bool _iconReady = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    pendingPinIcon().then((icon) {
      if (mounted) setState(() { _pinIcon = icon; _iconReady = true; });
    });
  }

  void _onTap(LatLng pos) => setState(() => _picked = pos);

  Future<void> _goToInitial() async {
    if (widget.initial == null) return;
    final ctrl = await _completer.future;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.initial!, zoom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg   = Color(0xFF0A1628);
    const blue = Color(0xFF0288D1);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initial ?? _center,
              zoom: widget.initial != null ? 16.0 : 13.5,
            ),
            onMapCreated: (c) {
              _completer.complete(c);
              _goToInitial();
            },
            onTap: _onTap,
            markers: _iconReady && _picked != null
                ? {
                    Marker(
                      markerId: const MarkerId('pick'),
                      position: _picked!,
                      icon: _pinIcon!,
                      infoWindow: const InfoWindow(
                          title: 'Household location'),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            style: _cleanStyle,
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  // Close
                  _CircleBtn(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  // Banner
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _picked != null ? blue : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8),
                        ],
                      ),
                      child: Text(
                        _picked != null
                            ? '📍 ${_picked!.latitude.toStringAsFixed(5)}, '
                              '${_picked!.longitude.toStringAsFixed(5)}'
                            : 'Tap the map to pin the household location',
                        style: TextStyle(
                          color: _picked != null
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── My-location button ───────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 100,
            child: _CircleBtn(
              icon: Icons.my_location,
              onTap: () async {
                final ctrl = await _completer.future;
                ctrl.animateCamera(
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(target: _center, zoom: 14),
                  ),
                );
              },
            ),
          ),

          // ── Confirm button ───────────────────────────────────────────────
          Positioned(
            left: 20, right: 20, bottom: 28,
            child: SafeArea(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _picked != null ? blue : const Color(0xFF1C2B3A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed:
                      _picked != null ? () => Navigator.pop(context, _picked) : null,
                  child: Text(
                    _picked != null
                        ? 'Confirm Location'
                        : 'Tap the map first',
                    style: TextStyle(
                      color: _picked != null ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

const String _cleanStyle = '''
[
  { "featureType": "poi",            "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.business",   "stylers": [{ "visibility": "off" }] },
  { "featureType": "transit",        "stylers": [{ "visibility": "off" }] }
]
''';
