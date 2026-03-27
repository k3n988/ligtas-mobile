import 'package:flutter/material.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';

class TriagePreviewCard extends StatelessWidget {
  final TriageLevel level;

  const TriagePreviewCard({super.key, required this.level});

  String get _description {
    switch (level) {
      case TriageLevel.critical:
        return 'Immediate evacuation required. Deploy rescue team now.';
      case TriageLevel.high:
        return 'Priority response needed within 1 hour.';
      case TriageLevel.elevated:
        return 'Monitor closely. Schedule assistance today.';
      case TriageLevel.stable:
        return 'Situation manageable. Queue for standard relief.';
    }
  }

  Color get _borderColor {
    switch (level) {
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Triage Assessment', style: AppTextStyles.labelSmall),
                const SizedBox(height: 4),
                Text(_description, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TriageBadge(level: level),
        ],
      ),
    );
  }
}
