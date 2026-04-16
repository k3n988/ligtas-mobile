import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/utils/map_utils.dart';
import '../../features/auth/auth_provider.dart';
import '../../providers/active_hazards_provider.dart';
import '../../providers/app_state.dart';

export '../../providers/app_state.dart'
    show queueProvider, householdProvider, locateHouseholdProvider;

// ── Filter / view state ────────────────────────────────────────────────────────

final queueLevelFilterProvider    = StateProvider<TriageLevel?>((ref) => null);
final queueCityFilterProvider     = StateProvider<String?>((ref) => null);
final queueBarangayFilterProvider = StateProvider<String?>((ref) => null);
final queueHazardFilterProvider   = StateProvider<String?>((ref) => null);

enum RescuerView { priority, assigned, nearest }

final queueRescuerViewProvider =
    StateProvider<RescuerView>((ref) => RescuerView.priority);

// ── QueueEntry ─────────────────────────────────────────────────────────────────

class QueueEntry {
  final Household household;
  final TriageLevel effectiveLevel;
  final bool isInHazardZone;
  final double? hazardDistanceKm;
  final int hazardPriorityRank; // 0=CRITICAL..3=STABLE, maxInt = not in zone
  final List<String> matchingHazardTypes;
  final double? rescuerDistanceKm;
  final bool assignedToCurrentRescuer;

  const QueueEntry({
    required this.household,
    required this.effectiveLevel,
    required this.isInHazardZone,
    required this.hazardDistanceKm,
    required this.hazardPriorityRank,
    required this.matchingHazardTypes,
    required this.rescuerDistanceKm,
    required this.assignedToCurrentRescuer,
  });
}

// ── Hazard-zone helpers ────────────────────────────────────────────────────────

TriageLevel? _hazardLevelForHousehold(
  Household h,
  List<ActiveHazard> hazards,
) {
  TriageLevel? best;
  for (final hz in hazards) {
    if (hz.type == 'Flood') continue; // no polygon data on mobile
    final distKm = haversineDistance(
          h.latitude, h.longitude, hz.centerLat, hz.centerLng) /
        1000.0;
    final TriageLevel? level;
    if (distKm <= hz.radiusCritical) {
      level = TriageLevel.critical;
    } else if (distKm <= hz.radiusHigh) {
      level = TriageLevel.high;
    } else if (distKm <= hz.radiusElevated) {
      level = TriageLevel.elevated;
    } else if (distKm <= hz.radiusStable) {
      level = TriageLevel.stable;
    } else {
      level = null;
    }

    if (level != null && (best == null || level.priority < best.priority)) {
      best = level;
    }
  }
  return best;
}

double? _nearestHazardKm(Household h, List<ActiveHazard> hazards) {
  double? best;
  for (final hz in hazards) {
    if (hz.type == 'Flood') continue;
    final d = haversineDistance(
          h.latitude, h.longitude, hz.centerLat, hz.centerLng) /
        1000.0;
    if (best == null || d < best) best = d;
  }
  return best;
}

// ── Providers ──────────────────────────────────────────────────────────────────

/// All approved households as QueueEntry (hazard data computed here).
final queueEntriesProvider = Provider<List<QueueEntry>>((ref) {
  final households = ref.watch(queueProvider);
  final hazards    = ref.watch(activeHazardsProvider);
  final myAsset    = ref.watch(myAssetProvider);

  return households.map((h) {
    final hazardLevel = _hazardLevelForHousehold(h, hazards);
    final isInZone    = hazardLevel != null;

    final effectiveLevel =
        (hazardLevel != null && hazardLevel.priority < h.triageLevel.priority)
            ? hazardLevel
            : h.triageLevel;

    final matchingTypes = hazards
        .where((hz) {
          if (hz.type == 'Flood') return false;
          final distKm = haversineDistance(
                h.latitude, h.longitude, hz.centerLat, hz.centerLng) /
              1000.0;
          return distKm <= hz.radiusStable;
        })
        .map((hz) => hz.type)
        .toList();

    final rescuerDistKm = myAsset != null
        ? haversineDistance(h.latitude, h.longitude,
              myAsset.latitude, myAsset.longitude) /
            1000.0
        : null;

    return QueueEntry(
      household:                h,
      effectiveLevel:           effectiveLevel,
      isInHazardZone:           isInZone,
      hazardDistanceKm:         _nearestHazardKm(h, hazards),
      hazardPriorityRank:       isInZone ? hazardLevel.priority : 0x7fffffff,
      matchingHazardTypes:      matchingTypes,
      rescuerDistanceKm:        rescuerDistKm,
      assignedToCurrentRescuer: myAsset != null && h.assignedAssetId == myAsset.id,
    );
  }).toList();
});

