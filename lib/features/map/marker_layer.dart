import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import 'marker_icons.dart';

/// Builds household [Marker]s using pre-loaded circular icons.
/// Falls back to default hue markers while icons are loading.
Future<Set<Marker>> buildHouseholdMarkersAsync({
  required List<Household> households,
  required void Function(Household) onTap,
}) async {
  final markers = <Marker>{};
  for (final h in households) {
    final color = markerColorFor(h.triageLevel, rescued: h.isRescued);
    final icon = await circularMarker(color);
    markers.add(Marker(
      markerId: MarkerId(h.id),
      position: LatLng(h.latitude, h.longitude),
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      onTap: () => onTap(h),
    ));
  }
  return markers;
}

/// Builds asset [Marker]s using the asset's emoji icon rendered as a text label.
/// These are informational only — no tap needed.
Set<Marker> buildAssetMarkers(List<Asset> assets) {
  return assets.map((a) {
    return Marker(
      markerId: MarkerId('asset_${a.id}'),
      position: LatLng(a.latitude, a.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: '${a.icon} ${a.name}',
        snippet: a.unit,
      ),
      alpha: 0.85,
    );
  }).toSet();
}
