import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/api_keys.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase ─────────────────────────────────────────────────────────────
  await Supabase.initialize(
    url:     ApiKeys.supabaseUrl,
    anonKey: ApiKeys.supabaseAnon,
  );

  // ── Android Maps renderer ─────────────────────────────────────────────────
  if (defaultTargetPlatform == TargetPlatform.android) {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is GoogleMapsFlutterAndroid) {
      await impl.initializeWithRenderer(AndroidMapRenderer.latest);
    }
  }

  runApp(const ProviderScope(child: App()));
}