/// Filtered + sorted queue entries (all filters applied).
final filteredQueueEntriesProvider = Provider<List<QueueEntry>>((ref) {
  final entries      = ref.watch(queueEntriesProvider);
  final hazards      = ref.watch(activeHazardsProvider);
  final city         = ref.watch(queueCityFilterProvider);
  final barangay     = ref.watch(queueBarangayFilterProvider);
  final level        = ref.watch(queueLevelFilterProvider);
  final hazardFilter = ref.watch(queueHazardFilterProvider);
  final rescuerView  = ref.watch(queueRescuerViewProvider);
  final isRescuer    = ref.watch(authProvider).role == UserRole.rescuer;
  final hasHazards   = hazards.isNotEmpty;

  final filtered = entries.where((e) {
    final h = e.household;
    if (city     != null && h.city     != city)     return false;
    if (barangay != null && h.barangay != barangay) return false;
    if (level    != null && e.effectiveLevel != level) return false;
    if (!isRescuer && hazardFilter != null &&
        !e.matchingHazardTypes.contains(hazardFilter)) { return false; }
    if (isRescuer && rescuerView == RescuerView.assigned &&
        !e.assignedToCurrentRescuer) { return false; }
    return true;
  }).toList();

  filtered.sort((a, b) {
    // Rescued → bottom
    if (a.household.isRescued && !b.household.isRescued) return 1;
    if (!a.household.isRescued && b.household.isRescued) return -1;

    // Rescuer "assigned": mine first
    if (isRescuer &&
        rescuerView == RescuerView.assigned &&
        a.assignedToCurrentRescuer != b.assignedToCurrentRescuer) {
      return a.assignedToCurrentRescuer ? -1 : 1;
    }

    // Rescuer "nearest": sort by distance from rescuer
    if (isRescuer && rescuerView == RescuerView.nearest) {
      final da = a.rescuerDistanceKm ?? double.maxFinite;
      final db = b.rescuerDistanceKm ?? double.maxFinite;
      if (da != db) return da.compareTo(db);
    }

    // In-zone before out-of-zone
    if (hasHazards && a.isInHazardZone != b.isInHazardZone) {
      return a.isInHazardZone ? -1 : 1;
    }

    // Both in-zone: hazard severity first
    if (a.isInHazardZone && b.isInHazardZone &&
        a.hazardPriorityRank != b.hazardPriorityRank) {
      return a.hazardPriorityRank.compareTo(b.hazardPriorityRank);
    }

    // Vulnerability triage level
    final triageDiff = a.effectiveLevel.priority - b.effectiveLevel.priority;
    if (triageDiff != 0) return triageDiff;

    // Both in-zone: closer hazard first
    if (a.isInHazardZone && b.isInHazardZone) {
      final da = a.hazardDistanceKm ?? double.maxFinite;
      final db = b.hazardDistanceKm ?? double.maxFinite;
      if (da != db) return da.compareTo(db);
    }

    final cc = a.household.city.compareTo(b.household.city);
    if (cc != 0) return cc;
    return a.household.barangay.compareTo(b.household.barangay);
  });

  return filtered;
});

/// Unique cities in queue
final queueCitiesProvider = Provider<List<String>>((ref) {
  final entries = ref.watch(queueEntriesProvider);
  return entries.map((e) => e.household.city).toSet().toList()..sort();
});

/// Barangays for selected city
final queueBarangaysProvider = Provider<List<String>>((ref) {
  final entries = ref.watch(queueEntriesProvider);
  final city    = ref.watch(queueCityFilterProvider);
  if (city == null) return [];
  return entries
      .where((e) => e.household.city == city)
      .map((e) => e.household.barangay)
      .toSet()
      .toList()
    ..sort();
});

/// Active hazard types present in the data (for the hazard filter dropdown)
final activeHazardTypesProvider = Provider<List<String>>((ref) {
  final hazards = ref.watch(activeHazardsProvider);
  return hazards
      .where((h) => h.type != 'Flood')
      .map((h) => h.type)
      .toSet()
      .toList()
    ..sort();
});

/// Back-compat: plain household list (used by any code that still imports filteredQueueProvider)
final filteredQueueProvider = Provider<List<Household>>((ref) {
  return ref
      .watch(filteredQueueEntriesProvider)
      .map((e) => e.household)
      .toList();
});
