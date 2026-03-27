import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/triage_level.dart';

/// Cache so we only render each icon once per session.
final _cache = <String, BitmapDescriptor>{};

/// Returns a circular filled marker icon for the given [color].
/// [size] is the diameter in logical pixels (default 48).
Future<BitmapDescriptor> circularMarker(Color color, {double size = 48}) async {
  final key = '${color.toARGB32()}_$size';
  if (_cache.containsKey(key)) return _cache[key]!;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = size / 2;

  // Outer white ring
  canvas.drawCircle(
    Offset(r, r),
    r,
    Paint()..color = Colors.white,
  );

  // Coloured fill
  canvas.drawCircle(
    Offset(r, r),
    r - 3,
    Paint()..color = color,
  );

  // Inner white dot
  canvas.drawCircle(
    Offset(r, r),
    r * 0.28,
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

  final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _cache[key] = desc;
  return desc;
}

/// Convenience: returns the right marker color for a household.
Color markerColorFor(TriageLevel level, {bool rescued = false}) {
  if (rescued) return const Color(0xFF238636);
  return level.color;
}

/// Pre-warm all five triage-level icons so first render is fast.
Future<void> preloadMarkerIcons() async {
  await Future.wait([
    circularMarker(const Color(0xFFFF4D4D)), // critical
    circularMarker(const Color(0xFFF39C12)), // high
    circularMarker(const Color(0xFFF1C40F)), // elevated
    circularMarker(const Color(0xFF58A6FF)), // stable
    circularMarker(const Color(0xFF238636)), // rescued
  ]);
}
