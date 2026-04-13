import 'dart:math';

/// Wraps GPS acquisition. For the MVP demo, returns a randomised coordinate
/// near the selected barangay centroid so the map shows realistic spread.
/// Replace the body of [getCurrentLocation] with a real geolocator call
/// once `geolocator` is added to pubspec.yaml.
class LocationService {
  static const _baseLat = 14.5995; // Metro Manila centroid
  static const _baseLng = 120.9842;

  /// Returns [latitude, longitude]. Adds ±0.01° jitter for demo variety.
  Future<(double, double)> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 300)); // simulated delay
    final rng = Random();
    final lat = _baseLat + (rng.nextDouble() - 0.5) * 0.02;
    final lng = _baseLng + (rng.nextDouble() - 0.5) * 0.02;
    return (lat, lng);
  }
}
