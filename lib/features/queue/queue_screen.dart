import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'queue_provider.dart';
import 'household_card.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue    = ref.watch(filteredQueueProvider);
    final allQueue = ref.watch(queueProvider);
    final cities   = ref.watch(queueCitiesProvider);
    final barangays = ref.watch(queueBarangaysProvider);

    final cityFilter     = ref.watch(queueCityFilterProvider);
    final barangayFilter = ref.watch(queueBarangayFilterProvider);
    final levelFilter    = ref.watch(queueLevelFilterProvider);

    final pending = allQueue.where((h) => !h.isRescued).length;
    final rescued = allQueue.where((h) => h.isRescued).length;
    final hasFilter = cityFilter != null || barangayFilter != null || levelFilter != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rescue Queue',
                          style: AppTextStyles.headlineLarge),
                      Text('$pending pending · $rescued rescued',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                  const Spacer(),
                  if (hasFilter)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(queueCityFilterProvider.notifier).state =
                            null;
                        ref
                            .read(queueBarangayFilterProvider.notifier)
                            .state = null;
                        ref
                            .read(queueLevelFilterProvider.notifier)
                            .state = null;
                      },
                      icon: const Icon(Icons.filter_alt_off,
                          size: 16, color: AppColors.textSecondary),
                      label: Text('Clear',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),

            // ── City + Barangay filters ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      hint: 'All Cities',
                      value: cityFilter,
                      items: cities,
                      onChanged: (v) {
                        ref.read(queueCityFilterProvider.notifier).state = v;
                        ref
                            .read(queueBarangayFilterProvider.notifier)
                            .state = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterDropdown(
                      hint: 'All Barangays',
                      value: barangayFilter,
                      items: barangays,
                      enabled: cityFilter != null,
                      onChanged: (v) => ref
                          .read(queueBarangayFilterProvider.notifier)
                          .state = v,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Triage level chips ───────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _LevelChip(
                    label: 'All',
                    selected: levelFilter == null,
                    color: AppColors.accent,
                    onTap: () => ref
                        .read(queueLevelFilterProvider.notifier)
                        .state = null,
                  ),
                  ...TriageLevel.values.map((l) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _LevelChip(
                          label: l.label,
                          selected: levelFilter == l,
                          color: l.color,
                          onTap: () => ref
                              .read(queueLevelFilterProvider.notifier)
                              .state = levelFilter == l ? null : l,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Queue list ───────────────────────────────────────────────
            Expanded(
              child: queue.isEmpty
                  ? _EmptyState(hasFilter: hasFilter)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final h = queue[i];
                        final pos = h.isRescued
                            ? 0
                            : queue
                                    .where((x) => !x.isRescued)
                                    .toList()
                                    .indexOf(h) +
                                1;
                        return HouseholdCard(
                          household: h,
                          queuePosition: pos,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  final bool enabled;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint,
            style:
                AppTextStyles.bodyMedium.copyWith(fontSize: 12),
            overflow: TextOverflow.ellipsis),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.cardBackground,
        style: AppTextStyles.bodyMedium,
        icon: const Icon(Icons.expand_more,
            size: 18, color: AppColors.textSecondary),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(hint,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 12)),
          ),
          ...items.map((i) => DropdownMenuItem(
                value: i,
                child: Text(i,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

// ── Triage level chip ─────────────────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _LevelChip({
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
          color: selected
              ? color.withValues(alpha: 0.2)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.divider),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64,
              color: AppColors.stable.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'No households match this filter'
                : 'All households rescued!',
            style: AppTextStyles.titleLarge
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
