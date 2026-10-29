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
const _authOnlyRoutes = {'/splash', '/verify-email', '/profile-setup'};
const _circleRequiredRoutes = {
  '/map',
  '/places',
  '/history',
  '/sharing',
  '/history/settings',
  '/notifications',
  '/notifications/settings',
};

bool _requiresCircle(String location) =>
    _circleRequiredRoutes.contains(location) || location.startsWith('/places/');

String? _safeInternalRedirect(String? value) {
  if (value == null || !value.startsWith('/') || value.startsWith('//')) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.path.isEmpty) return null;
  if (_publicRoutes.contains(uri.path) || _authOnlyRoutes.contains(uri.path)) return null;
  return uri.toString();
}

String _routeWithRedirect(String path, String? redirect) {
  if (redirect == null) return path;
  return Uri(path: path, queryParameters: {'redirect': redirect}).toString();
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(profileProvider, (_, __) => notifyListeners());
    // Refresh route gating as soon as circle membership becomes available or changes.
    _ref.listen(myCirclesProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final queryRedirect = _safeInternalRedirect(state.uri.queryParameters['redirect']);
    // Preserve a protected deep link while Firebase initializes, the user signs in,
    // and a new account completes profile setup/email verification.
    final currentProtectedLocation = (!_publicRoutes.contains(loc) && !_authOnlyRoutes.contains(loc))
        ? _safeInternalRedirect(state.uri.toString())
        : null;
    final requestedLocation = queryRedirect ?? currentProtectedLocation;

    final auth = _ref.read(authStateProvider);
    if (auth.isLoading) {
      if (loc == '/splash') return null;
      return _routeWithRedirect('/splash', requestedLocation);
    }

    final user = auth.valueOrNull;
    if (user == null) {
      if (_publicRoutes.contains(loc)) return null;
      return _routeWithRedirect('/login', requestedLocation);
    }

    // Google verifies the provider email; don't force Google-authenticated users
    // through the email/password verification screen.
    final trustedGoogleEmail = user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (!user.emailVerified && !trustedGoogleEmail) {
      if (loc == '/verify-email') return null;
      return _routeWithRedirect('/verify-email', requestedLocation);
    }

    final profile = _ref.read(profileProvider);
    if (profile.isLoading || profile.hasError) {
      if (loc == '/splash') return null;
      return _routeWithRedirect('/splash', requestedLocation);
    }
    if (profile.valueOrNull == null) {
      if (loc == '/profile-setup') return null;
      return _routeWithRedirect('/profile-setup', requestedLocation);
    }

    // Circle-first onboarding: first create or join a Circle. Hide/gate circle-dependent
    // surfaces until membership exists; if membership cannot be read before any cached result
    // is available, use one recovery screen rather than repeating Retry across feature tabs.
    if (_requiresCircle(loc)) {
      final circles = _ref.read(myCirclesProvider);
      final noKnownMembership = !circles.isLoading &&
          circles.hasValue &&
          (circles.valueOrNull?.isEmpty ?? true);
      final membershipCouldNotBeRead = circles.hasError && circles.valueOrNull == null;
      if (noKnownMembership || membershipCouldNotBeRead) {
        return '/circles';
      }
    }

    if (_publicRoutes.contains(loc) || _authOnlyRoutes.contains(loc)) {
      return requestedLocation ?? '/map';
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
      GoRoute(
        path: '/circles/join',
        builder: (_, state) => JoinCircleScreen(initialCode: state.uri.queryParameters['code']),
      ),
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

/// Main navigation adapts to circle membership: setup/Profile first, then Map, Places, History, Circles and Profile.
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

    const allPaths = ['/map', '/places', '/history', '/circles', '/profile'];
    const allDestinations = [
      NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
      NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place_rounded), label: 'Places'),
      NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Circles'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ];
    final circleState = ref.watch(myCirclesProvider);
    final hasCircles = !circleState.isLoading &&
        (circleState.valueOrNull?.isNotEmpty ?? false);
    // Before the first circle exists (or while membership could not be read), keep navigation
    // focused on setup and the profile. Map/Places/History are available after joining a circle.
    final paths = hasCircles ? allPaths : const ['/circles', '/profile'];
    final destinations = hasCircles
        ? allDestinations
        : const [
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Circles'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ];
    var index = paths.indexWhere((p) => widget.location.startsWith(p));
    if (index < 0) index = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    Container(
                      width: 238,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border(
                          right: BorderSide(color: scheme.outlineVariant.withOpacity(0.65)),
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
                              child: Row(
                                children: [
                                  const PremiumBrandMark(size: 42),
                                  const SizedBox(width: 11),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Circlo',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      Text(
                                        'STAY IN SYNC',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              letterSpacing: 1.25,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 0, 8),
                              child: Text(
                                'YOUR SPACE',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: NavigationRail(
                                extended: true,
                                minExtendedWidth: 218,
                                selectedIndex: index,
                                onDestinationSelected: (i) => context.go(paths[i]),
                                destinations: [
                                  for (final destination in destinations)
                                    NavigationRailDestination(
                                      icon: destination.icon,
                                      selectedIcon: destination.selectedIcon,
                                      label: Text(destination.label),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 16, 18),
                              child: Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your location. Your choice.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                )
              : widget.child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => context.go(paths[i]),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}
