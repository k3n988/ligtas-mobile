import 'package:flutter/material.dart';
import '../../core/models/asset.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final void Function(AssetStatus) onStatusChange;

  const AssetCard(
      {super.key, required this.asset, required this.onStatusChange});

  Color get _statusColor {
    switch (asset.status) {
      case AssetStatus.active:      return AppColors.available;
      case AssetStatus.dispatching: return AppColors.deployed;
      case AssetStatus.standby:     return AppColors.maintenance;
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
          // ── Main row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(asset.icon,
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name, style: AppTextStyles.titleLarge),
                      Text('${asset.type} · ${asset.unit}',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    asset.status.label.toUpperCase(),
                    style: AppTextStyles.labelSmall
                        .copyWith(color: _statusColor, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ───────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider))),
            child: Row(
              children: [
                Icon(Icons.people_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Cap: ${asset.capacity}',
                    style: AppTextStyles.bodyMedium),
                const SizedBox(width: 16),
                Icon(Icons.gps_fixed,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${asset.latitude.toStringAsFixed(4)}, ${asset.longitude.toStringAsFixed(4)}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),

          // ── Status toggle ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              children: AssetStatus.values.map((s) {
                final isActive = asset.status == s;
                final c = _colorFor(s);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: s != AssetStatus.standby ? 8 : 0),
                    child: GestureDetector(
                      onTap: isActive ? null : () => onStatusChange(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive
                              ? c.withValues(alpha: 0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isActive
                                  ? c
                                  : AppColors.divider),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          s.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isActive ? c : AppColors.textMuted,
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

  Color _colorFor(AssetStatus s) {
    switch (s) {
      case AssetStatus.active:      return AppColors.available;
      case AssetStatus.dispatching: return AppColors.deployed;
      case AssetStatus.standby:     return AppColors.maintenance;
    }
  }
}
