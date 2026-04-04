import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // <-- Added Geolocator import

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

  final _completer = Completer<GoogleMapController>();
  final _dio = Dio();

  Future<GoogleMapController> get _ctrl => _completer.future;

  void onMapCreated(GoogleMapController controller) {
    if (!_completer.isCompleted) _completer.complete(controller);
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

  // ── NEW: Go to My Location ────────────────────────────────────────────────
  Future<void> goToMyLocation() async {
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return;
      }

      // 2. Request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      // 3. Get the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Move the map camera
      final ctrl = await _ctrl;
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17.5, // Zooms in close to the user's street level
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> toggle3D() async {
    final ctrl = await _ctrl;
    final next = !state.is3D;
    final cam = state.currentCamera;

    // Switch between satellite (hybrid) and standard map — flat view so
    // satellite imagery is fully visible without building occlusion.
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
        CameraPosition(
          target: cam.target,
          zoom: cam.zoom,
          tilt: 0.0,
          bearing: 0.0,
        ),
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
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 14),
        ),
      );
      state = state.copyWith(isSearching: false);
      return null;
    } catch (_) {
      state = state.copyWith(isSearching: false);
      return 'Search failed. Check your connection.';
    }
  }

  // ── Household select + routing ────────────────────────────────────────────

  Future<void> selectHousehold(Household? h, {List<Asset>? assets}) async {
    if (h == null) {
      state = state.copyWith(
        clearSelected: true,
        clearPolylines: true,
        clearNearestAsset: true,
        clearRouteDistance: true,
      );
      return;
    }

    state = state.copyWith(selected: h);
    final ctrl = await _ctrl;
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(h.latitude, h.longitude), zoom: 15.5),
      ),
    );

    if (assets != null && assets.isNotEmpty) {
      await loadRoute(h, assets);
    }
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
      final origin = '${nearest.asset.latitude},${nearest.asset.longitude}';
      final destination = '${h.latitude},${h.longitude}';
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': origin,
          'destination': destination,
          'key': ApiKeys.googleMaps,
          'mode': 'driving',
        },
      );

      final routes = response.data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final encoded = routes[0]['overview_polyline']['points'] as String;
        final points = decodePolyline(encoded);

        // Use actual driving distance from API
        final legs = routes[0]['legs'] as List?;
        double? routeMeters;
        if (legs != null && legs.isNotEmpty) {
          routeMeters =
              (legs[0]['distance']['value'] as int).toDouble();
        }

        final polyline = Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF1A73E8),
          width: 4,
          patterns: [],
        );

        state = state.copyWith(
          isRouting: false,
          polylines: {polyline},
          routeDistanceMeters: routeMeters ?? nearest.distanceMeters,
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
      selected: clearSelected ? null : (selected ?? this.selected),
      is3D: is3D ?? this.is3D,
      isSearching: isSearching ?? this.isSearching,
      isRouting: isRouting ?? this.isRouting,
      currentCamera: currentCamera ?? this.currentCamera,
      mapType: mapType ?? this.mapType,
      polylines: clearPolylines ? {} : (polylines ?? this.polylines),
      nearestAsset:
          clearNearestAsset ? null : (nearestAsset ?? this.nearestAsset),
      routeDistanceMeters: clearRouteDistance
          ? null
          : (routeDistanceMeters ?? this.routeDistanceMeters),
    );
  }
}

final mapControllerProvider =
    StateNotifierProvider<MapControllerNotifier, MapControllerState>(
  (ref) => MapControllerNotifier(),
);