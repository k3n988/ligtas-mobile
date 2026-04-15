import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class ActiveHazard {
  final String id;
  final String type;
  final double centerLat;
  final double centerLng;
  final double radiusCritical;
  final double radiusHigh;
  final double radiusElevated;
  final double radiusStable;

  const ActiveHazard({
    required this.id,
    required this.type,
    required this.centerLat,
    required this.centerLng,
    required this.radiusCritical,
    required this.radiusHigh,
    required this.radiusElevated,
    required this.radiusStable,
  });

  factory ActiveHazard.fromJson(Map<String, dynamic> json) => ActiveHazard(
        id:             json['id'] as String,
        type:           json['type'] as String,
        centerLat:      (json['center_lat']      as num?)?.toDouble() ?? 0,
        centerLng:      (json['center_lng']      as num?)?.toDouble() ?? 0,
        radiusCritical: (json['radius_critical'] as num?)?.toDouble() ?? 1,
        radiusHigh:     (json['radius_high']     as num?)?.toDouble() ?? 3,
        radiusElevated: (json['radius_elevated'] as num?)?.toDouble() ?? 5,
        radiusStable:   (json['radius_stable']   as num?)?.toDouble() ?? 10,
      );

  Map<String, dynamic> toInsert() => {
        'type':            type,
        'center_lat':      centerLat,
        'center_lng':      centerLng,
        'radius_critical': radiusCritical,
        'radius_high':     radiusHigh,
        'radius_elevated': radiusElevated,
        'radius_stable':   radiusStable,
        'is_active':       true,
      };
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ActiveHazardsNotifier extends StateNotifier<List<ActiveHazard>> {
  ActiveHazardsNotifier() : super([]) {
    _load();
    _subscribeRealtime();
  }

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    try {
      final data = await _db
          .from('hazard_events')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      state = (data as List).map((r) => ActiveHazard.fromJson(r)).toList();
    } catch (e) {
      // keep previous state on error
    }
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('hazard_events_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hazard_events',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> activate({
    required String type,
    required double centerLat,
    required double centerLng,
    required double critical,
    required double high,
    required double elevated,
    required double stable,
  }) async {
    // Deactivate any existing hazard of same type
    await _db
        .from('hazard_events')
        .update({'is_active': false})
        .eq('is_active', true)
        .eq('type', type);

    await _db.from('hazard_events').insert({
      'type':            type,
      'center_lat':      centerLat,
      'center_lng':      centerLng,
      'radius_critical': critical,
      'radius_high':     high,
      'radius_elevated': elevated,
      'radius_stable':   stable,
      'is_active':       true,
    });

    await _load();
  }

  Future<void> clear(String type) async {
    await _db
        .from('hazard_events')
        .update({'is_active': false})
        .eq('is_active', true)
        .eq('type', type);
    await _load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final activeHazardsProvider =
    StateNotifierProvider<ActiveHazardsNotifier, List<ActiveHazard>>(
  (ref) => ActiveHazardsNotifier(),
);

// ── Hazard center picking state ───────────────────────────────────────────────

/// True while admin is in "tap map to pick hazard center" mode.
final isSelectingHazardCenterProvider = StateProvider<bool>((ref) => false);

/// Holds the tapped coords until admin confirms and activates.
final draftHazardCenterProvider =
    StateProvider<({double lat, double lng})?> ((ref) => null);
