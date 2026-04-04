import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/household.dart';
import '../core/models/asset.dart';
import '../core/models/triage_level.dart';

final _db = Supabase.instance.client;

// ── Household ─────────────────────────────────────────────────────────────────

class HouseholdNotifier extends StateNotifier<List<Household>> {
  HouseholdNotifier() : super([]) {
    _init();
  }

  RealtimeChannel? _channel;

  Future<void> _init() async {
    await _fetch();

    // Live updates — any INSERT/UPDATE/DELETE on the table refreshes the list
    _channel = _db
        .channel('public:households')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'households',
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  Future<void> _fetch() async {
    try {
      final rows = await _db
          .from('households')
          .select()
          .order('registered_at', ascending: true);
      if (mounted) {
        state = rows.map((r) => Household.fromJson(r)).toList();
      }
    } catch (_) {
      // Keep current state on error (offline / table missing)
    }
  }

  // ── Write-through ops ─────────────────────────────────────────────────────

  Future<void> add(Household h) async {
    await _db.from('households').insert(h.toJson());
    // Realtime fires _fetch automatically
  }

  Future<void> markRescued(String id) async {
    await _db
        .from('households')
        .update({'status': HouseholdStatus.rescued.name})
        .eq('id', id);
  }

  Future<void> restorePending(String id) async {
    await _db.from('households').update({
      'status':           HouseholdStatus.pending.name,
      'assigned_asset_id': null,
      'dispatched_at':    null,
    }).eq('id', id);
  }

  Future<void> dispatchRescue(String householdId, String assetId) async {
    await _db.from('households').update({
      'assigned_asset_id': assetId,
      'dispatched_at':    DateTime.now().toIso8601String(),
    }).eq('id', householdId);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final householdProvider =
    StateNotifierProvider<HouseholdNotifier, List<Household>>(
  (ref) => HouseholdNotifier(),
);

/// Sorted queue: pending first (CRITICAL→STABLE), then rescued at bottom.
final queueProvider = Provider<List<Household>>((ref) {
  final all = ref.watch(householdProvider);
  final pending = all.where((h) => !h.isRescued).toList()
    ..sort((a, b) {
      final p = a.triageLevel.priority.compareTo(b.triageLevel.priority);
      return p != 0 ? p : a.registeredAt.compareTo(b.registeredAt);
    });
  final rescued = all.where((h) => h.isRescued).toList();
  return [...pending, ...rescued];
});

// ── Locate (pan map to household) ─────────────────────────────────────────────

final locateHouseholdProvider = StateProvider<String?>((ref) => null);

// ── Asset ─────────────────────────────────────────────────────────────────────

class AssetNotifier extends StateNotifier<List<Asset>> {
  AssetNotifier() : super([]) {
    _init();
  }

  RealtimeChannel? _channel;

  Future<void> _init() async {
    await _fetch();

    _channel = _db
        .channel('public:assets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assets',
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  Future<void> _fetch() async {
    try {
      final rows = await _db.from('assets').select();
      if (mounted) {
        state = rows.map((r) => Asset.fromJson(r)).toList();
      }
    } catch (_) {}
  }

  Future<void> updateStatus(String id, AssetStatus status) async {
    await _db
        .from('assets')
        .update({'status': status.name})
        .eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final assetProvider = StateNotifierProvider<AssetNotifier, List<Asset>>(
  (ref) => AssetNotifier(),
);
