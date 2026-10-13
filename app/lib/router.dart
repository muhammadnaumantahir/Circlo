import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets.dart';
import 'features/auth/auth_screens.dart';
import 'features/circles/circles_screens.dart';
import 'features/location/map_screen.dart';
import 'features/location/sharing_screen.dart';
import 'features/profile/profile_screens.dart';
import 'providers.dart';

const _publicRoutes = {'/login', '/signup', '/reset'};

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(profileProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final auth = _ref.read(authStateProvider);
    if (auth.isLoading) return loc == '/splash' ? null : '/splash';

    final user = auth.valueOrNull;
    if (user == null) return _publicRoutes.contains(loc) ? null : '/login';

    final profile = _ref.read(profileProvider);
    if (profile.isLoading || profile.hasError) {
      return loc == '/splash' ? null : '/splash';
    }
    if (profile.valueOrNull == null) {
      return loc == '/profile-setup' ? null : '/profile-setup';
    }
    if (_publicRoutes.contains(loc) || loc == '/splash' || loc == '/profile-setup') {
      return '/map';
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/reset', builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          GoRoute(path: '/circles', builder: (_, __) => const CirclesScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/sharing', builder: (_, __) => const SharingScreen()),
      GoRoute(path: '/circles/create', builder: (_, __) => const CreateCircleScreen()),
      GoRoute(path: '/circles/join', builder: (_, __) => const JoinCircleScreen()),
      GoRoute(
        path: '/circles/:id',
        builder: (_, state) => CircleDetailScreen(circleId: state.pathParameters['id']!),
      ),
    ],
  );
});

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      body: profile.hasError
          ? MessageView(
              icon: Icons.cloud_off,
              title: 'Could not load your account',
              message: 'Check your connection and try again.',
              actions: [
                FilledButton(onPressed: () => ref.invalidate(profileProvider), child: const Text('Retry')),
                OutlinedButton(onPressed: () => ref.read(authRepositoryProvider).signOut(), child: const Text('Log out')),
              ],
            )
          : const LoadingView(),
    );
  }
}

/// Bottom navigation for the screens that exist so far (Map, Circles, Profile).
/// Places and History tabs are added with their features.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/profile') ? 2 : (location.startsWith('/circles') ? 1 : 0);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(const ['/map', '/circles', '/profile'][i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Circles'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
