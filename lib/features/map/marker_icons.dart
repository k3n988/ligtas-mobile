import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/models/triage_level.dart';

/// Renders an emoji string as a [BitmapDescriptor] for use as a map marker.
Future<BitmapDescriptor> emojiMarker(String emoji, {double size = 52}) async {
  final key = 'emoji_${emoji}_$size';
  if (_cache.containsKey(key)) return _cache[key]!;

  final recorder = ui.PictureRecorder();
  final canvas   = Canvas(recorder);
  final r = size / 2;

  // TINANGGAL: White circle background at shadow codes dito.

  // Draw emoji centred in transparent canvas
  final tp = TextPainter(
    text: TextSpan(
      text: emoji,
      // Pinalaki natin ang font size (mula 0.48 naging 0.75) 
      // para mas malaki ang mismong sasakyan dahil wala nang puting border.
      style: TextStyle(fontSize: size * 0.75), 
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  
  tp.paint(canvas, Offset(r - tp.width / 2, r - tp.height / 2));

  final picture = recorder.endRecording();
  final img     = await picture.toImage(size.toInt(), size.toInt());
  final bytes   = await img.toByteData(format: ui.ImageByteFormat.png);

  final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _cache[key] = desc;
  return desc;
}

/// Cache to ensure we only render each icon once per session.
final _cache = <String, BitmapDescriptor>{};

/// Renders a solid circular marker with a white border and shadow, 
/// matching the L.I.G.T.A.S. Web UI.
Future<BitmapDescriptor> circularMarker(Color color, {double size = 36}) async {
  final key = '${color.toARGB32()}_$size';
  if (_cache.containsKey(key)) return _cache[key]!;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = size / 2;

  // 1. Draw a subtle Drop Shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  canvas.drawCircle(Offset(r, r + 1.5), r - 1, shadowPaint);

  // 2. Draw the Outer White Border
  canvas.drawCircle(
    Offset(r, r),
    r - 1,
    Paint()..color = Colors.white,
  );

  // 3. Draw the Solid Color Fill
  // We subtract 2.5 to 3.0 from the radius to leave a clean white ring
  canvas.drawCircle(
    Offset(r, r),
    r - 3.5,
    Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

  final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _cache[key] = desc;
  return desc;
}

/// Helper to get the hex color based on Triage Level
Color markerColorFor(TriageLevel level, {bool rescued = false}) {
  if (rescued) return const Color(0xFF238636); // Green
  return level.color;
}

/// Pre-warm the icons using the specific hex codes from your web screenshot.
Future<void> preloadMarkerIcons() async {
  await Future.wait([
    circularMarker(const Color(0xFFFF4D4D)), // Critical (Red)
    circularMarker(const Color(0xFFF39C12)), // High (Orange)
    circularMarker(const Color(0xFFF1C40F)), // Elevated (Yellow)
    circularMarker(const Color(0xFF4A90E2)), // Stable (Blue)
    circularMarker(const Color(0xFF238636)), // Rescued (Green)
    pendingPinIcon(),                        // Map-pick preview
  ]);
}

/// The "Pending" icon used during registration. 
/// Updated to be a solid blue dot with a white border to match the theme.
Future<BitmapDescriptor> pendingPinIcon({double size = 40}) async {
  const key = '__pending__';
  if (_cache.containsKey(key)) return _cache[key]!;

  // We reuse the circularMarker logic for consistency, 
  // but we can give it a specific "Pending" blue.
  final descriptor = await circularMarker(const Color(0xFF58A6FF), size: size);
  
  _cache[key] = descriptor;
  return descriptor;
}