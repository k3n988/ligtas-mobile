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
    final h = household;
    final assets = ref.watch(assetProvider);
    final isRescued = h.isRescued;
    final isRescuer = ref.watch(authProvider).role == UserRole.rescuer;

    final assignedAsset = h.assignedAssetId != null
        ? assets.cast<Asset?>().firstWhere(
            (a) => a?.id == h.assignedAssetId,
            orElse: () => null,
          )
        : null;

    final myAsset = ref.watch(myAssetProvider);
    final isAssignedToMe = myAsset != null && h.assignedAssetId == myAsset.id;
    final isAssignedElsewhere = h.assignedAssetId != null && !isAssignedToMe;
    final canCompleteRescue = isAssignedToMe;

    return Opacity(
      opacity: isRescued ? 0.78 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    isRescued
                        ? 'DONE'
                        : queuePosition > 0
                            ? '#$queuePosition'
                            : 'QUEUE',
                    style: TextStyle(
                      color: isRescued ? AppColors.stable : _accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                if (isInHazardZone && matchingHazardTypes.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x33FF4D4D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0x66FF4D4D),
                      ),
                    ),
                    child: Text(
                      matchingHazardTypes.join(', ').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFF8A80),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              h.head.isEmpty ? 'Unnamed Household' : h.head,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  isRescued ? 'RESCUED' : _level.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isRescued ? AppColors.stable : _accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${h.occupants} occupant${h.occupants != 1 ? 's' : ''}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (h.source != null && h.source!.isNotEmpty)
                  Text(
                    _sourceLabel(h.source!),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${h.street.isNotEmpty ? '${h.street}, ' : ''}Brgy. ${h.barangay}, ${h.city}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (h.vulnerabilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: h.vulnerabilities
                    .map(
                      (v) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          v.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (assignedAsset != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${assignedAsset.icon} ${assignedAsset.name} dispatched',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isRescuer)
                      GestureDetector(
                        onTap: () => _showDispatchSheet(context, ref, h, assets),
                        child: Text(
                          'Reassign',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (isRescued)
              Row(
                children: [
                  Text(
                    'Operation Complete',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.stable,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                            : () async {
                                if (!isAssignedToMe) {
                                  await ref
                                      .read(householdProvider.notifier)
                                      .dispatchRescue(h.id, myAsset.id);
                                }
                                ref.read(dispatchHouseholdProvider.notifier).state =
                                    h.id;
                                if (context.mounted) {
                                  context.go('/rescuer');
                                }
                              },
                      ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _outlineBtn(
                      label: 'LOCATE',
                      color: AppColors.accent,
                      onTap: () {
                        ref.read(locateHouseholdProvider.notifier).state = h.id;
                        context.go('/rescuer');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _outlineBtn(
                      label: 'COMPLETE',
                      color: canCompleteRescue
                          ? AppColors.stable
                          : AppColors.textSecondary,
                      onTap: canCompleteRescue
                          ? () => ref
                              .read(householdProvider.notifier)
                              .markRescued(h.id)
                          : null,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _outlineBtn(
                      label: 'LOCATE',
                      color: AppColors.accent,
                      onTap: () {
                        ref.read(locateHouseholdProvider.notifier).state = h.id;
                        context.go('/');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filledBtn(
                      label: assignedAsset != null ? 'REASSIGN' : 'DISPATCH',
                      color: AppColors.critical,
                      textColor: Colors.white,
                      onTap: () => _showDispatchSheet(context, ref, h, assets),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _outlineBtn(
                      label: 'RESCUED',
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.surface : color,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: onTap == null ? AppColors.textSecondary : textColor,
            fontSize: 9,
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: onTap == null ? AppColors.textSecondary : color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'lgu':
        return 'BHW Field Survey';
      case 'citizen':
        return 'Citizen Self-Report';
      default:
        return source;
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
            Text(
              'Household: ${h.head}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (available.isEmpty)
              Center(
                child: Text(
                  'No available assets',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            else
              ...available.map(
                (a) => _AssetTile(
                  asset: a,
                  isAssigned: h.assignedAssetId == a.id,
                  onSelect: () {
                    ref.read(householdProvider.notifier).dispatchRescue(h.id, a.id);
                    Navigator.pop(ctx);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final Asset asset;
  final bool isAssigned;
  final VoidCallback onSelect;

  const _AssetTile({
    required this.asset,
    required this.isAssigned,
    required this.onSelect,
  });

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
            color: isAssigned ? AppColors.deployed : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Text(asset.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${asset.unit} · Cap: ${asset.capacity}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(asset.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _statusColor(asset.status).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                isAssigned ? 'Assigned' : asset.status.label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: _statusColor(asset.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AssetStatus s) {
    switch (s) {
      case AssetStatus.active:
        return AppColors.available;
      case AssetStatus.dispatching:
        return AppColors.deployed;
      case AssetStatus.standby:
        return AppColors.maintenance;
    }
  }
}
