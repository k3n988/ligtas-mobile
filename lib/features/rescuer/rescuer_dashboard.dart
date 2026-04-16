import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';
import '../../providers/app_state.dart';
import '../../providers/active_hazards_provider.dart';

class RescuerDashboard extends ConsumerStatefulWidget {
  const RescuerDashboard({super.key});

  @override
  ConsumerState<RescuerDashboard> createState() => _RescuerDashboardState();
}

class _RescuerDashboardState extends ConsumerState<RescuerDashboard> {
  // null = TOTAL (all), or 'CRITICAL' / 'HIGH' / 'ELEVATED' / 'STABLE' / 'RESCUED'
  String? _filter;
  String _selectedHazardId = 'ALL';

  @override
  Widget build(BuildContext context) {
    final households    = ref.watch(householdProvider);
    final assets        = ref.watch(assetProvider);
    final myAsset       = ref.watch(myAssetProvider);
    final dispatched    = ref.watch(myDispatchedHouseholdsProvider);
    final activeHazards = ref.watch(activeHazardsProvider);

    final incidentLabel = activeHazards.isNotEmpty
        ? activeHazards.map((h) => h.type).join(', ')
        : null;

    final allPending = households.where((h) => !h.isRescued).toList();
    final rescued    = households.where((h) =>  h.isRescued).length;
    final critical   = allPending.where((h) => h.triageLevel == TriageLevel.critical).length;
    final high       = allPending.where((h) => h.triageLevel == TriageLevel.high).length;
    final elevated   = allPending.where((h) => h.triageLevel == TriageLevel.elevated).length;
    final stable     = allPending.where((h) => h.triageLevel == TriageLevel.stable).length;

    // Report rows driven by stat card tap
    final List<Household> reportRows;
    if (_filter == 'RESCUED') {
      reportRows = households.where((h) => h.isRescued).toList();
    } else if (_filter != null) {
      final level = TriageLevel.values.firstWhere(
        (l) => l.label == _filter,
        orElse: () => TriageLevel.stable,
      );
      reportRows = allPending
          .where((h) => h.triageLevel == level)
          .toList()
        ..sort((a, b) => a.triageLevel.priority.compareTo(b.triageLevel.priority));
    } else {
      reportRows = [...households]
        ..sort((a, b) {
          if (a.isRescued != b.isRescued) return a.isRescued ? 1 : -1;
          return a.triageLevel.priority.compareTo(b.triageLevel.priority);
        });
    }

    // Operational: pending unassigned
    final pendingUnassigned = households
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
                          'Incident Summary Report',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _copyReport(
                        context: context,
                        households: households,
                        assets: assets,
                        reportRows: reportRows,
                        incidentLabel: incidentLabel,
                        critical: critical,
                        high: high,
                        elevated: elevated,
                        stable: stable,
                        rescued: rescued,
                        pending: allPending.length,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_outlined, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Copy',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Incident label ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidentLabel != null
                          ? 'ACTIVE: ${incidentLabel.toUpperCase()}'
                          : 'NO ACTIVE INCIDENT',
                      style: TextStyle(
                        color: incidentLabel != null
                            ? const Color(0xFFFF4D4D)
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      incidentLabel != null
                          ? 'This summary includes households registered during the active incident.'
                          : 'No active hazard layer — showing all registered households.',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Disaster selector (only when 2+ active hazards) ────────────
            if (activeHazards.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FILTER BY DISASTER',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _HazardPill(
                              label: 'All Disasters',
                              isSelected: _selectedHazardId == 'ALL',
                              onTap: () => setState(() {
                                _selectedHazardId = 'ALL';
                                _filter = null;
                              }),
                            ),
                            ...activeHazards.map((h) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _HazardPill(
                                    label: h.type,
                                    isSelected: _selectedHazardId == h.id,
                                    dotColor: const Color(0xFFFF4D4D),
                                    onTap: () => setState(() {
                                      _selectedHazardId = h.id;
                                      _filter = null;
                                    }),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Stat cards (tappable → filters report table) ───────────────
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
                        _StatCard(
                          label: 'CRITICAL', count: critical,
                          color: AppColors.critical,
                          isActive: _filter == 'CRITICAL',
                          onTap: () => setState(() =>
                              _filter = _filter == 'CRITICAL' ? null : 'CRITICAL'),
                        ),
                        _StatCard(
                          label: 'HIGH', count: high,
                          color: AppColors.high,
                          isActive: _filter == 'HIGH',
                          onTap: () => setState(() =>
                              _filter = _filter == 'HIGH' ? null : 'HIGH'),
                        ),
                        _StatCard(
                          label: 'ELEVATED', count: elevated,
                          color: AppColors.elevated,
                          isActive: _filter == 'ELEVATED',
                          onTap: () => setState(() =>
                              _filter = _filter == 'ELEVATED' ? null : 'ELEVATED'),
                        ),
                        _StatCard(
                          label: 'STABLE', count: stable,
                          color: AppColors.stable,
                          isActive: _filter == 'STABLE',
                          onTap: () => setState(() =>
                              _filter = _filter == 'STABLE' ? null : 'STABLE'),
                        ),
                        _StatCard(
                          label: 'RESCUED', count: rescued,
                          color: const Color(0xFF238636),
                          isActive: _filter == 'RESCUED',
                          onTap: () => setState(() =>
                              _filter = _filter == 'RESCUED' ? null : 'RESCUED'),
                        ),
                        _StatCard(
                          label: 'TOTAL', count: households.length,
                          color: AppColors.textSecondary,
                          isActive: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Filtered households report ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3, height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${incidentLabel != null ? '${incidentLabel.toUpperCase()} AFFECTED' : 'ALL'} HOUSEHOLDS (${reportRows.length})',
                            style: _sectionTitleStyle(),
                          ),
                        ),
                        if (_filter != null)
                          GestureDetector(
                            onTap: () => setState(() => _filter = null),
                            child: Text(
                              '✕ Clear filter',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (reportRows.isEmpty)
                      _emptyCard(incidentLabel != null
                          ? 'No households inside the active ${incidentLabel.toLowerCase()} hazard layer.'
                          : 'No households registered yet.')
                    else
                      ...reportRows.map((h) => _ReportHouseholdRow(
                            household: h,
                            assets: assets,
                          )),
                  ],
                ),
              ),
            ),

            // ── My Unit ────────────────────────────────────────────────────
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
                        : _MyUnitHeroCard(asset: myAsset, dispatchedCount: dispatched.length),
                  ],
                ),
              ),
            ),

            // ── Dispatched to my unit ──────────────────────────────────────
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
                    _sectionTitle('PENDING UNASSIGNED (${pendingUnassigned.length})'),
                    const SizedBox(height: 10),
                    if (pendingUnassigned.isEmpty)
                      _emptyCard('All households have been assigned.')
                    else
                      ...pendingUnassigned.take(8).map((h) => _HouseholdRow(household: h)),
                    if (pendingUnassigned.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '+ ${pendingUnassigned.length - 8} more in Triage Queue',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Assets ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3, height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('ASSETS (${assets.length})', style: _sectionTitleStyle()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (assets.isEmpty)
                      _emptyCard('No assets in the system.')
                    else
                      ...assets.map((a) {
                        final assignedCount = households
                            .where((h) => !h.isRescued && h.assignedAssetId == a.id)
                            .length;
                        return _AssetCard(asset: a, assignedCount: assignedCount);
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyReport({
    required BuildContext context,
    required List<Household> households,
    required List<Asset> assets,
    required List<Household> reportRows,
    required String? incidentLabel,
    required int critical,
    required int high,
    required int elevated,
    required int stable,
    required int rescued,
    required int pending,
  }) {
    final now = DateTime.now();
    final ts  = '${now.month}/${now.day}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final lines = [
      'L.I.G.T.A.S. INCIDENT SUMMARY REPORT',
      'Generated: $ts — Bacolod City DRRMO Command Center',
      'Incident: ${incidentLabel ?? 'None'}',
      '',
      'CRITICAL: $critical  HIGH: $high  ELEVATED: $elevated  STABLE: $stable',
      'RESCUED: $rescued  PENDING: $pending  TOTAL: ${households.length}',
      '',
      '=== ${incidentLabel != null ? '${incidentLabel.toUpperCase()} AFFECTED' : 'ALL'} HOUSEHOLDS ===',
      ...reportRows.map((h) {
        final assetList = assets.where((a) => a.id == h.assignedAssetId);
        final assetName = assetList.isNotEmpty ? assetList.first.name : 'Unassigned';
        final src = (h.source?.isNotEmpty == true) ? h.source! : '-';
        return '${h.head} | ${h.triageLevel.label} | ${h.barangay}, ${h.city} | $src | ${h.isRescued ? "Rescued" : "Pending"} | $assetName';
      }),
      '',
      '=== ASSETS ===',
      ...assets.map((a) => '${a.name} | ${a.type} | ${a.unit} | ${a.status.label}'),
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  TextStyle _sectionTitleStyle() => const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      );

  Widget _sectionTitle(String text) => Text(text, style: _sectionTitleStyle());

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(msg,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
      );
}

// ── Hazard filter pill ────────────────────────────────────────────────────────

class _HazardPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? dotColor;
  final VoidCallback onTap;

  const _HazardPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0A67D0);
    final selColor = dotColor ?? accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? selColor.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? selColor : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected ? selColor : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.25),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? color : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report household row (detailed, with source / asset / dispatched at) ──────

class _ReportHouseholdRow extends StatelessWidget {
  final Household household;
  final List<Asset> assets;

  const _ReportHouseholdRow({required this.household, required this.assets});

  @override
  Widget build(BuildContext context) {
    final h = household;
    final assetList = assets.where((a) => a.id == h.assignedAssetId);
    final asset     = assetList.isNotEmpty ? assetList.first : null;

    final isRescued   = h.isRescued;
    final statusColor  = isRescued ? const Color(0xFF3FB950) : const Color(0xFFD29922);
    final statusBg     = isRescued ? const Color(0xFF0D2016) : const Color(0xFF2B1D0A);
    final statusBorder = isRescued ? const Color(0xFF238636) : const Color(0xFF9E6A03);

    String? dispFmt;
    if (h.dispatchedAt != null) {
      final dt = h.dispatchedAt!.toLocal();
      dispFmt = '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: h.triageLevel.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TriageBadge(level: h.triageLevel),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.head,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${h.barangay}, ${h.city}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  isRescued ? 'RESCUED' : 'PENDING',
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          if (asset != null || (h.source?.isNotEmpty == true) || dispFmt != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (h.source?.isNotEmpty == true)
                  _chip(Icons.label_outline, h.source!.toUpperCase()),
                if (asset != null)
                  _chip(Icons.directions_car_outlined, '${asset.icon} ${asset.name}'),
                if (dispFmt != null)
                  _chip(Icons.schedule, dispFmt),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(text, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
        ],
      );
}

// ── Compact household row (operational sections) ──────────────────────────────

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
        border: Border.all(color: h.triageLevel.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TriageBadge(level: h.triageLevel),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.head,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Text('${h.barangay}, ${h.city}',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('${h.occupants} occ.',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Asset card ────────────────────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final Asset asset;
  final int assignedCount;
  final bool highlightAsMine;

  const _AssetCard({
    required this.asset,
    this.assignedCount = 0,
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
          color: highlightAsMine ? AppColors.accent.withValues(alpha: 0.45) : AppColors.divider,
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
                Text(asset.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('${asset.type} • ${asset.unit}',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary, fontSize: 11)),
                if (assignedCount > 0)
                  Text(
                    '$assignedCount household${assignedCount > 1 ? 's' : ''} assigned',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600),
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
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── My Unit hero card ─────────────────────────────────────────────────────────

class _MyUnitHeroCard extends StatelessWidget {
  final Asset asset;
  final int dispatchedCount;

  const _MyUnitHeroCard({required this.asset, required this.dispatchedCount});

  @override
  Widget build(BuildContext context) {
    final statusColor = asset.status == AssetStatus.active
        ? const Color(0xFF238636)
        : asset.status == AssetStatus.dispatching
            ? AppColors.high
            : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2D4A), Color(0xFF13253D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(asset.icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ASSIGNED UNIT',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.accent, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    const SizedBox(height: 3),
                    Text(asset.name,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${asset.type} • ${asset.unit}',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  asset.status.name.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _heroStat(label: 'Capacity', value: '${asset.capacity}', color: AppColors.textPrimary)),
              const SizedBox(width: 10),
              Expanded(child: _heroStat(
                label: 'Dispatched',
                value: '$dispatchedCount',
                color: dispatchedCount > 0 ? AppColors.high : const Color(0xFF238636),
              )),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/rescuer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.map, size: 18),
              label: const Text(
                'OPEN RESCUE MAP',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary, fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: AppTextStyles.titleMedium.copyWith(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
