import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/map/map_screen.dart';
import '../features/registration/registration_screen.dart';
import '../features/queue/queue_screen.dart';
import '../features/assets/assets_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        GoRoute(
          path: '/triage',
          builder: (context, state) => const QueueScreen(),
        ),
        GoRoute(
          path: '/dispatch',
          builder: (context, state) => const AssetsScreen(),
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  int _locationToIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc == '/register') return 1;
    if (loc == '/triage') return 2;
    if (loc == '/dispatch') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _locationToIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/register');
            case 2:
              context.go('/triage');
            case 3:
              context.go('/dispatch');
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
            label: 'Triage',
          ),
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send),
            label: 'Dispatch',
          ),
        ],
      ),
    );
  }
}
