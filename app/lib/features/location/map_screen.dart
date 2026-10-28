import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../../core/map_config.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import '../places/notifications_screen.dart';
import '../places/place_models.dart';
import 'directions.dart';
import 'location_models.dart';
import 'sharing_controller.dart';
import 'sharing_status.dart';

/// False = map view, true = full-height people list on compact screens.
final _peopleListModeProvider = StateProvider<bool>((ref) => false);

Color _statusColor(BuildContext context, ShareStatus s) {
  switch (s) {
    case ShareStatus.sharing:
      return const Color(0xFF16A34A);
    case ShareStatus.paused:
      return const Color(0xFFD97706);
    case ShareStatus.unavailable:
    case ShareStatus.notSharing:
      return Theme.of(context).colorScheme.outline;
  }
}

IconData _statusIcon(ShareStatus s) {
  switch (s) {
    case ShareStatus.sharing:
      return Icons.location_on;
    case ShareStatus.paused:
      return Icons.pause_circle_outline;
    case ShareStatus.unavailable:
      return Icons.location_off;
    case ShareStatus.notSharing:
      return Icons.visibility_off;
  }
}

String _formatDateTime(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.day} ${months[l.month - 1]}, ${two(l.hour)}:${two(l.minute)}';
}

/// One row of display data for a member (merged from member doc + location doc).
class _MemberView {
  _MemberView(this.member, this.location, DateTime now)
      : status = deriveStatus(
          sharesLocation: member.sharesLocation,
          paused: member.paused,
          updatedAt: location?.updatedAt,
          now: now,
        );
  final Member member;
  final MemberLocation? location;
  final ShareStatus status;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _controller = MapController();
  bool _ready = false;
  String? _fittedFor;

