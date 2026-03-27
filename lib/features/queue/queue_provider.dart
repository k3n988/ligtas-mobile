import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/triage_level.dart';
import '../../providers/app_state.dart';

// Re-export for convenience
export '../../providers/app_state.dart' show queueProvider, householdProvider;

/// Active filter — null means show all levels.
final queueFilterProvider = StateProvider<TriageLevel?>((ref) => null);

/// Filtered & sorted queue.
final filteredQueueProvider = Provider((ref) {
  final queue = ref.watch(queueProvider);
  final filter = ref.watch(queueFilterProvider);
  if (filter == null) return queue;
  return queue.where((h) => h.triageLevel == filter).toList();
});
