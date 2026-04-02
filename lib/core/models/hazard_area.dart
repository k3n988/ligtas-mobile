import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:equatable/equatable.dart';

enum DisasterType { flood, fire, landslide, storm, earthquake }

extension DisasterTypeX on DisasterType {
  String get label {
    switch (this) {
      case DisasterType.flood:      return 'Flood';
      case DisasterType.fire:       return 'Fire';
      case DisasterType.landslide:  return 'Landslide';
      case DisasterType.storm:      return 'Storm';
      case DisasterType.earthquake: return 'Earthquake';
    }
  }

  String get emoji {
    switch (this) {
      case DisasterType.flood:      return '🌊';
      case DisasterType.fire:       return '🔥';
      case DisasterType.landslide:  return '⛰';
      case DisasterType.storm:      return '🌪';
      case DisasterType.earthquake: return '⚡';
    }
  }
}

enum HazardSeverity { critical, high, elevated }

extension HazardSeverityX on HazardSeverity {
  String get label {
    switch (this) {
      case HazardSeverity.critical: return 'CRITICAL';
      case HazardSeverity.high:     return 'HIGH';
      case HazardSeverity.elevated: return 'ELEVATED';
    }
  }
}

class HazardArea extends Equatable {
  final String id;
  final String label;
  final DisasterType disasterType;
  final HazardSeverity severity;
  final List<LatLng> polygonPoints;

  const HazardArea({
    required this.id,
    required this.label,
    required this.disasterType,
    required this.severity,
    required this.polygonPoints,
  });

  @override
  List<Object?> get props => [id, label, disasterType, severity, polygonPoints];
}
