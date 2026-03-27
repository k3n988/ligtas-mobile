import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LegendWidget extends StatelessWidget {
  const LegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(AppColors.critical),
          _label('Critical'),
          const SizedBox(width: 10),
          _dot(AppColors.high),
          _label('High'),
          const SizedBox(width: 10),
          _dot(AppColors.elevated),
          _label('Elevated'),
          const SizedBox(width: 10),
          _dot(AppColors.stable),
          _label('Stable'),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _label(String text) =>
      Text(text, style: AppTextStyles.labelSmall.copyWith(fontSize: 11));
}
