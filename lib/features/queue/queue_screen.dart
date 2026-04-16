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
    final entries       = ref.watch(filteredQueueEntriesProvider);
    final cities        = ref.watch(queueCitiesProvider);
    final barangays     = ref.watch(queueBarangaysProvider);
    final activeHazards = ref.watch(activeHazardsProvider);
    final hazardTypes   = ref.watch(activeHazardTypesProvider);
    final isRescuer     = ref.watch(authProvider).role == UserRole.rescuer;

    final cityFilter    = ref.watch(queueCityFilterProvider);
    final brgyFilter    = ref.watch(queueBarangayFilterProvider);
    final levelFilter   = ref.watch(queueLevelFilterProvider);
    final rescuerView   = ref.watch(queueRescuerViewProvider);

    final pending        = entries.where((e) => !e.household.isRescued).toList();
    final rescued        = entries.where((e) =>  e.household.isRescued).toList();
    final hazardPending  = pending.where((e) => e.isInHazardZone).toList();
    final regularPending = pending.where((e) => !e.isInHazardZone).toList();

    final hasHazards      = activeHazards.isNotEmpty;
    final showHazardBanner = hasHazards && hazardPending.isNotEmpty;
    final assignedCount   = pending.where((e) => e.assignedToCurrentRescuer).length;
    final nearestCount    = pending.where((e) => e.rescuerDistanceKm != null).length;
    final hazardLabel     = activeHazards.map((h) => h.type).join(', ');

    final hasFilter = cityFilter != null || brgyFilter != null ||
        levelFilter != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FILTER',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (hasFilter)
                    GestureDetector(
                      onTap: () {
                        ref.read(queueCityFilterProvider.notifier).state     = null;
                        ref.read(queueBarangayFilterProvider.notifier).state = null;
                        ref.read(queueLevelFilterProvider.notifier).state    = null;
                        ref.read(queueHazardFilterProvider.notifier).state   = null;
                        ref.read(queueRescuerViewProvider.notifier).state    = RescuerView.priority;
                      },
                      child: Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),

            // ── Rescuer view toggle ───────────────────────────────────────
            if (isRescuer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ViewBtn(
                        label: 'Priority Missions',
                        selected: rescuerView == RescuerView.priority,
                        onTap: () => ref
                            .read(queueRescuerViewProvider.notifier)
                            .state = RescuerView.priority,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ViewBtn(
                        label: 'Assigned To Me',
                        selected: rescuerView == RescuerView.assigned,
                        onTap: () => ref
                            .read(queueRescuerViewProvider.notifier)
                            .state = RescuerView.assigned,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ViewBtn(
                        label: 'Nearest To Me',
                        selected: rescuerView == RescuerView.nearest,
                        onTap: () => ref
                            .read(queueRescuerViewProvider.notifier)
                            .state = RescuerView.nearest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Three dropdowns: City · Barangay · Priority ───────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _Dropdown<String>(
                      hint: 'All Cities / Municipalities',
                      value: cityFilter,
                      items: cities,
                      itemLabel: (v) => v,
                      onChanged: (v) {
                        ref.read(queueCityFilterProvider.notifier).state     = v;
                        ref.read(queueBarangayFilterProvider.notifier).state = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Dropdown<String>(
                      hint: 'All Barangays',
                      value: brgyFilter,
                      items: barangays,
                      itemLabel: (v) => v,
                      enabled: cityFilter != null,
                      onChanged: (v) =>
                          ref.read(queueBarangayFilterProvider.notifier).state = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Hazard type dropdown for admin; priority dropdown for rescuer
                  if (!isRescuer && hazardTypes.isNotEmpty)
                    Expanded(
                      child: _HazardDropdown(
                        hazardTypes: hazardTypes,
                        ref: ref,
                      ),
                    )
                  else
                    Expanded(
                      child: _Dropdown<TriageLevel>(
                        hint: 'All Priorities',
                        value: levelFilter,
                        items: TriageLevel.values,
                        itemLabel: (l) =>
                            '${l.label[0]}${l.label.substring(1).toLowerCase()}',
                        onChanged: (v) =>
                            ref.read(queueLevelFilterProvider.notifier).state = v,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── "ACTIVE QUEUE" row ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    hasFilter
                        ? '${cityFilter ?? 'All Cities'}${brgyFilter != null ? ' · $brgyFilter' : ''}'
                        : 'ACTIVE QUEUE',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${pending.length} pending',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFF4D4D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: entries.isEmpty
                  ? _EmptyState(hasFilter: hasFilter)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        // Hazard priority banner
                        if (showHazardBanner)
                          _HazardBanner(
                            hazardLabel: hazardLabel,
                            hazardCount: hazardPending.length,
                            assignedCount: assignedCount,
                            nearestCount: nearestCount,
                            isRescuer: isRescuer,
                          ),

                        // Inside hazard zone section
                        if (showHazardBanner) ...[
                          _SectionLabel(
                            label: 'INSIDE ACTIVE HAZARD LAYER',
                            color: const Color(0xFFFF4D4D),
                          ),
                          ..._priorityGroups(hazardPending),
                        ],

                        // Outside hazard zone
                        if (showHazardBanner && regularPending.isNotEmpty) ...[
                          _DividerRow(label: 'Outside Active Hazard Layer'),
                          ..._priorityGroups(regularPending),
                        ] else if (!showHazardBanner)
                          ..._priorityGroups(pending),

                        // Completed operations
                        if (rescued.isNotEmpty) ...[
                          _DividerRow(label: 'Completed Operations'),
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

  List<Widget> _priorityGroups(List<QueueEntry> entries) {
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

class _HazardBanner extends StatelessWidget {
  final String hazardLabel;
  final int hazardCount;
  final int assignedCount;
  final int nearestCount;
  final bool isRescuer;

  const _HazardBanner({
    required this.hazardLabel,
    required this.hazardCount,
    required this.assignedCount,
    required this.nearestCount,
    required this.isRescuer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF200A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFFF4D4D).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRescuer
                ? 'PRIORITY MISSIONS IN ACTIVE HAZARD ZONES'
                : '${hazardLabel.toUpperCase()} HAZARD PRIORITY ACTIVE',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF4D4D),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isRescuer
                ? '$hazardCount priority mission${hazardCount != 1 ? 's' : ''} are inside active hazard layers.'
                    ' Assigned: $assignedCount. Nearest available: $nearestCount.'
                : '$hazardCount household${hazardCount != 1 ? 's' : ''} inside the active hazard layer'
                    ' are pinned to the top of the queue.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFADB5BD),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        label,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(
            '${level.label[0]}${level.label.substring(1).toLowerCase()} Priority'
                .toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: level.color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Divider row ───────────────────────────────────────────────────────────────

class _DividerRow extends StatelessWidget {
  final String label;
  const _DividerRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7785),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

// ── Generic dropdown ──────────────────────────────────────────────────────────

class _Dropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final bool enabled;

  const _Dropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7785)),
            overflow: TextOverflow.ellipsis),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.cardBackground,
        icon: const Icon(Icons.expand_more,
            size: 16, color: Color(0xFF6B7785)),
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text(hint,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7785)),
                overflow: TextOverflow.ellipsis),
          ),
          ...items.map((i) => DropdownMenuItem<T>(
                value: i,
                child: Text(itemLabel(i),
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

// ── Hazard type dropdown (admin) ───────────────────────────────────────────────

class _HazardDropdown extends StatelessWidget {
  final List<String> hazardTypes;
  final WidgetRef ref;

  const _HazardDropdown({required this.hazardTypes, required this.ref});

  @override
  Widget build(BuildContext context) {
    final hazardFilter = ref.watch(queueHazardFilterProvider);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButton<String>(
        value: hazardFilter,
        hint: Text(
          hazardTypes.length > 1 ? 'All Active Disasters' : 'Active Disaster',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7785)),
          overflow: TextOverflow.ellipsis,
        ),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.cardBackground,
        icon: const Icon(Icons.expand_more,
            size: 16, color: Color(0xFF6B7785)),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              hazardTypes.length > 1 ? 'All Active Disasters' : 'Active Disaster',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7785)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...hazardTypes.map((t) => DropdownMenuItem<String>(
                value: t,
                child: Text(t,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: (v) =>
            ref.read(queueHazardFilterProvider.notifier).state = v,
      ),
    );
  }
}

// ── Rescuer view button ────────────────────────────────────────────────────────

class _ViewBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.divider),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7785),
          ),
          textAlign: TextAlign.center,
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
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(
            hasFilter
                ? 'No reports match this filter.'
                : 'All households rescued!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
