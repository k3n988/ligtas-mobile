import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/asset.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'assets_provider.dart';
import 'asset_card.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetProvider);
    final available = assets.where((a) => a.status == AssetStatus.available).length;
    final deployed = assets.where((a) => a.status == AssetStatus.deployed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rescue Assets', style: AppTextStyles.headlineLarge),
                  const SizedBox(height: 4),
                  Text('${assets.length} total · $available available · $deployed deployed',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ),

            // ── Summary cards ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SummaryTile(
                    label: 'Available',
                    count: available,
                    color: AppColors.available,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 10),
                  _SummaryTile(
                    label: 'Deployed',
                    count: deployed,
                    color: AppColors.deployed,
                    icon: Icons.send_outlined,
                  ),
                  const SizedBox(width: 10),
                  _SummaryTile(
                    label: 'Maint.',
                    count: assets.where((a) => a.status == AssetStatus.maintenance).length,
                    color: AppColors.maintenance,
                    icon: Icons.build_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Asset list ──────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: assets.length,
                itemBuilder: (context, i) => AssetCard(
                  asset: assets[i],
                  onStatusChange: (status) =>
                      ref.read(assetProvider.notifier).updateStatus(assets[i].id, status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: AppTextStyles.headlineMedium.copyWith(color: color)),
                Text(label, style: AppTextStyles.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
