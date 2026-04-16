import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/auth_provider.dart';
import '../../providers/active_hazards_provider.dart';
import 'household_card.dart';
import 'queue_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries        = ref.watch(filteredQueueEntriesProvider);
    final cities         = ref.watch(queueCitiesProvider);
    final barangays      = ref.watch(queueBarangaysProvider);
    final activeHazards  = ref.watch(activeHazardsProvider);
    final hazardTypes    = ref.watch(activeHazardTypesProvider);
    final isRescuer      = ref.watch(authProvider).role == UserRole.rescuer;

    final cityFilter     = ref.watch(queueCityFilterProvider);
    final barangayFilter = ref.watch(queueBarangayFilterProvider);
    final levelFilter    = ref.watch(queueLevelFilterProvider);
    final hazardFilter   = ref.watch(queueHazardFilterProvider);
    final rescuerView    = ref.watch(queueRescuerViewProvider);

    final pending         = entries.where((e) => !e.household.isRescued).toList();
    final rescued         = entries.where((e) =>  e.household.isRescued).toList();
    final hazardPending   = pending.where((e) => e.isInHazardZone).toList();
    final regularPending  = pending.where((e) => !e.isInHazardZone).toList();

    final hasHazards       = activeHazards.isNotEmpty;
    final showHazardBanner = hasHazards && hazardPending.isNotEmpty;
    final assignedCount    = pending.where((e) => e.assignedToCurrentRescuer).length;

    final hasFilter = cityFilter != null || barangayFilter != null ||
        levelFilter != null || hazardFilter != null;

    final hazardLabel = hazardFilter ??
        activeHazards.map((h) => h.type).join(', ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rescue Queue', style: AppTextStyles.headlineLarge),
                      Text(
                        hasFilter
                            ? '${cityFilter ?? 'All Cities'}${barangayFilter != null ? ' · $barangayFilter' : ''}'
                            : '${pending.length} pending',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (hasFilter)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(queueCityFilterProvider.notifier).state     = null;
                        ref.read(queueBarangayFilterProvider.notifier).state = null;
                        ref.read(queueLevelFilterProvider.notifier).state    = null;
                        ref.read(queueHazardFilterProvider.notifier).state   = null;
                        ref.read(queueRescuerViewProvider.notifier).state    = RescuerView.priority;
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

            // ── Rescuer view toggle (rescuers only) ───────────────────────
            if (isRescuer) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _ViewChip(
                      label: 'Priority Missions',
                      selected: rescuerView == RescuerView.priority,
                      color: AppColors.accent,
                      onTap: () => ref.read(queueRescuerViewProvider.notifier).state =
                          RescuerView.priority,
                    ),
                    const SizedBox(width: 8),
                    _ViewChip(
                      label: 'Assigned To Me${assignedCount > 0 ? ' ($assignedCount)' : ''}',
                      selected: rescuerView == RescuerView.assigned,
                      color: AppColors.deployed,
                      onTap: () => ref.read(queueRescuerViewProvider.notifier).state =
                          RescuerView.assigned,
                    ),
                    const SizedBox(width: 8),
                    _ViewChip(
                      label: 'Nearest To Me',
                      selected: rescuerView == RescuerView.nearest,
                      color: AppColors.stable,
                      onTap: () => ref.read(queueRescuerViewProvider.notifier).state =
                          RescuerView.nearest,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Filters ────────────────────────────────────────────────────
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
                        ref.read(queueCityFilterProvider.notifier).state     = v;
                        ref.read(queueBarangayFilterProvider.notifier).state = null;
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
                      onChanged: (v) =>
                          ref.read(queueBarangayFilterProvider.notifier).state = v,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Triage level + hazard filter chips ─────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _LevelChip(
                    label: 'All',
                    selected: levelFilter == null,
                    color: AppColors.accent,
                    onTap: () =>
                        ref.read(queueLevelFilterProvider.notifier).state = null,
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
                  // Hazard filter chips (admin/LGU only, when hazards active)
                  if (!isRescuer && hazardTypes.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(width: 1, height: 18, color: AppColors.divider),
                    const SizedBox(width: 12),
                    ...hazardTypes.map((type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _LevelChip(
                            label: type,
                            selected: hazardFilter == type,
                            color: const Color(0xFFFF4D4D),
                            onTap: () => ref
                                .read(queueHazardFilterProvider.notifier)
                                .state = hazardFilter == type ? null : type,
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: entries.isEmpty
                  ? _EmptyState(hasFilter: hasFilter)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        // Hazard priority banner
                        if (showHazardBanner)
                          _HazardPriorityBanner(
                            hazardLabel: hazardLabel,
                            hazardCount: hazardPending.length,
                            assignedCount: assignedCount,
                            isRescuer: isRescuer,
                          ),

                        // Hazard zone section
                        if (showHazardBanner) ...[
                          _SectionHeader(
                            label: 'Inside Active Hazard Layer',
                            color: const Color(0xFFFF4D4D),
                          ),
                          ..._priorityGroups(hazardPending, ref),
                        ],

                        // Outside hazard zone (or all if no hazards)
                        if (showHazardBanner && regularPending.isNotEmpty) ...[
                          _Divider(label: 'Outside Active Hazard Layer'),
                          ..._priorityGroups(regularPending, ref),
                        ] else if (!showHazardBanner)
                          ..._priorityGroups(pending, ref),

                        // Rescued section
                        if (rescued.isNotEmpty) ...[
                          _Divider(label: 'Completed Operations'),
                          ...rescued.map((e) => HouseholdCard(
                                household: e.household,
                                queuePosition: 0,
                                isInHazardZone: e.isInHazardZone,
                                matchingHazardTypes: e.matchingHazardTypes,
                                effectiveLevel: e.effectiveLevel,
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _priorityGroups(List<QueueEntry> entries, WidgetRef ref) {
    final result = <Widget>[];
    for (final level in TriageLevel.values) {
      final group = entries.where((e) => e.effectiveLevel == level).toList();
      if (group.isEmpty) continue;

      result.add(_PriorityGroupHeader(level: level));
      var pos = 1;
      for (final e in group) {
        result.add(HouseholdCard(
          household: e.household,
          queuePosition: e.household.isRescued ? 0 : pos++,
          isInHazardZone: e.isInHazardZone,
          matchingHazardTypes: e.matchingHazardTypes,
          effectiveLevel: e.effectiveLevel,
        ));
      }
    }
    return result;
  }
}

// ── Hazard priority banner ─────────────────────────────────────────────────────

class _HazardPriorityBanner extends StatelessWidget {
  final String hazardLabel;
  final int hazardCount;
  final int assignedCount;
  final bool isRescuer;

  const _HazardPriorityBanner({
    required this.hazardLabel,
    required this.hazardCount,
    required this.assignedCount,
    required this.isRescuer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF200A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF4D4D).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRescuer
                ? 'Priority Missions In Active Hazard Zones'
                : '$hazardLabel Hazard Priority Active',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF4D4D),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRescuer
                ? '$hazardCount priority mission${hazardCount != 1 ? 's' : ''} are inside active hazard layers. Assigned: $assignedCount.'
                : '$hazardCount household${hazardCount != 1 ? 's' : ''} inside the active hazard layer are pinned to the top of the queue.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Priority group header ──────────────────────────────────────────────────────

class _PriorityGroupHeader extends StatelessWidget {
  final TriageLevel level;
  const _PriorityGroupHeader({required this.level});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            '${level.label[0]}${level.label.substring(1).toLowerCase()} Priority',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: level.color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ── Divider with label ─────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ── Filter dropdown ────────────────────────────────────────────────────────────

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
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
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

// ── View chip (rescuer mode selector) ─────────────────────────────────────────

class _ViewChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ViewChip({
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Triage level chip ──────────────────────────────────────────────────────────

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

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search,
              size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            hasFilter
                ? 'No reports match this filter.'
                : 'All households rescued!',
            style:
                AppTextStyles.titleLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
