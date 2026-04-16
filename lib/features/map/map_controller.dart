import 'dart:async';
import 'dart:math' show min, max;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/api_keys.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/utils/map_utils.dart';

const _defaultCamera = CameraPosition(
  target: LatLng(10.6765, 122.9509),
  zoom: 13.5,
);

class MapControllerNotifier extends StateNotifier<MapControllerState> {
  MapControllerNotifier()
      : super(MapControllerState(
          selected: null,
          is3D: false,
          isSearching: false,
          isRouting: false,
          currentCamera: _defaultCamera,
          polylines: {},
          nearestAsset: null,
          routeDistanceMeters: null,
        ));

  // Non-final so it can be reset when a new GoogleMap widget is mounted
  // (e.g. navigating away from /rescuer and back creates a fresh controller).
  Completer<GoogleMapController> _completer = Completer<GoogleMapController>();
  final _dio = Dio();

  Future<GoogleMapController> get _ctrl => _completer.future;

  void onMapCreated(GoogleMapController controller) {
    if (_completer.isCompleted) {
      _completer = Completer<GoogleMapController>();
    }
    _completer.complete(controller);
  }

  void onCameraMove(CameraPosition position) {
    state = state.copyWith(currentCamera: position);
  }

  // ── Camera controls ───────────────────────────────────────────────────────

  Future<void> zoomIn() async {
    final ctrl = await _ctrl;
    ctrl.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> zoomOut() async {
    final ctrl = await _ctrl;
    ctrl.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> animateTo(LatLng target, {double zoom = 12}) async {
    final ctrl = await _ctrl;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)),
    );
  }

  // ── Go to My Location ─────────────────────────────────────────────────────

  Future<void> goToMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final ctrl = await _ctrl;
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17.5,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> fitAllHouseholds(List<Household> households) async {
    if (households.isEmpty) return;

    final lats = households.map((h) => h.latitude).toList()..sort();
    final lngs = households.map((h) => h.longitude).toList()..sort();

    double percentile(List<double> sorted, double p) {
      final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
      return sorted[idx];
    }

    final bounds = LatLngBounds(
      southwest: LatLng(percentile(lats, 0.10), percentile(lngs, 0.10)),
      northeast: LatLng(percentile(lats, 0.90), percentile(lngs, 0.90)),
    );

    try {
      final ctrl = await _ctrl;
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
    } catch (e) {
      debugPrint("Error fitting bounds: $e");
    }
  }

  // ── 3D / Satellite toggle ─────────────────────────────────────────────────

  Future<void> toggle3D() async {
    final ctrl = await _ctrl;
    final next = !state.is3D;
    final cam = state.currentCamera;

    state = state.copyWith(
      is3D: next,
      mapType: next ? MapType.hybrid : MapType.normal,
    );

    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: cam.target,
          zoom: next && cam.zoom < 14 ? 14.5 : cam.zoom,
          tilt: 0.0,
          bearing: 0.0,
        ),
      ),
    );
  }

  Future<void> resetBearing() async {
    final ctrl = await _ctrl;
    state = state.copyWith(is3D: false, mapType: MapType.normal);
    final cam = state.currentCamera;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: cam.target, zoom: cam.zoom, tilt: 0.0, bearing: 0.0),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<String?> searchAndGo(String query) async {
    if (query.trim().isEmpty) return null;
    state = state.copyWith(isSearching: true);
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'address': query, 'key': ApiKeys.googleMaps},
      );
      final results = response.data['results'] as List?;
      if (results == null || results.isEmpty) {
        state = state.copyWith(isSearching: false);
        return 'No results found for "$query"';
      }
      final loc = results[0]['geometry']['location'];
      final target = LatLng(loc['lat'] as double, loc['lng'] as double);
      final ctrl = await _ctrl;
      ctrl.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 14)));
      state = state.copyWith(isSearching: false);
      return null;
    } catch (_) {
      state = state.copyWith(isSearching: false);
      return 'Search failed.';
    }
  }

  // ── Household select + routing (FIXED) ────────────────────────────────────

  Future<void> selectHousehold(Household? h, {List<Asset>? assets}) async {
    // Debug to confirm the marker tap is working
    debugPrint('Select Household: ${h?.id ?? "None"}');

    if (h == null) {
      state = state.copyWith(
        clearSelected: true,
        clearPolylines: true,
        clearNearestAsset: true,
        clearRouteDistance: true,
        is3D: false,
        mapType: MapType.normal,
      );
      return;
    }

    // Explicitly update selected state first
    state = state.copyWith(selected: h);

    final ctrl = await _ctrl;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(h.latitude, h.longitude), zoom: 16.5),
      ),
    );

    if (assets != null && assets.isNotEmpty) {
      await loadRoute(h, assets);
    }
  }

  Future<void> panToHousehold(Household h) async {
    state = state.copyWith(
      selected: h,
      is3D: true,
      mapType: MapType.hybrid,
      clearPolylines: true,
      clearNearestAsset: true,
      clearRouteDistance: true,
    );
    final ctrl = await _ctrl;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(h.latitude, h.longitude), zoom: 19.0),
      ),
    );
  }

  Future<void> selectHouseholdAndRouteFromGps(Household h) async {
    state = state.copyWith(
      selected: h,
      clearPolylines: true,
      clearNearestAsset: true,
      clearRouteDistance: true,
    );

    final ctrl = await _ctrl;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(h.latitude, h.longitude), zoom: 16.0),
      ),
    );

    // Obtain rescuer GPS — gracefully skip routing if unavailable.
    Position? pos;
    try {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      if (svcEnabled &&
          perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    } catch (_) {}

    if (pos == null) return; // No GPS — household is already selected + zoomed.

    state = state.copyWith(isRouting: true);
    final origin = LatLng(pos.latitude, pos.longitude);
    final dest   = LatLng(h.latitude, h.longitude);

    // Try Directions API first.
    bool routedViaApi = false;
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin':      '${pos.latitude},${pos.longitude}',
          'destination': '${h.latitude},${h.longitude}',
          'key':  ApiKeys.googleMaps,
          'mode': 'driving',
        },
      );

      final routes = response.data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final points = decodePolyline(
            routes[0]['overview_polyline']['points'] as String);
        final legs = routes[0]['legs'] as List?;
        final dist = legs != null
            ? (legs[0]['distance']['value'] as int).toDouble()
            : null;

        state = state.copyWith(
          isRouting: false,
          polylines: {
            Polyline(
              polylineId: const PolylineId('gps_route'),
              points: points,
              color: const Color(0xFF4CAF50),
              width: 5,
            ),
          },
          routeDistanceMeters: dist,
        );
        routedViaApi = true;
        await _fitBounds(ctrl, origin, dest);
      }
    } catch (_) {}

    // Fallback: straight-line dashed polyline when API is unavailable.
    if (!routedViaApi) {
      state = state.copyWith(
        isRouting: false,
        polylines: {
          Polyline(
            polylineId: const PolylineId('gps_route'),
            points: [origin, dest],
            color: const Color(0xFF4CAF50),
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        },
      );
      await _fitBounds(ctrl, origin, dest);
    }
  }

  Future<void> _fitBounds(
      GoogleMapController ctrl, LatLng a, LatLng b) async {
    try {
      final pad = 0.003;
      final bounds = LatLngBounds(
        southwest: LatLng(min(a.latitude, b.latitude) - pad,
            min(a.longitude, b.longitude) - pad),
        northeast: LatLng(max(a.latitude, b.latitude) + pad,
            max(a.longitude, b.longitude) + pad),
      );
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {}
  }

  Future<void> loadRoute(Household h, List<Asset> assets) async {
    final available = assets.where((a) => a.isAvailable).toList();
    if (available.isEmpty) return;

    final nearest = nearestAsset(h, available);
    if (nearest == null) return;

    state = state.copyWith(
      isRouting: true,
      nearestAsset: nearest.asset,
      routeDistanceMeters: nearest.distanceMeters,
    );

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${nearest.asset.latitude},${nearest.asset.longitude}',
          'destination': '${h.latitude},${h.longitude}',
          'key': ApiKeys.googleMaps,
          'mode': 'driving',
        },
      );

      final routes = response.data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final points = decodePolyline(routes[0]['overview_polyline']['points']);
        final legs = routes[0]['legs'] as List?;
        double? dist = legs != null ? (legs[0]['distance']['value'] as int).toDouble() : null;

        state = state.copyWith(
          isRouting: false,
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFF1A73E8),
              width: 4,
            ),
          },
          routeDistanceMeters: dist ?? nearest.distanceMeters,
        );
      } else {
        state = state.copyWith(isRouting: false);
      }
    } catch (_) {
      state = state.copyWith(isRouting: false);
    }
  }

  @override
  void dispose() {
    _ctrl.then((c) => c.dispose());
    _dio.close();
    super.dispose();
  }
}

