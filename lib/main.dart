import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Android Maps renderer — required for mapType changes
  // (hybrid/satellite) to work correctly on Android v2.12+.
  if (defaultTargetPlatform == TargetPlatform.android) {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is GoogleMapsFlutterAndroid) {
      await impl.initializeWithRenderer(AndroidMapRenderer.latest);
    }
  }

  runApp(const ProviderScope(child: App()));
}
