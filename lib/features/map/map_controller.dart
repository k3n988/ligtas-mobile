import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/api_keys.dart';
import '../../core/models/household.dart';

const _defaultZoom = 13.5;

class MapControllerNotifier extends StateNotifier<MapControllerState> {
  MapControllerNotifier()
      : super(const MapControllerState(selected: null, is3D: false, isSearching: false));

  final _completer = Completer<GoogleMapController>();
  final _dio = Dio();

  Future<GoogleMapController> get _ctrl => _completer.future;

  void onMapCreated(GoogleMapController controller) {
    if (!_completer.isCompleted) _completer.complete(controller);
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

  Future<void> toggle3D() async {
    final ctrl = await _ctrl;
    final next = !state.is3D;
    state = state.copyWith(is3D: next);
    final pos = await ctrl.getVisibleRegion();
    final center = LatLng(
      (pos.northeast.latitude + pos.southwest.latitude) / 2,
      (pos.northeast.longitude + pos.southwest.longitude) / 2,
    );
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: 15, tilt: next ? 60 : 0, bearing: next ? 30 : 0),
      ),
    );
  }

  Future<void> resetBearing() async {
    final ctrl = await _ctrl;
    state = state.copyWith(is3D: false);
    final pos = await ctrl.getVisibleRegion();
    final center = LatLng(
      (pos.northeast.latitude + pos.southwest.latitude) / 2,
      (pos.northeast.longitude + pos.southwest.longitude) / 2,
    );
    ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: _defaultZoom, tilt: 0, bearing: 0),
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
      final target = LatLng(loc['lat'], loc['lng']);
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

  // ── Household select ──────────────────────────────────────────────────────

  Future<void> selectHousehold(Household? h) async {
    state = state.copyWith(selected: h, clearSelected: h == null);
    if (h != null) {
      final ctrl = await _ctrl;
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(h.latitude, h.longitude), zoom: 15.5),
        ),
      );
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

  const MapControllerState({
    required this.selected,
    required this.is3D,
    required this.isSearching,
  });

  MapControllerState copyWith({
    Household? selected,
    bool clearSelected = false,
    bool? is3D,
    bool? isSearching,
  }) {
    return MapControllerState(
      selected: clearSelected ? null : (selected ?? this.selected),
      is3D: is3D ?? this.is3D,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

final mapControllerProvider =
    StateNotifierProvider<MapControllerNotifier, MapControllerState>(
  (ref) => MapControllerNotifier(),
);
