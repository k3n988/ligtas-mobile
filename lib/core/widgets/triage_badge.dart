import 'package:flutter/material.dart';
import '../models/triage_level.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TriageBadge extends StatelessWidget {
  final TriageLevel level;
  final bool compact;

  const TriageBadge({super.key, required this.level, this.compact = false});

  Color get _bg {
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
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _bg.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        level.label,
        style: AppTextStyles.labelLarge.copyWith(
          fontSize: compact ? 10 : 11,
          color: level == TriageLevel.elevated ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }
}
