import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LegendWidget extends StatelessWidget {
  const LegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Binabaan ko yung bottom margin para hindi masyadong naka-angat
      margin: const EdgeInsets.only(left: 10, bottom: 0), 
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Triage Levels ─────────────────────────────────────────────
          _section('TRIAGE LEVELS'),
          _triageRow(AppColors.critical, 'Critical (Immobile)'),
          _triageRow(AppColors.high,     'High (Limited Mob.)'),
          _triageRow(AppColors.elevated, 'Elevated (Vuln.)'),
          _triageRow(const Color(0xFF238636), 'Rescued'),

          const SizedBox(height: 8),
          
          // ── Assets (Hardcoded based on screenshot) ───────────────────
          _section('ASSETS'),
          _assetRow('🚤', 'Rescue Boat'),
          _assetRow('🚑', 'Medic Team '),
          _assetRow('🚒', 'Transport Truck 01'), // Pwede mong palitan yung emoji kung gusto mo
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _triageRow(Color color, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );

  Widget _assetRow(String icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
}