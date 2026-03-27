import 'package:flutter/material.dart';
import '../../core/models/asset.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final void Function(AssetStatus) onStatusChange;

  const AssetCard({super.key, required this.asset, required this.onStatusChange});

  Color get _statusColor {
    switch (asset.status) {
      case AssetStatus.available:
        return AppColors.available;
      case AssetStatus.deployed:
        return AppColors.deployed;
      case AssetStatus.maintenance:
        return AppColors.maintenance;
    }
  }

  IconData get _typeIcon {
    switch (asset.type) {
      case AssetType.boat:
        return Icons.directions_boat;
      case AssetType.truck:
        return Icons.local_shipping;
      case AssetType.helicopter:
        return Icons.flight;
      case AssetType.medicalTeam:
        return Icons.local_hospital;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // ── Main row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Type icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name, style: AppTextStyles.titleLarge),
                      Text(asset.type.label, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    asset.status.label.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(color: _statusColor, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          // ── Details row ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(asset.location, style: AppTextStyles.bodyMedium)),
                Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Cap: ${asset.capacity}', style: AppTextStyles.bodyMedium),
              ],
            ),
          ),

          // ── Status actions ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              children: AssetStatus.values.map((s) {
                final isActive = asset.status == s;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: s != AssetStatus.maintenance ? 8 : 0),
                    child: GestureDetector(
                      onTap: isActive ? null : () => onStatusChange(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? _statusColorFor(s).withValues(alpha: 0.2) : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? _statusColorFor(s) : AppColors.divider,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          s.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isActive ? _statusColorFor(s) : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColorFor(AssetStatus s) {
    switch (s) {
      case AssetStatus.available:
        return AppColors.available;
      case AssetStatus.deployed:
        return AppColors.deployed;
      case AssetStatus.maintenance:
        return AppColors.maintenance;
    }
  }
}
