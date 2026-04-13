import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/landing_screen.dart';
import '../features/map/map_screen.dart';
import '../features/registration/registration_screen.dart';
import '../features/queue/queue_screen.dart';
import '../features/assets/assets_screen.dart';
import '../features/rescuer/rescuer_shell.dart';
import '../features/rescuer/rescuer_dashboard.dart';
import '../features/citizen/citizen_screen.dart';
import '../core/theme/app_colors.dart';

// ── Router provider ────────────────────────────────────────────────────────────
// Exposed as a Riverpod provider so it can read auth state and re-evaluate
// redirects whenever login / logout happens.

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/landing',
    refreshListenable: authNotifier,
    redirect: (context, routerState) {
      final auth      = ref.read(authProvider);
      final location  = routerState.matchedLocation;
      final onLanding = location == '/landing';

      // ── Not logged in → landing ────────────────────────────────────────
      if (!auth.isLoggedIn) {
        return onLanding ? null : '/landing';
      }

      // ── Logged in on landing → role home ──────────────────────────────
      if (onLanding) return _homeForRole(auth.role);

      // ── Guard wrong-role routes ────────────────────────────────────────
      final inRescuer = location.startsWith('/rescuer');
      final inCitizen = location.startsWith('/citizen');
      final inAdmin   = !inRescuer && !inCitizen && !onLanding;

      switch (auth.role) {
        case UserRole.rescuer:
          if (!inRescuer) return '/rescuer/dashboard';
        case UserRole.citizen:
          if (!inCitizen) return '/citizen';
        case UserRole.admin:
          if (!inAdmin) return '/';
        case UserRole.unknown:
          return '/landing';
      }
      return null;
    },
    routes: [
      // ── Public ─────────────────────────────────────────────────────────
      GoRoute(path: '/landing', builder: (_, __) => const LandingScreen()),

      // ── Admin / LGU shell ───────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/',         builder: (_, __) => const MapScreen()),
          GoRoute(path: '/register', builder: (_, __) => const RegistrationScreen()),
          GoRoute(path: '/triage',   builder: (_, __) => const QueueScreen()),
          GoRoute(path: '/dispatch', builder: (_, __) => const AssetsScreen()),
        ],
      ),

      // ── Rescuer shell ───────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => RescuerShell(child: child),
        routes: [
          GoRoute(path: '/rescuer/dashboard', builder: (_, __) => const RescuerDashboard()),
          GoRoute(path: '/rescuer',           builder: (_, __) => const MapScreen()),
          GoRoute(path: '/rescuer/queue',     builder: (_, __) => const QueueScreen()),
        ],
      ),

      // ── Citizen portal ──────────────────────────────────────────────────
      GoRoute(path: '/citizen', builder: (_, __) => const CitizenScreen()),
    ],
  );
});

String _homeForRole(UserRole role) {
  switch (role) {
    case UserRole.rescuer: return '/rescuer/dashboard';
    case UserRole.citizen: return '/citizen';
    case UserRole.admin:   return '/';
    case UserRole.unknown: return '/landing';
  }
}

// ── ChangeNotifier bridge ──────────────────────────────────────────────────────

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _sub = ref.listen(authProvider, (_, __) => notifyListeners());
  }
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

// ── App shell (bottom nav + logout) ───────────────────────────────────────────

class _AppShell extends ConsumerWidget {
  final Widget child;
  const _AppShell({required this.child});

  int _locationToIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc == '/register') return 1;
    if (loc == '/triage')   return 2;
    if (loc == '/dispatch') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx      = _locationToIndex(context);
    final username = ref.watch(authProvider).username ?? '';

    return Scaffold(
      body: Stack(
        children: [
          child,

          // ── User badge + logout (top-right, inside safe area) ────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _UserBadge(username: username, ref: ref, context: context),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/');
            case 1: context.go('/register');
            case 2: context.go('/triage');
            case 3: context.go('/dispatch');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.app_registration_outlined),
            selectedIcon: Icon(Icons.app_registration),
            label: 'Register',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency),
            label: 'Assets',
          ),
        ],
      ),
    );
  }
}

// ── User badge (shows username + logout popup) ────────────────────────────────

class _UserBadge extends StatelessWidget {
  final String username;
  final WidgetRef ref;
  final BuildContext context;

  const _UserBadge({
    required this.username,
    required this.ref,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    // Show short identifier (first part before @ or first 10 chars)
    final display = username.contains('@')
        ? username.split('@').first
        : (username.length > 10 ? '${username.substring(0, 10)}…' : username);

    return GestureDetector(
      onTap: () => _showLogoutMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('asset/logo2.png', width: 20, height: 20, fit: BoxFit.contain),
            const SizedBox(width: 5),
            Text(
              display,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more,
                color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  void _showLogoutMenu() {
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
                  const Icon(Icons.person, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Signed in as',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11)),
                        Text(username,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, indent: 20, endIndent: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFF85149)),
              title: const Text('Log Out',
                  style: TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.w600)),
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
