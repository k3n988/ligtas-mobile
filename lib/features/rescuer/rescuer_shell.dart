import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/mesh_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_provider.dart';

/// Bottom-nav shell shown to rescuers.
/// Gives access to Dashboard, Map, and Queue only.
class RescuerShell extends ConsumerStatefulWidget {
  final Widget child;

  const RescuerShell({super.key, required this.child});

  @override
  ConsumerState<RescuerShell> createState() => _RescuerShellState();
}

class _RescuerShellState extends ConsumerState<RescuerShell> {
  @override
  void initState() {
    super.initState();
    ref.read(meshServiceProvider).init();
  }

  int _locationToIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/rescuer/dashboard')) return 0;
    if (loc.startsWith('/rescuer/queue')) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final idx      = _locationToIndex(context);
    final username = ref.watch(authProvider).username ?? '';
    final display  = username.contains('@') ? username.split('@').first : username;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _RescuerHeader(display: display, username: username, ref: ref),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/rescuer/dashboard');
            case 1:
              context.go('/rescuer');
            case 2:
              context.go('/rescuer/queue');
          }
        },
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon:         Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Rescue Map',
          ),
          NavigationDestination(
            icon:         Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Triage Queue',
          ),
        ],
      ),
    );
  }
}

class _RescuerHeader extends StatelessWidget {
  final String display;
  final String username;
  final WidgetRef ref;

  const _RescuerHeader({
    required this.display,
    required this.username,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Image.asset('asset/logo2.png', width: 36, height: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'L.I.G.T.A.S.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Rescuer Portal',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                display,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: Text(
                  'Log out',
                  style: TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
