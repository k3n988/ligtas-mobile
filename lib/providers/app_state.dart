import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/household.dart';
import '../core/models/asset.dart';
import '../core/models/triage_level.dart';

// ── Household ─────────────────────────────────────────────────────────────────

class HouseholdNotifier extends StateNotifier<List<Household>> {
  HouseholdNotifier() : super(_seedHouseholds());

  void add(Household h) => state = [...state, h];

  void markRescued(String id) => _update(id, (h) => h.copyWith(status: HouseholdStatus.rescued));

  void restorePending(String id) => _update(
        id,
        (h) => h.copyWith(status: HouseholdStatus.pending, clearAssignment: true),
      );

  void dispatchRescue(String householdId, String assetId) {
    _update(
      householdId,
      (h) => h.copyWith(
        assignedAssetId: assetId,
        dispatchedAt: DateTime.now(),
      ),
    );
  }

  void _update(String id, Household Function(Household) fn) {
    state = [for (final h in state) if (h.id == id) fn(h) else h];
  }
}

final householdProvider =
    StateNotifierProvider<HouseholdNotifier, List<Household>>(
  (ref) => HouseholdNotifier(),
);

/// Sorted queue: pending first, CRITICAL→STABLE, then rescued at bottom.
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
  AssetNotifier() : super(_seedAssets());

  void updateStatus(String id, AssetStatus status) {
    state = [for (final a in state) if (a.id == id) a.copyWith(status: status) else a];
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
      id: 'HH-MOCK1',
      latitude: 10.6765,
      longitude: 122.9509,
      city: 'Bacolod City',
      barangay: 'Taculing',
      purok: 'Purok 3',
      street: 'Rizal St.',
      structure: StructureType.lightMaterials,
      head: 'Maria Santos',
      contact: '09171234567',
      occupants: 6,
      vulnerabilities: [Vulnerability.bedridden, Vulnerability.oxygen],
      notes: 'Second house from the corner',
      status: HouseholdStatus.pending,
      triageLevel: TriageLevel.critical,
      registeredAt: now.subtract(const Duration(minutes: 55)),
    ),
    Household(
      id: 'HH-MOCK2',
      latitude: 10.6720,
      longitude: 122.9470,
      city: 'Bacolod City',
      barangay: 'Mandalagan',
      purok: 'Purok 1',
      street: 'Magsaysay Ave.',
      structure: StructureType.singleStory,
      head: 'Juan dela Cruz',
      contact: '09281234567',
      occupants: 4,
      vulnerabilities: [Vulnerability.senior, Vulnerability.wheelchair],
      notes: '',
      status: HouseholdStatus.pending,
      triageLevel: TriageLevel.high,
      registeredAt: now.subtract(const Duration(minutes: 40)),
    ),
    Household(
      id: 'HH-MOCK3',
      latitude: 10.6700,
      longitude: 122.9530,
      city: 'Bacolod City',
      barangay: 'Villamonte',
      purok: 'Purok 5',
      street: 'Lopez Jaena St.',
      structure: StructureType.singleStory,
      head: 'Rosa Reyes',
      contact: '09351234567',
      occupants: 5,
      vulnerabilities: [Vulnerability.pregnant, Vulnerability.infant],
      notes: 'Near the church',
      status: HouseholdStatus.pending,
      triageLevel: TriageLevel.elevated,
      registeredAt: now.subtract(const Duration(minutes: 25)),
    ),
    Household(
      id: 'HH-MOCK4',
      latitude: 10.6680,
      longitude: 122.9490,
      city: 'Talisay City',
      barangay: 'Matab-ang',
      purok: 'Purok 2',
      street: 'National Highway',
      structure: StructureType.multiStory,
      head: 'Pedro Lim',
      contact: '09091234567',
      occupants: 3,
      vulnerabilities: [],
      notes: '',
      status: HouseholdStatus.pending,
      triageLevel: TriageLevel.stable,
      registeredAt: now.subtract(const Duration(minutes: 10)),
    ),
    Household(
      id: 'HH-MOCK5',
      latitude: 10.6790,
      longitude: 122.9550,
      city: 'Bacolod City',
      barangay: 'Bata',
      purok: 'Purok 4',
      street: 'Burgos St.',
      structure: StructureType.lightMaterials,
      head: 'Ana Villanueva',
      contact: '09501234567',
      occupants: 8,
      vulnerabilities: [Vulnerability.dialysis, Vulnerability.senior],
      notes: 'Flood-prone area',
      status: HouseholdStatus.pending,
      triageLevel: TriageLevel.critical,
      registeredAt: now.subtract(const Duration(minutes: 60)),
    ),
  ];
}

List<Asset> _seedAssets() {
  return [
    const Asset(
      id: 'A-001',
      name: 'Marine-1',
      type: 'Boat',
      unit: 'BFP Marine',
      status: AssetStatus.dispatching,
      latitude: 10.6750,
      longitude: 122.9480,
      icon: '🚤',
      capacity: 12,
    ),
    const Asset(
      id: 'A-002',
      name: 'Marine-2',
      type: 'Boat',
      unit: 'BFP Marine',
      status: AssetStatus.active,
      latitude: 10.6710,
      longitude: 122.9460,
      icon: '🚤',
      capacity: 10,
    ),
    const Asset(
      id: 'A-003',
      name: 'Truck-303',
      type: 'Truck',
      unit: 'Army 303rd',
      status: AssetStatus.active,
      latitude: 10.6760,
      longitude: 122.9500,
      icon: '🛻',
      capacity: 20,
    ),
    const Asset(
      id: 'A-004',
      name: 'Ambulance-1',
      type: 'Ambulance',
      unit: 'Red Cross',
      status: AssetStatus.standby,
      latitude: 10.6730,
      longitude: 122.9520,
      icon: '🚑',
      capacity: 4,
    ),
    const Asset(
      id: 'A-005',
      name: 'Truck-Army2',
      type: 'Truck',
      unit: 'Army 303rd',
      status: AssetStatus.standby,
      latitude: 10.6745,
      longitude: 122.9535,
      icon: '🛻',
      capacity: 20,
    ),
  ];
}