// ── State (FIXED logic for selection) ───────────────────────────────────────

class MapControllerState {
  final Household? selected;
  final bool is3D;
  final bool isSearching;
  final bool isRouting;
  final CameraPosition currentCamera;
  final MapType mapType;
  final Set<Polyline> polylines;
  final Asset? nearestAsset;
  final double? routeDistanceMeters;

  MapControllerState({
    required this.selected,
    required this.is3D,
    required this.isSearching,
    required this.isRouting,
    required this.currentCamera,
    required this.polylines,
    required this.nearestAsset,
    required this.routeDistanceMeters,
    this.mapType = MapType.normal,
  });

  MapControllerState copyWith({
    Household? selected,
    bool clearSelected = false,
    bool? is3D,
    bool? isSearching,
    bool? isRouting,
    CameraPosition? currentCamera,
    MapType? mapType,
    Set<Polyline>? polylines,
    bool clearPolylines = false,
    Asset? nearestAsset,
    bool clearNearestAsset = false,
    double? routeDistanceMeters,
    bool clearRouteDistance = false,
  }) {
    return MapControllerState(
      // Ensure we can actually set a new selected household or nullify it
      selected: clearSelected ? null : (selected ?? this.selected),
      is3D: is3D ?? this.is3D,
      isSearching: isSearching ?? this.isSearching,
      isRouting: isRouting ?? this.isRouting,
      currentCamera: currentCamera ?? this.currentCamera,
      mapType: mapType ?? this.mapType,
      polylines: clearPolylines ? {} : (polylines ?? this.polylines),
      nearestAsset: clearNearestAsset ? null : (nearestAsset ?? this.nearestAsset),
      routeDistanceMeters: clearRouteDistance ? null : (routeDistanceMeters ?? this.routeDistanceMeters),
    );
  }
}

final mapControllerProvider =
    StateNotifierProvider<MapControllerNotifier, MapControllerState>(
  (ref) => MapControllerNotifier(),
);