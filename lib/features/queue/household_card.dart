import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/asset.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/triage_badge.dart';
import '../../features/auth/auth_provider.dart';
import '../../providers/app_state.dart';

class HouseholdCard extends ConsumerWidget {
  final Household household;
  final int queuePosition;

  const HouseholdCard({
    super.key,
    required this.household,
    required this.queuePosition,
  });

  Color get _accentColor => household.triageLevel.color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = household;
    final assets = ref.watch(assetProvider);
    final isRescued = h.isRescued;

    return Opacity(
      opacity: isRescued ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _accentColor.withValues(alpha: isRescued ? 0.2 : 0.4)),
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isRescued ? '✓' : '#$queuePosition',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: _accentColor, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.head, style: AppTextStyles.titleMedium),
                        Text('${h.barangay}, ${h.city}',
                            style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                  TriageBadge(level: h.triageLevel),
                ],
              ),
            ),

            // ── Details ─────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  _stat(Icons.group, '${h.occupants}', 'occupants'),
                  if (h.purok.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    _stat(Icons.place, h.purok, ''),
                  ],
                  const Spacer(),
                  if (h.vulnerabilities.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        children: h.vulnerabilities
                            .map((v) => Tooltip(
                                  message: v.label,
                                  child: Icon(v.icon,
                                      size: 14,
                                      color: v.triggersLevel.color),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),

            // ── Dispatch indicator ───────────────────────────────────────
            if (h.isDispatched)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: const BoxDecoration(
                    border:
                        Border(top: BorderSide(color: AppColors.divider))),
                child: Row(
                  children: [
                    const Icon(Icons.send, size: 14, color: AppColors.deployed),
                    const SizedBox(width: 6),
                    Text(
                      'Dispatched: ${_assetName(assets, h.assignedAssetId)}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.deployed),
                    ),
                    const Spacer(),
                    Text(_timeAgo(h.dispatchedAt!),
                        style: AppTextStyles.labelSmall),
                  ],
                ),
              ),

            // ── Actions ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Builder(builder: (context) {
                final isRescuer =
                    ref.watch(authProvider).role == UserRole.rescuer;
                return Row(
                  children: [
                    Text(_timeAgo(h.registeredAt),
                        style: AppTextStyles.labelSmall),
                    const Spacer(),
                    if (isRescuer) ...[
                      // Rescuer: full actions for CRITICAL, Mark Rescued for dispatched others
                      if (!isRescued) ...[
                        if (h.triageLevel == TriageLevel.critical) ...[
                          _actionBtn(
                            icon: Icons.location_on_outlined,
                            label: 'Locate',
                            color: AppColors.accent,
                            onTap: () {
                              ref
                                  .read(locateHouseholdProvider.notifier)
                                  .state = h.id;
                              context.go('/rescuer');
                            },
                          ),
                          const SizedBox(width: 8),
                          _actionBtn(
                            icon: Icons.send_outlined,
                            label: h.isDispatched ? 'Reassign' : 'Dispatch',
                            color: AppColors.deployed,
                            onTap: () =>
                                _showDispatchSheet(context, ref, h, assets),
                          ),
                          const SizedBox(width: 8),
                          _actionBtn(
                            icon: Icons.check_circle_outline,
                            label: 'Rescued',
                            color: AppColors.stable,
                            onTap: () => ref
                                .read(householdProvider.notifier)
                                .markRescued(h.id),
                          ),
                        ] else if (h.isDispatched)
                          _actionBtn(
                            icon: Icons.check_circle_outline,
                            label: 'Mark Rescued',
                            color: AppColors.stable,
                            onTap: () => ref
                                .read(householdProvider.notifier)
                                .markRescued(h.id),
                          ),
                      ],
                    ] else ...[
                      // Admin/LGU: Locate + Dispatch + Restore (no Mark Rescued)
                      if (!isRescued) ...[
                        _actionBtn(
                          icon: Icons.location_on_outlined,
                          label: 'Locate',
                          color: AppColors.accent,
                          onTap: () {
                            ref
                                .read(locateHouseholdProvider.notifier)
                                .state = h.id;
                            context.go('/');
                          },
                        ),
                        const SizedBox(width: 8),
                        _actionBtn(
                          icon: Icons.send_outlined,
                          label: h.isDispatched ? 'Reassign' : 'Dispatch',
                          color: AppColors.deployed,
                          onTap: () =>
                              _showDispatchSheet(context, ref, h, assets),
                        ),
                      ] else
                        _actionBtn(
                          icon: Icons.undo,
                          label: 'Restore',
                          color: AppColors.textSecondary,
                          onTap: () => ref
                              .read(householdProvider.notifier)
                              .restorePending(h.id),
                        ),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(value, style: AppTextStyles.bodyMedium),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.labelLarge
                    .copyWith(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _assetName(List<Asset> assets, String? id) {
    if (id == null) return '—';
    try {
      return assets.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return id;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
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
            Text('Assign Rescue Asset',
                style: AppTextStyles.headlineMedium),
            Text('Household: ${h.head}',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            if (available.isEmpty)
              Center(
                child: Text('No available assets',
                    style: AppTextStyles.bodyMedium),
              )
            else
              ...available.map((a) => _AssetTile(
                    asset: a,
                    isAssigned: h.assignedAssetId == a.id,
                    onSelect: () {
                      ref
                          .read(householdProvider.notifier)
                          .dispatchRescue(h.id, a.id);
                      ref
                          .read(assetProvider.notifier)
                          .updateStatus(a.id, AssetStatus.dispatching);
                      Navigator.pop(ctx);
                    },
                  )),
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

  const _AssetTile(
      {required this.asset,
      required this.isAssigned,
      required this.onSelect});

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
                  Text(asset.name, style: AppTextStyles.titleMedium),
                  Text('${asset.unit} · Cap: ${asset.capacity}',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(asset.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _statusColor(asset.status).withValues(alpha: 0.4)),
              ),
              child: Text(
                isAssigned ? 'Assigned' : asset.status.label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: _statusColor(asset.status)),
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
