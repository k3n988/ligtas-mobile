import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import 'marker_icons.dart';

/// Builds household [Marker]s using pre-loaded circular icons.
Future<Set<Marker>> buildHouseholdMarkersAsync({
  required List<Household> households,
  required void Function(Household) onTap,
}) async {
  final markers = <Marker>{};
  for (final h in households) {
    // Assuming markerColorFor is defined in marker_icons.dart
    final color = markerColorFor(h.triageLevel, rescued: h.isRescued);
    final icon  = await circularMarker(color);
    markers.add(Marker(
      markerId: MarkerId(h.id),
      position: LatLng(h.latitude, h.longitude),
      icon:     icon,
      consumeTapEvents: true,
      anchor:   const Offset(0.5, 0.5),
      onTap:    () => onTap(h),
    ));
  }
  return markers;
}

/// Builds asset [Marker]s with emoji icons rendered as bitmaps.
Future<Set<Marker>> buildAssetMarkers(List<Asset> assets) async {
  final markers = <Marker>{};
  for (final a in assets) {
    // Assuming emojiMarker is defined in marker_icons.dart
    final icon = await emojiMarker(a.icon);
    markers.add(Marker(
      markerId:    MarkerId('asset_${a.id}'),
      position:    LatLng(a.latitude, a.longitude),
      icon:        icon,
      consumeTapEvents: true,
      anchor:      const Offset(0.5, 0.5),
      infoWindow:  InfoWindow(title: a.name, snippet: a.unit),
    ));
  }
  return markers;
}