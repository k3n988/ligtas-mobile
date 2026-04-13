import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/asset.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';
import '../../providers/app_state.dart';
import 'asset_card.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets     = ref.watch(assetProvider);
    final households = ref.watch(householdProvider);

    final active      = assets.where((a) => a.status == AssetStatus.active).length;
    final dispatching = assets.where((a) => a.status == AssetStatus.dispatching).length;
    final standby     = assets.where((a) => a.status == AssetStatus.standby).length;

    final criticalPending = households
        .where((h) =>
            !h.isRescued && h.triageLevel == TriageLevel.critical)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rescue Assets',
                        style: AppTextStyles.headlineLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${assets.length} total',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            // ── Status summary ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _SummaryTile(
                        label: 'Active',
                        count: active,
                        color: AppColors.available,
                        icon: Icons.check_circle_outline),
                    const SizedBox(width: 8),
                    _SummaryTile(
                        label: 'Dispatching',
                        count: dispatching,
                        color: AppColors.deployed,
                        icon: Icons.send_outlined),
                    const SizedBox(width: 8),
                    _SummaryTile(
                        label: 'Standby',
                        count: standby,
                        color: AppColors.maintenance,
                        icon: Icons.pause_circle_outline),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Critical pending households ────────────────────────────
            if (criticalPending.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: AppColors.critical, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'CRITICAL PENDING (${criticalPending.length})',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.critical),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final h = criticalPending[i];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.critical.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.critical
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          TriageBadge(level: h.triageLevel, compact: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.head,
                                    style: AppTextStyles.titleMedium),
                                Text(
                                  '${h.barangay}, ${h.city}',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(locateHouseholdProvider.notifier)
                                  .state = h.id;
                              context.go('/');
                            },
                            icon: const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.accent),
                            label: Text('Locate',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.accent)),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: criticalPending.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],

            // ── Asset list ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'FLEET',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.accent),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => AssetCard(
                  asset: assets[i],
                  onStatusChange: (status) => ref
                      .read(assetProvider.notifier)
                      .updateStatus(assets[i].id, status),
                ),
                childCount: assets.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryTile(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: color)),
                Text(label, style: AppTextStyles.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