  void _fit(List<LatLng> pts) {
    if (!_ready || pts.isEmpty) return;
    if (pts.length == 1) {
      _controller.move(pts.first, 15);
    } else {
      _controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the sharing engine alive while the app is open (it reacts to the user's switches).
    ref.watch(sharingControllerProvider);
    final circlesAsync = ref.watch(myCirclesProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final profileName = profile?.displayName.trim() ?? '';
    final profileInitial = profileName.isEmpty ? '?' : profileName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumBrandMark(size: 38),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Circlo', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'YOUR PEOPLE, IN SYNC',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const NotificationsBell(),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Profile & settings',
              onPressed: () => context.go('/profile'),
              icon: CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: Text(
                  profileInitial,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
      body: circlesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => MessageView(
          icon: Icons.cloud_off,
          title: 'Could not load your circles',
          message: 'Check your connection and try again.',
          actions: [FilledButton(onPressed: () => ref.invalidate(myCirclesProvider), child: const Text('Retry'))],
        ),
        data: (circles) {
          if (circles.isEmpty) {
            return MessageView(
              icon: Icons.map_outlined,
              title: 'No circles yet',
              message: 'Create or join a circle to see your people on the map.',
              actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Go to circles'))],
            );
          }
          final selectedId = ref.watch(selectedCircleIdProvider);
          final circle = circles.firstWhere((c) => c.id == selectedId, orElse: () => circles.first);
          return _MapBody(
            circles: circles,
            circle: circle,
            controller: _controller,
            onReady: () => _ready = true,
            onFit: _fit,
            fittedFor: _fittedFor,
            markFitted: (id) => _fittedFor = id,
          );
        },
      ),
    );
  }
}

class _MapBody extends ConsumerWidget {
  const _MapBody({
    required this.circles,
    required this.circle,
    required this.controller,
    required this.onReady,
    required this.onFit,
    required this.fittedFor,
    required this.markFitted,
  });

  final List<Circle> circles;
  final Circle circle;
  final MapController controller;
  final VoidCallback onReady;
  final void Function(List<LatLng>) onFit;
  final String? fittedFor;
  final void Function(String) markFitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final membersAsync = ref.watch(membersProvider(circle.id));
    final locationsAsync = ref.watch(locationsProvider(circle.id));
    final places = ref.watch(placesProvider(circle.id)).valueOrNull ?? const <Place>[];
    final now = DateTime.now();

    final members = membersAsync.valueOrNull ?? const <Member>[];
    final locations = locationsAsync.valueOrNull ?? const <String, MemberLocation>{};
    final views = [for (final m in members) _MemberView(m, locations[m.uid], now)];
    final located = [for (final v in views) if (v.location != null) v];
    final points = [for (final v in located) LatLng(v.location!.lat, v.location!.lng)];

    // Fit the camera once per circle as soon as there is something to show.
    if (points.isNotEmpty && fittedFor != circle.id) {
      markFitted(circle.id);
      WidgetsBinding.instance.addPostFrameCallback((_) => onFit(points));
    }

    final mapWidget = _buildMap(context, ref, views, located, uid, places);
    final list = _buildList(context, ref, views, uid, now, membersAsync.isLoading, membersAsync.hasError);
    final peopleOnly = ref.watch(_peopleListModeProvider);

    return Column(
      children: [
        _Header(circles: circles, selected: circle),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.desktop_windows_rounded,
                    size: 19,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Web sharing stays active only while this tab is open.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 900) {
                return Row(children: [
                  Expanded(flex: 3, child: mapWidget),
                  SizedBox(width: 360, child: list),
                ]);
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.map_outlined),
                          label: Text('Map'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.groups_outlined),
                          label: Text('People'),
                        ),
                      ],
                      selected: {peopleOnly},
                      onSelectionChanged: (selection) {
                        ref.read(_peopleListModeProvider.notifier).state = selection.first;
                      },
                    ),
                  ),
                  Expanded(child: peopleOnly ? list : mapWidget),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMap(BuildContext context, WidgetRef ref, List<_MemberView> views, List<_MemberView> located, String? uid, List<Place> places) {
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: const LatLng(20, 0),
            initialZoom: 2,
            onMapReady: onReady,
          ),
          children: [
            TileLayer(urlTemplate: kMapTileUrl, userAgentPackageName: 'com.circlo.app'),
            CircleLayer(circles: [
              for (final p in places)
                CircleMarker(
                  point: LatLng(p.lat, p.lng),
                  radius: p.radiusM,
                  useRadiusInMeter: true,
                  color: const Color(0x260D9488),
                  borderColor: const Color(0xFF0D9488),
                  borderStrokeWidth: 2,
                ),
            ]),
            MarkerLayer(markers: [
              for (final p in places)
                Marker(
                  point: LatLng(p.lat, p.lng),
                  width: 110,
                  height: 44,
                  child: Semantics(
                    label: 'Saved place ${p.name}',
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.place, size: 22, color: Color(0xFF0D9488)),
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
            MarkerLayer(markers: [
              for (final v in located)
                Marker(
                  point: LatLng(v.location!.lat, v.location!.lng),
                  width: 116,
                  height: 78,
                  child: Semantics(
                    button: true,
                    label: '${v.member.displayName}, ${statusLabel(v.status)}. Open member details.',
                    onTap: () => _showDetails(context, v, DateTime.now()),
                    child: GestureDetector(
                      onTap: () => _showDetails(context, v, DateTime.now()),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Avatar(name: v.member.displayName, color: _statusColor(context, v.status), size: 42),
                          const SizedBox(height: 3),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 112),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .75)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              v.member.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution(kMapAttribution)]),
          ],
        ),
        if (located.isEmpty)
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No location updates to show yet. Members may be offline, paused, or still waiting for a GPS fix.'),
              ),
            ),
          ),
        if (MediaQuery.sizeOf(context).width < 900)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _PeoplePeekCard(
              views: views,
              onAllPeople: () => ref.read(_peopleListModeProvider.notifier).state = true,
              onMemberTap: (v) => _showDetails(context, v, DateTime.now()),
              onPlaces: () => context.go('/places'),
              onSharing: () => context.push('/sharing'),
            ),
          ),
        Positioned(
          right: 18,
          bottom: MediaQuery.sizeOf(context).width < 900 ? 194 : 24,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: 'Show everyone',
            onPressed: located.isEmpty ? null : () => onFit([for (final v in located) LatLng(v.location!.lat, v.location!.lng)]),
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<_MemberView> views, String? uid,
      DateTime now, bool loading, bool hasError) {
    if (loading && views.isEmpty) return const LoadingView();
    if (hasError) return const MessageView(icon: Icons.lock_outline, title: 'Could not load members');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: views.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final v = views[i];
        final name = v.member.uid == uid ? '${v.member.displayName} (you)' : v.member.displayName;
        final ago = v.location == null ? '' : ' · ${formatAgo(v.location!.updatedAt, now)}';
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: _Avatar(name: v.member.displayName, color: _statusColor(context, v.status), size: 40),
            title: Text(name),
            subtitle: Row(children: [
              Icon(_statusIcon(v.status), size: 16, color: _statusColor(context, v.status)),
              const SizedBox(width: 6),
              Flexible(child: Text('${statusLabel(v.status)}$ago')),
            ]),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => _showDetails(context, v, now),
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context, _MemberView v, DateTime now) {
    final loc = v.location;
    final statusColor = _statusColor(context, v.status);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(name: v.member.displayName, color: statusColor, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.member.displayName, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('Circle member', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(v.status), color: statusColor, size: 17),
                          const SizedBox(width: 6),
                          Text(statusLabel(v.status), style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (loc == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_off_outlined),
                        SizedBox(width: 10),
                        Expanded(child: Text('No location is available. Sharing may be off, paused, or waiting for a GPS fix.')),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: scheme.primary, size: 19),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Last location update', style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${formatAgo(loc.updatedAt, now)}${loc.updatedAt == null ? '' : ' · ${_formatDateTime(loc.updatedAt!)}'}',
                                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.gps_fixed_rounded, color: scheme.primary, size: 19),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text('Estimated GPS accuracy ±${loc.accuracy.round()} m', style: Theme.of(ctx).textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (v.status == ShareStatus.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'This is the last known location and may be out of date.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok = await launchDirections(loc.lat, loc.lng);
                        if (!ok && ctx.mounted) showSnack(ctx, 'Could not open a maps app.');
                      },
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Get directions'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PeoplePeekCard extends StatelessWidget {
  const _PeoplePeekCard({
    required this.views,
    required this.onAllPeople,
    required this.onMemberTap,
    required this.onPlaces,
    required this.onSharing,
  });

  final List<_MemberView> views;
  final VoidCallback onAllPeople;
  final ValueChanged<_MemberView> onMemberTap;
  final VoidCallback onPlaces;
  final VoidCallback onSharing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sharing = views.where((v) => v.status == ShareStatus.sharing).length;
    final paused = views.where((v) => v.status == ShareStatus.paused).length;
    final status = sharing > 0
        ? '$sharing sharing now'
        : (paused > 0 ? '$paused paused' : 'No active location updates');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .75)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: CircloPalette.brand.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_rounded, color: CircloPalette.brand, size: 20),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your people', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text(
                        '$status · ${views.length} ${views.length == 1 ? 'member' : 'members'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onAllPeople,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 9)),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (views.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Members will appear here when the circle loads.'),
              )
            else
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: views.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final v = views[index];
                    return Semantics(
                      button: true,
                      label: 'View ${v.member.displayName}. ${statusLabel(v.status)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onMemberTap(v),
                        child: SizedBox(
                          width: 54,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Avatar(name: v.member.displayName, color: _statusColor(context, v.status), size: 38),
                              const SizedBox(height: 4),
                              Text(
                                v.member.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickMapAction(
                    icon: Icons.place_rounded,
                    label: 'Saved places',
                    color: CircloPalette.mint,
                    onTap: onPlaces,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickMapAction(
                    icon: Icons.tune_rounded,
                    label: 'Sharing settings',
                    color: CircloPalette.violet,
                    onTap: onSharing,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMapAction extends StatelessWidget {
  const _QuickMapAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.circles, required this.selected});
  final List<Circle> circles;
  final Circle selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final memberships = ref.watch(myMembershipsProvider).valueOrNull ?? const <MyMembership>[];
    final active = memberships.where((m) => m.isActive).length;
    final pausedCount = memberships.where((m) => m.sharesLocation && m.paused).length;
    final label = active > 0
        ? 'Sharing with $active ${active == 1 ? 'circle' : 'circles'}'
        : (pausedCount > 0 ? 'Sharing paused' : 'Not sharing');
    final icon = active > 0
        ? Icons.location_on_rounded
        : (pausedCount > 0 ? Icons.pause_circle_outline_rounded : Icons.visibility_off_rounded);
    final chipBackground = active > 0
        ? scheme.primaryContainer
        : (pausedCount > 0 ? scheme.secondaryContainer : scheme.surface);
    final chipForeground = active > 0
        ? scheme.onPrimaryContainer
        : (pausedCount > 0 ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.65)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.groups_rounded, color: scheme.onPrimaryContainer, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selected.id,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.unfold_more_rounded, size: 20),
              style: theme.textTheme.titleMedium,
              items: [
                for (final c in circles)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => ref.read(selectedCircleIdProvider.notifier).state = id,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 174),
            child: ActionChip(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              side: BorderSide.none,
              backgroundColor: chipBackground,
              avatar: Icon(icon, size: 17, color: chipForeground),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: chipForeground,
                fontWeight: FontWeight.w700,
              ),
              onPressed: () => context.push('/sharing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, required this.size});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: color, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .20),
              blurRadius: 9,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .12),
          ),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      );
}
