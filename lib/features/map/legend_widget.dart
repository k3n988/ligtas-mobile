import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LegendWidget extends StatelessWidget {
  const LegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Keep your existing margin
      margin: const EdgeInsets.only(left: 10, bottom: 0), 
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // Light mode background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)), // Light border
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
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
          // Brighter green for "Rescued" to fit light mode better
          _triageRow(const Color(0xFF16A34A), 'Rescued'), 

          const SizedBox(height: 10),
          
          // ── Assets ───────────────────────────────────────────────────
          _section('ASSETS'),
          _assetRow('🚤', 'Rescue Boat'),
          _assetRow('🚑', 'Medic Team '),
          _assetRow('🚒', 'Transport Truck 01'),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1E293B), // Dark slate text for headings
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
                color: const Color(0xFF475569), // Slate gray for secondary text
                fontWeight: FontWeight.w600,
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
                color: const Color(0xFF475569), // Slate gray for secondary text
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}