import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import 'location_models.dart';
import 'sharing_controller.dart';
import 'sharing_status.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
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

    final mapWidget = _buildMap(context, located, uid);
    final list = _buildList(context, ref, views, uid, now, membersAsync.isLoading, membersAsync.hasError);

    return Column(
      children: [
        _Header(circles: circles, selected: circle),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 900) {
                return Row(children: [
                  Expanded(flex: 3, child: mapWidget),
                  SizedBox(width: 360, child: list),
                ]);
              }
              return Column(children: [
                Expanded(flex: 3, child: mapWidget),
                Expanded(flex: 2, child: list),
              ]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMap(BuildContext context, List<_MemberView> located, String? uid) {
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
            TileLayer(urlTemplate: kMapTileUrl, userAgentPackageName: 'com.circlo.circlo'),
            MarkerLayer(markers: [
              for (final v in located)
                Marker(
                  point: LatLng(v.location!.lat, v.location!.lng),
                  width: 56,
                  height: 56,
                  child: Semantics(
                    label: '${v.member.displayName}, ${statusLabel(v.status)}',
                    child: _Avatar(name: v.member.displayName, color: _statusColor(context, v.status), size: 44),
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
                child: Text('Nobody is sharing a location with this circle right now.'),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 28,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: 'Show everyone',
            onPressed: () => onFit([for (final v in located) LatLng(v.location!.lat, v.location!.lng)]),
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
      itemCount: views.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final v = views[i];
        final name = v.member.uid == uid ? '${v.member.displayName} (you)' : v.member.displayName;
        final ago = v.location == null ? '' : ' · ${formatAgo(v.location!.updatedAt, now)}';
        return ListTile(
          leading: _Avatar(name: v.member.displayName, color: _statusColor(context, v.status), size: 40),
          title: Text(name),
          subtitle: Row(children: [
            Icon(_statusIcon(v.status), size: 16, color: _statusColor(context, v.status)),
            const SizedBox(width: 4),
            Flexible(child: Text('${statusLabel(v.status)}$ago')),
          ]),
          onTap: () => _showDetails(context, v, now),
        );
      },
    );
  }

  void _showDetails(BuildContext context, _MemberView v, DateTime now) {
    final loc = v.location;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Avatar(name: v.member.displayName, color: _statusColor(ctx, v.status), size: 48),
              const SizedBox(width: 12),
              Expanded(child: Text(v.member.displayName, style: Theme.of(ctx).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Icon(_statusIcon(v.status), color: _statusColor(ctx, v.status)),
              const SizedBox(width: 8),
              Text(statusLabel(v.status)),
            ]),
            const SizedBox(height: 8),
            if (loc == null)
              const Text('No location available.')
            else ...[
              Text('Last updated: ${formatAgo(loc.updatedAt, now)}'
                  '${loc.updatedAt == null ? '' : ' (${_formatDateTime(loc.updatedAt!)})'}'),
              const SizedBox(height: 4),
              Text('Position: ${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)} · accuracy ±${loc.accuracy.round()} m'),
              if (v.status == ShareStatus.unavailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('This is the last known location. It may be out of date.'),
                ),
            ],
          ],
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
    final memberships = ref.watch(myMembershipsProvider).valueOrNull ?? const <MyMembership>[];
    final active = memberships.where((m) => m.isActive).length;
    final pausedCount = memberships.where((m) => m.sharesLocation && m.paused).length;
    final label = active > 0
        ? 'Sharing with $active ${active == 1 ? 'circle' : 'circles'}'
        : (pausedCount > 0 ? 'Sharing paused' : 'Not sharing');
    final icon = active > 0 ? Icons.location_on : (pausedCount > 0 ? Icons.pause_circle_outline : Icons.visibility_off);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selected.id,
            underline: const SizedBox.shrink(),
            items: [for (final c in circles) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
            onChanged: (id) => ref.read(selectedCircleIdProvider.notifier).state = id,
          ),
        ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: () => context.push('/sharing'),
        ),
      ]),
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
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3), color: Theme.of(context).colorScheme.surface),
        alignment: Alignment.center,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
      );
}
