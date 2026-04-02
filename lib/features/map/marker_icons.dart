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
    pendingPinIcon(),                        // map-pick preview
  ]);
}

/// Dashed blue ring with filled center — used for the "pick on map" preview pin.
Future<BitmapDescriptor> pendingPinIcon({double size = 52}) async {
  const key = '__pending__';
  if (_cache.containsKey(key)) return _cache[key]!;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = size / 2;

  // Outer dashed ring (approximated with arcs)
  final dashPaint = Paint()
    ..color = const Color(0xFF58A6FF)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  const dashCount = 8;
  const gapFraction = 0.4;
  const twoPi = 6.2832;
  final dashArc = twoPi / dashCount * (1 - gapFraction);
  final gapArc  = twoPi / dashCount * gapFraction;
  double angle = 0;
  for (int i = 0; i < dashCount; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r - 4),
      angle, dashArc, false, dashPaint,
    );
    angle += dashArc + gapArc;
  }

  // Inner filled dot
  canvas.drawCircle(
    Offset(r, r),
    r * 0.32,
    Paint()..color = const Color(0xFF58A6FF),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

  final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _cache[key] = desc;
  return desc;
}
