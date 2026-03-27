import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/household.dart';
import '../core/models/asset.dart';
import '../core/models/triage_level.dart';

// ── Household list ────────────────────────────────────────────────────────────

class HouseholdNotifier extends StateNotifier<List<Household>> {
  HouseholdNotifier() : super(_seedHouseholds());

  void add(Household h) => state = [...state, h];

  void markRescued(String id) {
    state = [
      for (final h in state)
        if (h.id == id) h.copyWith(isRescued: true) else h,
    ];
  }

  void remove(String id) => state = state.where((h) => h.id != id).toList();
}

final householdProvider =
    StateNotifierProvider<HouseholdNotifier, List<Household>>(
  (ref) => HouseholdNotifier(),
);

/// Sorted queue: unrescued first, ordered by triage priority then registration time.
final queueProvider = Provider<List<Household>>((ref) {
  final all = ref.watch(householdProvider);
  final pending = all.where((h) => !h.isRescued).toList()
    ..sort((a, b) {
      final p = a.triageLevel.priority.compareTo(b.triageLevel.priority);
      return p != 0 ? p : a.registeredAt.compareTo(b.registeredAt);
    });
  return pending;
});

// ── Asset list ────────────────────────────────────────────────────────────────

class AssetNotifier extends StateNotifier<List<Asset>> {
  AssetNotifier() : super(_seedAssets());

  void updateStatus(String id, AssetStatus status) {
    state = [
      for (final a in state)
        if (a.id == id) a.copyWith(status: status) else a,
    ];
  }
}

final assetProvider = StateNotifierProvider<AssetNotifier, List<Asset>>(
  (ref) => AssetNotifier(),
);

// ── Seed data ─────────────────────────────────────────────────────────────────

List<Household> _seedHouseholds() {
  final now = DateTime.now();
  return [
    Household(
      id: 'h1',
      headName: 'Maria Santos',
      barangay: 'Brgy. 176',
      memberCount: 6,
      elderlyCount: 1,
      infantCount: 1,
      medicalCount: 2,
      hasDisabled: false,
      damageLevel: 2,
      latitude: 14.6090,
      longitude: 120.9890,
      triageLevel: TriageLevel.critical,
      registeredAt: now.subtract(const Duration(minutes: 45)),
    ),
    Household(
      id: 'h2',
      headName: 'Juan dela Cruz',
      barangay: 'Brgy. 201',
      memberCount: 4,
      elderlyCount: 0,
      infantCount: 1,
      medicalCount: 1,
      hasDisabled: false,
      damageLevel: 1,
      latitude: 14.5980,
      longitude: 120.9810,
      triageLevel: TriageLevel.high,
      registeredAt: now.subtract(const Duration(minutes: 30)),
    ),
    Household(
      id: 'h3',
      headName: 'Rosa Reyes',
      barangay: 'Brgy. 145',
      memberCount: 5,
      elderlyCount: 2,
      infantCount: 0,
      medicalCount: 0,
      hasDisabled: false,
      damageLevel: 1,
      latitude: 14.6010,
      longitude: 120.9860,
      triageLevel: TriageLevel.elevated,
      registeredAt: now.subtract(const Duration(minutes: 20)),
    ),
    Household(
      id: 'h4',
      headName: 'Pedro Lim',
      barangay: 'Brgy. 090',
      memberCount: 3,
      elderlyCount: 0,
      infantCount: 0,
      medicalCount: 0,
      hasDisabled: false,
      damageLevel: 0,
      latitude: 14.5950,
      longitude: 120.9870,
      triageLevel: TriageLevel.stable,
      registeredAt: now.subtract(const Duration(minutes: 10)),
    ),
    Household(
      id: 'h5',
      headName: 'Ana Villanueva',
      barangay: 'Brgy. 176',
      memberCount: 8,
      elderlyCount: 2,
      infantCount: 2,
      medicalCount: 3,
      hasDisabled: true,
      damageLevel: 3,
      latitude: 14.6070,
      longitude: 120.9920,
      triageLevel: TriageLevel.critical,
      registeredAt: now.subtract(const Duration(minutes: 55)),
    ),
  ];
}

List<Asset> _seedAssets() {
  return [
    const Asset(
      id: 'a1',
      name: 'RB-Alpha',
      type: AssetType.boat,
      location: 'Staging Area North',
      capacity: 12,
      status: AssetStatus.deployed,
      latitude: 14.6050,
      longitude: 120.9830,
    ),
    const Asset(
      id: 'a2',
      name: 'RB-Bravo',
      type: AssetType.boat,
      location: 'Staging Area South',
      capacity: 10,
      status: AssetStatus.available,
      latitude: 14.5960,
      longitude: 120.9850,
    ),
    const Asset(
      id: 'a3',
      name: 'Truck-01',
      type: AssetType.truck,
      location: 'City Hall Hub',
      capacity: 20,
      status: AssetStatus.available,
      latitude: 14.5995,
      longitude: 120.9842,
    ),
    const Asset(
      id: 'a4',
      name: 'Heli-1',
      type: AssetType.helicopter,
      location: 'Airport',
      capacity: 6,
      status: AssetStatus.maintenance,
    ),
    const Asset(
      id: 'a5',
      name: 'Med-Team A',
      type: AssetType.medicalTeam,
      location: 'District Hospital',
      capacity: 30,
      status: AssetStatus.deployed,
    ),
  ];
}
