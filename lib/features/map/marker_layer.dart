import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';

/// Builds the [Set<Marker>] passed to [GoogleMap.markers].
Set<Marker> buildHouseholdMarkers({
  required List<Household> households,
  required void Function(Household) onTap,
}) {
  return households.map((h) {
    final hue = h.isRescued ? BitmapDescriptor.hueAzure : _hue(h.triageLevel);
    return Marker(
      markerId: MarkerId(h.id),
      position: LatLng(h.latitude, h.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: h.headName,
        snippet: '${h.triageLevel.label} · ${h.barangay}',
      ),
      onTap: () => onTap(h),
    );
  }).toSet();
}

double _hue(TriageLevel level) {
  switch (level) {
    case TriageLevel.critical:
      return BitmapDescriptor.hueRed;
    case TriageLevel.high:
      return BitmapDescriptor.hueOrange;
    case TriageLevel.elevated:
      return BitmapDescriptor.hueYellow;
    case TriageLevel.stable:
      return BitmapDescriptor.hueGreen;
  }
}
