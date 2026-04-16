import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';
import '../../providers/app_state.dart';

class RescuerDashboard extends ConsumerWidget {
  const RescuerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final households = ref.watch(householdProvider);
    final assets     = ref.watch(assetProvider);
    final myAsset    = ref.watch(myAssetProvider);
    final dispatched = ref.watch(myDispatchedHouseholdsProvider);

    // Triage stats
    final total    = households.length;
    final rescued  = households.where((h) => h.isRescued).length;
    final critical = households.where((h) => !h.isRescued && h.triageLevel == TriageLevel.critical).length;
    final high     = households.where((h) => !h.isRescued && h.triageLevel == TriageLevel.high).length;
    final elevated = households.where((h) => !h.isRescued && h.triageLevel == TriageLevel.elevated).length;
    final stable   = households.where((h) => !h.isRescued && h.triageLevel == TriageLevel.stable).length;

    // Pending unassigned (no asset assigned, not rescued)
    final pending = households
        .where((h) => !h.isRescued && h.assignedAssetId == null)
        .toList()
      ..sort((a, b) => a.triageLevel.priority.compareTo(b.triageLevel.priority));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    Image.asset('asset/logo2.png', width: 28, height: 28),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'L.I.G.T.A.S.',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontSize: 17,
                            letterSpacing: 1.5,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          'Rescuer Dashboard',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Stat grid ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('INCIDENT SUMMARY'),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.3,
                      children: [
                        _StatCard(label: 'Critical',  count: critical, color: AppColors.critical),
                        _StatCard(label: 'High',      count: high,     color: AppColors.high),
                        _StatCard(label: 'Elevated',  count: elevated, color: AppColors.elevated),
                        _StatCard(label: 'Stable',    count: stable,   color: AppColors.stable),
                        _StatCard(label: 'Rescued',   count: rescued,  color: const Color(0xFF238636)),
                        _StatCard(label: 'Total',     count: total,    color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── My Asset ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('MY UNIT'),
                    const SizedBox(height: 10),
                    myAsset == null
                        ? _emptyCard('No asset assigned to your account.')
                        : _AssetCard(asset: myAsset, highlightAsMine: true),
                  ],
                ),
              ),
            ),

            // ── Dispatched to me ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('DISPATCHED TO MY UNIT (${dispatched.length})'),
                    const SizedBox(height: 10),
                    if (dispatched.isEmpty)
                      _emptyCard('No households dispatched to your unit yet.')
                    else
                      ...dispatched.map((h) => _HouseholdRow(household: h)),
                  ],
                ),
              ),
            ),

            // ── Pending unassigned ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('PENDING UNASSIGNED (${pending.length})'),
                    const SizedBox(height: 10),
                    if (pending.isEmpty)
                      _emptyCard('All households have been assigned.')
                    else
                      ...pending.take(8).map((h) => _HouseholdRow(household: h)),
                    if (pending.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '+ ${pending.length - 8} more in Triage Queue',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Assets deployed ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('ASSETS DEPLOYED (${assets.length})'),
                    const SizedBox(height: 10),
                    if (assets.isEmpty)
                      _emptyCard('No assets in the system.')
                    else
                      ...assets.map((a) => _AssetCard(asset: a)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(msg,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      );
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Household row ─────────────────────────────────────────────────────────────

class _HouseholdRow extends StatelessWidget {
  final Household household;
  const _HouseholdRow({required this.household});

  @override
  Widget build(BuildContext context) {
    final h = household;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: h.triageLevel.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          TriageBadge(level: h.triageLevel),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.head,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${h.barangay}, ${h.city}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${h.occupants} occ.',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Asset card ────────────────────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final Asset asset;
  final bool highlightAsMine;

  const _AssetCard({
    required this.asset,
    this.highlightAsMine = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = asset.status == AssetStatus.active
        ? const Color(0xFF238636)
        : asset.status == AssetStatus.dispatching
            ? AppColors.high
            : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlightAsMine
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Text(asset.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlightAsMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'Assigned Asset',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  asset.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (asset.unit.isNotEmpty)
                  Text(
                    '${asset.type} • ${asset.unit}',
                    style: AppTextStyles.labelSmall
                        .copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              asset.status.name.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
