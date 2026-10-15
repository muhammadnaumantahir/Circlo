import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets.dart';
import 'features/auth/auth_screens.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/circles/circles_screens.dart';
import 'features/history/history_screens.dart';
import 'features/location/map_screen.dart';
import 'features/location/sharing_screen.dart';
import 'features/places/notifications_screen.dart';
import 'features/circles/circle_models.dart';
import 'features/places/place_models.dart';
import 'features/places/places_screens.dart';
import 'features/profile/account_deletion_screen.dart';
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

    if (!user.emailVerified) {
      return loc == '/verify-email' ? null : '/verify-email';
    }

    final profile = _ref.read(profileProvider);
    if (profile.isLoading || profile.hasError) {
      return loc == '/splash' ? null : '/splash';
    }
    if (profile.valueOrNull == null) {
      return loc == '/profile-setup' ? null : '/profile-setup';
    }
    if (_publicRoutes.contains(loc) || loc == '/splash' || loc == '/profile-setup' || loc == '/verify-email') {
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
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: '/account/delete', builder: (_, __) => const DeleteAccountScreen()),
      GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          GoRoute(path: '/places', builder: (_, __) => const PlacesScreen()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/circles', builder: (_, __) => const CirclesScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/sharing', builder: (_, __) => const SharingScreen()),
      GoRoute(path: '/history/settings', builder: (_, __) => const HistorySettingsScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/notifications/settings', builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(
        path: '/places/new',
        builder: (_, state) => PlaceFormScreen(circleId: state.uri.queryParameters['circle'] ?? ''),
      ),
      GoRoute(
        path: '/places/:circleId/:placeId',
        builder: (_, state) => PlaceFormScreen(
          circleId: state.pathParameters['circleId']!,
          placeId: state.pathParameters['placeId'],
        ),
      ),
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

/// Bottom navigation (Map, Places, History, Circles, Profile).
/// Also announces new matching arrival/departure alerts with a snackbar while the app is open.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final DateTime _startedAt = DateTime.now();
  final Set<String> _announced = {};
  final Set<String> _completing = {};

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<FeedItem>>>(notificationFeedProvider, (_, next) {
      final items = next.valueOrNull;
      if (items == null) return;
      for (final item in items) {
        if (item.at.isAfter(_startedAt) && _announced.add(item.id)) {
          showSnack(context, item.text);
        }
      }
    });

    // When the owner approves one of our join requests, finish joining (create the membership).
    ref.listen<AsyncValue<List<JoinRequest>>>(myJoinRequestsProvider, (_, next) {
      final uid = ref.read(currentUidProvider);
      final name = ref.read(profileProvider).valueOrNull?.displayName;
      if (uid == null || name == null) return;
      for (final r in next.valueOrNull ?? const <JoinRequest>[]) {
        if (!r.approved || !_completing.add(r.circleId)) continue;
        ref.read(circlesRepositoryProvider).completeApprovedJoin(uid: uid, displayName: name, request: r).then((_) {
          if (mounted) showSnack(context, 'You were approved and joined a circle.');
        }).catchError((_) {
          _completing.remove(r.circleId); // retry on the next update
        });
      }
    });

    const paths = ['/map', '/places', '/history', '/circles', '/profile'];
    var index = paths.indexWhere((p) => widget.location.startsWith(p));
    if (index < 0) index = 0;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(paths[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place), label: 'Places'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Circles'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
