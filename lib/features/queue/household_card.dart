import 'package:flutter/material.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';

class HouseholdCard extends StatelessWidget {
  final Household household;
  final int queuePosition;
  final VoidCallback onRescue;

  const HouseholdCard({
    super.key,
    required this.household,
    required this.queuePosition,
    required this.onRescue,
  });

  Color get _accentColor {
    switch (household.triageLevel) {
      case TriageLevel.critical:
        return AppColors.critical;
      case TriageLevel.high:
        return AppColors.high;
      case TriageLevel.elevated:
        return AppColors.elevated;
      case TriageLevel.stable:
        return AppColors.stable;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Queue number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$queuePosition',
                    style: AppTextStyles.labelLarge.copyWith(color: _accentColor, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(household.headName, style: AppTextStyles.titleMedium),
                      Text(household.barangay, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                TriageBadge(level: household.triageLevel),
              ],
            ),
          ),

          // ── Stats row ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                _stat(Icons.group, '${household.memberCount}', 'members'),
                if (household.medicalCount > 0) ...[
                  const SizedBox(width: 16),
                  _stat(Icons.medical_services, '${household.medicalCount}', 'medical', color: AppColors.critical),
                ],
                if (household.elderlyCount > 0) ...[
                  const SizedBox(width: 16),
                  _stat(Icons.elderly, '${household.elderlyCount}', 'elderly'),
                ],
                if (household.infantCount > 0) ...[
                  const SizedBox(width: 16),
                  _stat(Icons.child_care, '${household.infantCount}', 'infant'),
                ],
                const Spacer(),
                _damageChip(household.damageLevel),
              ],
            ),
          ),

          // ── Action row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              children: [
                Text(
                  _timeAgo(household.registeredAt),
                  style: AppTextStyles.labelSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onRescue,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.stable.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.stable),
                  label: Text('Rescued', style: AppTextStyles.labelLarge.copyWith(color: AppColors.stable)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(value, style: AppTextStyles.titleMedium.copyWith(color: color)),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  Widget _damageChip(int level) {
    const labels = ['No Damage', 'Minor', 'Major', 'Destroyed'];
    const colors = [AppColors.stable, AppColors.elevated, AppColors.high, AppColors.critical];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors[level].withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors[level].withValues(alpha: 0.4)),
      ),
      child: Text(labels[level], style: AppTextStyles.labelSmall.copyWith(color: colors[level])),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
