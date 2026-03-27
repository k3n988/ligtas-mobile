import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'queue_provider.dart';
import 'household_card.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(filteredQueueProvider);
    final allQueue = ref.watch(queueProvider);
    final filter = ref.watch(queueFilterProvider);
    final rescued = ref.watch(householdProvider).where((h) => h.isRescued).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rescue Queue', style: AppTextStyles.headlineLarge),
                      Text('${allQueue.length} pending · $rescued rescued', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                  const Spacer(),
                  FloatingActionButton.small(
                    onPressed: () => context.go('/register'),
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ),

            // ── Filter chips ───────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: filter == null,
                    color: AppColors.accent,
                    onTap: () => ref.read(queueFilterProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  ...TriageLevel.values.map((level) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: level.label,
                          selected: filter == level,
                          color: _levelColor(level),
                          onTap: () => ref.read(queueFilterProvider.notifier).state =
                              filter == level ? null : level,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Queue list ─────────────────────────────────────────────────
            Expanded(
              child: queue.isEmpty
                  ? _EmptyState(hasFilter: filter != null)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final h = queue[i];
                        return HouseholdCard(
                          household: h,
                          queuePosition: i + 1,
                          onRescue: () =>
                              ref.read(householdProvider.notifier).markRescued(h.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(TriageLevel l) {
    switch (l) {
      case TriageLevel.critical:
        return AppColors.critical;
      case TriageLevel.high:
        return AppColors.high;
      case TriageLevel.elevated:
        return AppColors.elevated;
      case TriageLevel.stable:
        return AppColors.stable;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? color : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: AppColors.stable.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No households match this filter' : 'All households rescued!',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
