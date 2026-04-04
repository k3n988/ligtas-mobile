import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  runApp(const ProviderScope(child: App()));
}
