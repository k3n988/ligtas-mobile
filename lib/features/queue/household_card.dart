import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/auth_provider.dart';
import '../../providers/app_state.dart';

class HouseholdCard extends ConsumerWidget {
  final Household household;
  final int queuePosition;
  final bool isInHazardZone;
  final List<String> matchingHazardTypes;
  final TriageLevel? effectiveLevel;

  const HouseholdCard({
    super.key,
    required this.household,
    required this.queuePosition,
    this.isInHazardZone = false,
    this.matchingHazardTypes = const [],
    this.effectiveLevel,
  });

  TriageLevel get _level => effectiveLevel ?? household.triageLevel;
  Color get _accentColor => _level.color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h       = household;
    final assets  = ref.watch(assetProvider);
    final isRescued = h.isRescued;
    final isRescuer = ref.watch(authProvider).role == UserRole.rescuer;

    final assignedAsset = h.assignedAssetId != null
        ? assets.cast<Asset?>().firstWhere(
            (a) => a?.id == h.assignedAssetId,
            orElse: () => null)
        : null;

    final myAsset = ref.watch(myAssetProvider);
    final isAssignedToMe =
        myAsset != null && h.assignedAssetId == myAsset.id;
    final isAssignedElsewhere =
        h.assignedAssetId != null && !isAssignedToMe;

    return Opacity(
      opacity: isRescued ? 0.74 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isRescued ? AppColors.stable : _accentColor,
              width: 4,
            ),
            top:    BorderSide(color: AppColors.divider),
            right:  BorderSide(color: AppColors.divider),
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name + triage badge ──────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      h.head,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRescued ? 'RESCUED' : _level.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isRescued ? AppColors.stable : _accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Address ──────────────────────────────────────────────
              Text(
                '${h.street.isNotEmpty ? '${h.street}, ' : ''}'
                'Brgy. ${h.barangay}, ${h.city}'
                ' - ${h.occupants} occupant${h.occupants != 1 ? 's' : ''}',
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
              ),

              // ── Source ────────────────────────────────────────────────
              if (h.source != null && h.source!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Source: ${_sourceLabel(h.source!)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 11, color: AppColors.accent),
                ),
              ],

              // ── Vulnerability tags ───────────────────────────────────
              if (h.vulnerabilities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: h.vulnerabilities
                      .map((v) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(v.label,
                                style: AppTextStyles.labelSmall
                                    .copyWith(fontSize: 10)),
                          ))
                      .toList(),
                ),
              ],

              // ── Dispatched asset row ─────────────────────────────────
              if (assignedAsset != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${assignedAsset.icon} ${assignedAsset.name} - dispatched',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.deployed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (!isRescuer)
                        GestureDetector(
                          onTap: () => _showDispatchSheet(
                              context, ref, h, assets),
                          child: Text('Reassign',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Action buttons ───────────────────────────────────────
              if (isRescued)
                Row(
                  children: [
                    Text('Operation Complete',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.stable,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _outlineBtn(
                      label: 'Restore',
                      color: AppColors.textSecondary,
                      onTap: () => ref
                          .read(householdProvider.notifier)
                          .restorePending(h.id),
                    ),
                  ],
                )
              else if (isRescuer)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _filledBtn(
                        label: isAssignedToMe
                            ? 'EN ROUTE'
                            : isAssignedElsewhere
                                ? 'ASSIGNED ELSEWHERE'
                                : 'RESPOND',
                        color: isAssignedToMe
                            ? AppColors.deployed
                            : isAssignedElsewhere
                                ? AppColors.surface
                                : AppColors.critical,
                        textColor: isAssignedElsewhere
                            ? AppColors.textSecondary
                            : Colors.white,
                        onTap: isAssignedElsewhere || myAsset == null
                            ? null
                            : () {
                                ref
                                    .read(householdProvider.notifier)
                                    .dispatchRescue(h.id, myAsset.id);
                                ref
                                    .read(assetProvider.notifier)
                                    .updateStatus(
                                        myAsset.id, AssetStatus.dispatching);
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _outlineBtn(
                        label: 'LOCATE',
                        color: AppColors.accent,
                        onTap: () {
                          ref.read(locateHouseholdProvider.notifier).state =
                              h.id;
                          context.go('/rescuer');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _outlineBtn(
                        label: 'COMPLETE RESCUE',
                        color: AppColors.stable,
                        onTap: () => ref
                            .read(householdProvider.notifier)
                            .markRescued(h.id),
                      ),
                    ),
                  ],
                )
              else
                // Admin / LGU
                Row(
                  children: [
                    Expanded(
                      child: _outlineBtn(
                        label: 'LOCATE',
                        color: AppColors.accent,
                        onTap: () {
                          ref.read(locateHouseholdProvider.notifier).state =
                              h.id;
                          context.go('/');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _filledBtn(
                        label: assignedAsset != null
                            ? 'REASSIGN'
                            : 'DISPATCH RESCUE',
                        color: AppColors.critical,
                        textColor: Colors.white,
                        onTap: () =>
                            _showDispatchSheet(context, ref, h, assets),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _outlineBtn(
                        label: 'MARK RESCUED',
                        color: AppColors.stable,
                        onTap: () => ref
                            .read(householdProvider.notifier)
                            .markRescued(h.id),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filledBtn({
    required String label,
    required Color color,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.surface : color,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: onTap == null ? AppColors.textSecondary : textColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _outlineBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'lgu':    return 'BHW Field Survey';
      case 'citizen': return 'Citizen Self-Report';
      default:       return source;
    }
  }

  void _showDispatchSheet(
    BuildContext context,
    WidgetRef ref,
    Household h,
    List<Asset> assets,
  ) {
    final available =
        assets.where((a) => a.isAvailable || a.id == h.assignedAssetId).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Assign Rescue Asset', style: AppTextStyles.headlineMedium),
            Text('Household: ${h.head}', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            if (available.isEmpty)
              Center(
                  child: Text('No available assets',
                      style: AppTextStyles.bodyMedium))
            else
              ...available.map((a) => _AssetTile(
                    asset: a,
                    isAssigned: h.assignedAssetId == a.id,
                    onSelect: () {
                      ref
                          .read(householdProvider.notifier)
                          .dispatchRescue(h.id, a.id);
                      ref
                          .read(assetProvider.notifier)
                          .updateStatus(a.id, AssetStatus.dispatching);
                      Navigator.pop(ctx);
                    },
                  )),
          ],
        ),
      ),
    );
  }
}

// ── Asset tile (bottom sheet) ─────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  final Asset asset;
  final bool isAssigned;
  final VoidCallback onSelect;

  const _AssetTile(
      {required this.asset, required this.isAssigned, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAssigned
              ? AppColors.deployed.withValues(alpha: 0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isAssigned ? AppColors.deployed : AppColors.divider),
        ),
        child: Row(
          children: [
            Text(asset.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: AppTextStyles.titleMedium),
                  Text('${asset.unit} · Cap: ${asset.capacity}',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(asset.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _statusColor(asset.status).withValues(alpha: 0.4)),
              ),
              child: Text(
                isAssigned ? 'Assigned' : asset.status.label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: _statusColor(asset.status)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AssetStatus s) {
    switch (s) {
      case AssetStatus.active:      return AppColors.available;
      case AssetStatus.dispatching: return AppColors.deployed;
      case AssetStatus.standby:     return AppColors.maintenance;
    }
  }
}
