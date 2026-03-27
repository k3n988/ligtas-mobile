import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/asset.dart';
import '../models/household.dart';

// ── Haversine distance (returns metres) ───────────────────────────────────────

double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;

// ── Nearest asset by straight-line distance ───────────────────────────────────

({Asset asset, double distanceMeters})? nearestAsset(
  Household h,
  List<Asset> assets,
) {
  if (assets.isEmpty) return null;
  Asset? best;
  double bestDist = double.infinity;
  for (final a in assets) {
    final d = haversineDistance(h.latitude, h.longitude, a.latitude, a.longitude);
    if (d < bestDist) {
      bestDist = d;
      best = a;
    }
  }
  return best == null ? null : (asset: best, distanceMeters: bestDist);
}

// ── Google Encoded Polyline decoder ───────────────────────────────────────────

List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

// ── Distance label helper ─────────────────────────────────────────────────────

String formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}
