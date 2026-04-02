import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/models/hazard_area.dart';
import '../core/models/household.dart';
import '../core/utils/map_utils.dart';
import 'app_state.dart';

// ── Hazard state ──────────────────────────────────────────────────────────────

class HazardNotifier extends StateNotifier<List<HazardArea>> {
  HazardNotifier() : super([]);

  void addHazard(HazardArea h) => state = [...state, h];

  void removeHazard(String id) =>
      state = state.where((h) => h.id != id).toList();

  void updateHazard(HazardArea updated) {
    state = [
      for (final h in state) if (h.id == updated.id) updated else h,
    ];
  }
}

final hazardProvider =
    StateNotifierProvider<HazardNotifier, List<HazardArea>>(
  (ref) => HazardNotifier(),
);

// ── Derived: households inside each hazard zone ───────────────────────────────

/// All households whose coordinates fall inside [hazardId]'s polygon.
final householdsInHazardProvider =
    Provider.family<List<Household>, String>((ref, hazardId) {
  final households = ref.watch(householdProvider);
  final hazards = ref.watch(hazardProvider);

  final hazard = hazards.where((h) => h.id == hazardId).firstOrNull;
  if (hazard == null) return [];

  return households.where((hh) {
    return isPointInPolygon(
      LatLng(hh.latitude, hh.longitude),
      hazard.polygonPoints,
    );
  }).toList();
});

/// Resolution State 1 — true when every household inside the zone is rescued.
final hazardAllRescuedProvider =
    Provider.family<bool, String>((ref, hazardId) {
  final inside = ref.watch(householdsInHazardProvider(hazardId));
  if (inside.isEmpty) return false;
  return inside.every((hh) => hh.isRescued);
});

// ── Map-picking state (shared between map + registration screens) ─────────────

/// When true, the map screen enters "tap to pin" mode.
final pickingLocationProvider = StateProvider<bool>((ref) => false);

/// Holds the last pinned coords until registration consumes them.
final pendingCoordsProvider = StateProvider<LatLng?>((ref) => null);
