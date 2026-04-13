import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/triage_level.dart';
import '../../providers/app_state.dart';

export '../../providers/app_state.dart'
    show queueProvider, householdProvider, locateHouseholdProvider;

final queueLevelFilterProvider = StateProvider<TriageLevel?>((ref) => null);
final queueCityFilterProvider  = StateProvider<String?>((ref) => null);
final queueBarangayFilterProvider = StateProvider<String?>((ref) => null);

final filteredQueueProvider = Provider((ref) {
  final queue   = ref.watch(queueProvider);
  final level   = ref.watch(queueLevelFilterProvider);
  final city    = ref.watch(queueCityFilterProvider);
  final barangay = ref.watch(queueBarangayFilterProvider);

  return queue.where((h) {
    if (level    != null && h.triageLevel != level)   return false;
    if (city     != null && h.city        != city)    return false;
    if (barangay != null && h.barangay    != barangay) return false;
    return true;
  }).toList();
});

/// Unique cities present in the current queue
final queueCitiesProvider = Provider<List<String>>((ref) {
  final queue = ref.watch(queueProvider);
  return queue.map((h) => h.city).toSet().toList()..sort();
});

/// Barangays in selected city
final queueBarangaysProvider = Provider<List<String>>((ref) {
  final queue = ref.watch(queueProvider);
  final city  = ref.watch(queueCityFilterProvider);
  if (city == null) return [];
  return queue
      .where((h) => h.city == city)
      .map((h) => h.barangay)
      .toSet()
      .toList()
    ..sort();
});
