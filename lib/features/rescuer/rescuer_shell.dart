
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/household.dart';
import '../../core/models/triage_level.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_state.dart';
import '../auth/auth_provider.dart';

/// Bottom-nav shell shown to rescuers.
/// Gives access to Map (rescue operations) and Queue only.
class RescuerShell extends ConsumerStatefulWidget {
  final Widget child;
  const RescuerShell({super.key, required this.child});

  @override
  ConsumerState<RescuerShell> createState() => _RescuerShellState();
}

class _RescuerShellState extends ConsumerState<RescuerShell> {
  int _locationToIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/rescuer/queue')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Listen for newly dispatched households and fire banner
    ref.listen<List<Household>>(myDispatchedHouseholdsProvider, (prev, next) {
      final prevIds = (prev ?? []).map((h) => h.id).toSet();
      final newOnes = next.where((h) => !prevIds.contains(h.id)).toList();
      for (final h in newOnes) {
        _showDispatchBanner(context, h);
      }
    });

    final idx      = _locationToIndex(context);
    final username = ref.watch(authProvider).username ?? '';
    final display  = username.contains('@')
        ? username.split('@').first
        : username;

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _RescuerBadge(display: display, ref: ref, context: context),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/rescuer');
            case 1: context.go('/rescuer/queue');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Rescue Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Triage Queue',
          ),
        ],
      ),
    );
  }

  void _showDispatchBanner(BuildContext context, Household h) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF1A3A2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2E7D32)),
        ),
        content: Row(
          children: [
            const Icon(Icons.emergency, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DISPATCH ALERT',
                    style: TextStyle(
                      color: Color(0xFF81C784),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${h.head} · ${h.barangay}, ${h.city}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${h.triageLevel.label} · ${h.occupants} occupants',
                    style: TextStyle(
                      color: h.triageLevel.color,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: const Color(0xFF4CAF50),
          onPressed: () => context.go('/rescuer/queue'),
        ),
      ),
    );
  }
}

// ── Rescuer badge (top-right) ─────────────────────────────────────────────────

class _RescuerBadge extends StatelessWidget {
  final String display;
  final WidgetRef ref;
  final BuildContext context;
  const _RescuerBadge({
    required this.display,
    required this.ref,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: _showMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A2A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E7D32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('asset/logo2.png', width: 18, height: 18),
            const SizedBox(width: 6),
            const Icon(Icons.emergency, color: Color(0xFF4CAF50), size: 14),
            const SizedBox(width: 4),
            Text(
              display,
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Color(0xFF4CAF50), size: 14),
          ],
        ),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.emergency, color: Color(0xFF4CAF50), size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rescuer Account',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                      Text(ref.read(authProvider).username ?? '',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, indent: 20, endIndent: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFF85149)),
              title: const Text('Log Out',
                  style: TextStyle(
                      color: Color(0xFFF85149), fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
