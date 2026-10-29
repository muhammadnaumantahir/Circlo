import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Circle;
import 'package:url_launcher/url_launcher.dart';

import '../../core/map_config.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/activity.dart';
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

Future<void> _launchMemberContact(BuildContext context, String scheme, String phone) async {
  try {
    final launched = await launchUrl(
      Uri(scheme: scheme, path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) showSnack(context, 'Could not open the phone app.');
  } catch (_) {
    if (context.mounted) showSnack(context, 'Could not open the phone app.');
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
  bool _savingCheckIn = false;
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
            PremiumBrandMark(size: MediaQuery.sizeOf(context).width < 380 ? 32 : 38),
            SizedBox(width: MediaQuery.sizeOf(context).width < 380 ? 7 : 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Circlo', style: Theme.of(context).textTheme.titleLarge),
                if (MediaQuery.sizeOf(context).width >= 380)
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
          IconButton.filledTonal(
            tooltip: 'Share a manual check-in — no GPS attached',
            onPressed: _savingCheckIn ? null : _showCheckInSheet,
            icon: _savingCheckIn
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.task_alt_rounded),
          ),
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

  Future<void> _showCheckInSheet() async {
    if (_savingCheckIn) return;
    final circles = ref.read(myCirclesProvider).valueOrNull;
    final uid = ref.read(currentUidProvider);
    final displayName = ref.read(profileProvider).valueOrNull?.displayName.trim() ?? '';
    if (circles == null || circles.isEmpty || uid == null || displayName.isEmpty) {
      if (mounted) showSnack(context, 'Your profile and circle must be loaded before checking in.');
      return;
    }
    final selectedId = ref.read(selectedCircleIdProvider);
    final circle = circles.firstWhere((c) => c.id == selectedId, orElse: () => circles.first);
    final places = ref.read(placesProvider(circle.id)).valueOrNull ?? const <Place>[];
    final choice = await showModalBottomSheet<_CheckInChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _CheckInSheet(circle: circle, places: places),
    );
    if (!mounted || choice == null) return;

    setState(() => _savingCheckIn = true);
    try {
      await ref.read(circlesRepositoryProvider).createCheckIn(
            circleId: circle.id,
            uid: uid,
            displayName: displayName,
            status: choice.status,
            placeId: choice.place?.id,
            placeName: choice.place?.name,
          );
      if (mounted) {
        final placeSuffix = choice.place == null ? '' : ' at ${choice.place!.name}';
        showSnack(context, 'Check-in shared with ${circle.name}$placeSuffix. No GPS coordinates were sent.');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not share your check-in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _savingCheckIn = false);
    }
  }
}

class _CheckInChoice {
  const _CheckInChoice({required this.status, this.place});
  final String status;
  final Place? place;
}

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({required this.circle, required this.places});
  final Circle circle;
  final List<Place> places;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  String? _placeId;

  Place? get _selectedPlace {
    for (final place in widget.places) {
      if (place.id == _placeId) return place;
    }
    return null;
  }

  @override
  Widget build(BuildContext sheetContext) {
    final scheme = Theme.of(sheetContext).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Share a quick check-in', style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Shared with everyone in ${widget.circle.name}. This is a manual status, not GPS verification, and no coordinates are sent.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.places.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _placeId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Saved place (optional)',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('No saved place attached')),
                    for (final place in widget.places)
                      DropdownMenuItem<String>(
                        value: place.id,
                        child: Text(place.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _placeId = value == null || value.isEmpty ? null : value),
                ),
                const SizedBox(height: 8),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'You can check in without a saved place, or add one from Places later.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final entry in kCheckInStatuses.entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      switch (entry.key) {
                        'im_okay' => Icons.check_circle_rounded,
                        'arrived_safely' => Icons.home_rounded,
                        'on_my_way' => Icons.directions_walk_rounded,
                        _ => Icons.schedule_rounded,
                      },
                      color: scheme.primary,
                      size: 26,
                    ),
                    title: Text(entry.value, style: Theme.of(sheetContext).textTheme.titleSmall),
                    subtitle: Text(switch (entry.key) {
                      'im_okay' => 'Let your circle know you are okay',
                      'arrived_safely' => 'Tell them you reached your destination',
                      'on_my_way' => 'Share that you are travelling',
                      _ => 'Let them know your plans changed',
                    }),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(
                      _CheckInChoice(status: entry.key, place: _selectedPlace),
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

class _MapBody extends ConsumerStatefulWidget {
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
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

enum _MemberFilter { all, sharing, paused, unavailable, notSharing }

class _MapBodyState extends ConsumerState<_MapBody> {
  final TextEditingController _searchController = TextEditingController();
  late final Timer _statusRefreshTimer;
  String _query = '';
  _MemberFilter _filter = _MemberFilter.all;

  List<Circle> get circles => widget.circles;
  Circle get circle => widget.circle;
  MapController get controller => widget.controller;
  VoidCallback get onReady => widget.onReady;
  void Function(List<LatLng>) get onFit => widget.onFit;
  String? get fittedFor => widget.fittedFor;
  void Function(String) get markFitted => widget.markFitted;

  @override
  void initState() {
    super.initState();
    // Location snapshots can go quiet, so refresh age labels and stale status locally.
    // This timer only rebuilds the UI; it performs no Firebase reads or writes.
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _MapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circle.id != widget.circle.id) {
      _searchController.clear();
      _query = '';
      _filter = _MemberFilter.all;
    }
  }

  @override
  void dispose() {
    _statusRefreshTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final membersAsync = ref.watch(membersProvider(circle.id));
    final locationsAsync = ref.watch(locationsProvider(circle.id));
    final places = ref.watch(placesProvider(circle.id)).valueOrNull ?? const <Place>[];
    final sharedContacts = ref.watch(sharedContactsProvider(circle.id)).valueOrNull ?? const <SharedContact>[];
    final sharedPhones = {for (final contact in sharedContacts) contact.uid: contact.phone};
    final activityAsync = ref.watch(activityProvider(circle.id));
    final latestCheckIns = <String, ActivityEvent>{};
    for (final event in activityAsync.valueOrNull ?? const <ActivityEvent>[]) {
      if (event.type != ActivityType.checkedIn || event.actorUid.isEmpty || event.occurredAt == null) continue;
      final previous = latestCheckIns[event.actorUid];
      if (previous == null || event.occurredAt!.isAfter(previous.occurredAt!)) {
        latestCheckIns[event.actorUid] = event;
      }
    }
    final now = DateTime.now();

    final members = membersAsync.valueOrNull ?? const <Member>[];
    final locations = locationsAsync.valueOrNull ?? const <String, MemberLocation>{};
    final views = [for (final m in members) _MemberView(m, locations[m.uid], now)];
    final allLocated = [for (final v in views) if (v.location != null) v];
    final points = [for (final v in allLocated) LatLng(v.location!.lat, v.location!.lng)];
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleViews = [
      for (final v in views)
        if (_matchesFilter(v.status) &&
            (normalizedQuery.isEmpty || v.member.displayName.toLowerCase().contains(normalizedQuery)))
          v,
    ];
    final located = [for (final v in visibleViews) if (v.location != null) v];

    // Fit the camera once per circle as soon as there is something to show.
    if (points.isNotEmpty && fittedFor != circle.id) {
      markFitted(circle.id);
      WidgetsBinding.instance.addPostFrameCallback((_) => onFit(points));
    }

    final mapWidget = _buildMap(context, ref, visibleViews, located, uid, places, latestCheckIns, sharedPhones);
    final list = _buildList(context, ref, visibleViews, uid, now, membersAsync.isLoading, membersAsync.hasError, latestCheckIns, sharedPhones);
    final peopleOnly = ref.watch(_peopleListModeProvider);

    return Column(
      children: [
        _Header(circles: circles, selected: circle),
        _buildPeopleSearchFilters(context, views),
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

  bool _matchesFilter(ShareStatus status) {
    switch (_filter) {
      case _MemberFilter.all:
        return true;
      case _MemberFilter.sharing:
        return status == ShareStatus.sharing;
      case _MemberFilter.paused:
        return status == ShareStatus.paused;
      case _MemberFilter.unavailable:
        return status == ShareStatus.unavailable;
      case _MemberFilter.notSharing:
        return status == ShareStatus.notSharing;
    }
  }

  Widget _buildPeopleSearchFilters(BuildContext context, List<_MemberView> views) {
    final scheme = Theme.of(context).colorScheme;
    int countFor(ShareStatus status) => views.where((v) => v.status == status).length;

    Widget chip(String label, int count, _MemberFilter filter) => Padding(
          padding: const EdgeInsets.only(right: 7),
          child: ChoiceChip(
            label: Text('$label $count'),
            selected: _filter == filter,
            onSelected: (_) => setState(() => _filter = filter),
            visualDensity: VisualDensity.compact,
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search people in this circle',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear people search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: .45),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('All', views.length, _MemberFilter.all),
                chip('Sharing', countFor(ShareStatus.sharing), _MemberFilter.sharing),
                chip('Paused', countFor(ShareStatus.paused), _MemberFilter.paused),
                chip('Unavailable', countFor(ShareStatus.unavailable), _MemberFilter.unavailable),
                chip('Not sharing', countFor(ShareStatus.notSharing), _MemberFilter.notSharing),
              ],
            ),
          ),
          if (_query.trim().isNotEmpty || _filter != _MemberFilter.all)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Showing ${views.where((v) => _matchesFilter(v.status) && (_query.trim().isEmpty || v.member.displayName.toLowerCase().contains(_query.trim().toLowerCase()))).length} of ${views.length} people',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _filter = _MemberFilter.all;
                        });
                      },
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    WidgetRef ref,
    List<_MemberView> views,
    List<_MemberView> located,
    String? uid,
    List<Place> places,
    Map<String, ActivityEvent> latestCheckIns,
    Map<String, String> sharedPhones,
  ) {
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
                    onTap: () => _showDetails(context, v, DateTime.now(), latestCheckIn: latestCheckIns[v.member.uid], sharedPhone: sharedPhones[v.member.uid]),
                    child: GestureDetector(
                      onTap: () => _showDetails(context, v, DateTime.now(), latestCheckIn: latestCheckIns[v.member.uid], sharedPhone: sharedPhones[v.member.uid]),
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
        if (views.isEmpty && (_query.trim().isNotEmpty || _filter != _MemberFilter.all))
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No people match the current search or status filter. Clear the search or choose All to see everyone.'),
              ),
            ),
          )
        else if (located.isEmpty)
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
              onMemberTap: (v) => _showDetails(context, v, DateTime.now(), latestCheckIn: latestCheckIns[v.member.uid], sharedPhone: sharedPhones[v.member.uid]),
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

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<_MemberView> views,
    String? uid,
    DateTime now,
    bool loading,
    bool hasError,
    Map<String, ActivityEvent> latestCheckIns,
    Map<String, String> sharedPhones,
  ) {
    if (loading && views.isEmpty) return const LoadingView();
    if (hasError) return const MessageView(icon: Icons.lock_outline, title: 'Could not load members');
    if (views.isEmpty) {
      final filtering = _query.trim().isNotEmpty || _filter != _MemberFilter.all;
      return MessageView(
        icon: filtering ? Icons.search_off_rounded : Icons.groups_outlined,
        title: filtering ? 'No matching people' : 'No members to show',
        message: filtering
            ? 'Try another name or status, or clear your filters to see everyone in this circle.'
            : 'Circle members will appear here when available.',
        actions: filtering
            ? [
                OutlinedButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _filter = _MemberFilter.all;
                    });
                  },
                  child: const Text('Clear search and filters'),
                ),
              ]
            : const [],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: views.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final v = views[i];
        final name = v.member.uid == uid ? '${v.member.displayName} (you)' : v.member.displayName;
        final ago = v.location == null ? '' : ' · ${formatAgo(v.location!.updatedAt, now)}';
        final checkIn = latestCheckIns[v.member.uid];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: _Avatar(name: v.member.displayName, color: _statusColor(context, v.status), size: 40),
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_statusIcon(v.status), size: 16, color: _statusColor(context, v.status)),
                    const SizedBox(width: 6),
                    Flexible(child: Text('${statusLabel(v.status)}$ago')),
                  ],
                ),
                if (checkIn?.occurredAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Manual check-in: ${kCheckInStatuses[checkIn!.checkInStatus] ?? 'Check-in shared'} · ${formatAgo(checkIn.occurredAt, now)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => _showDetails(
              context,
              v,
              now,
              latestCheckIn: latestCheckIns[v.member.uid],
              sharedPhone: sharedPhones[v.member.uid],
            ),
          ),
        );
      },
    );
  }

  void _showDetails(
    BuildContext context,
    _MemberView v,
    DateTime now, {
    ActivityEvent? latestCheckIn,
    String? sharedPhone,
  }) {
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
            child: SingleChildScrollView(
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
                            Text(v.member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(v.member.isOwner ? 'Circle owner' : 'Circle member', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
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
                            Text(statusLabel(v.status), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (sharedPhone != null && v.member.uid != ref.read(currentUidProvider)) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, color: scheme.primary, size: 19),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Phone shared with this circle',
                                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SelectableText(
                            sharedPhone,
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _launchMemberContact(ctx, 'tel', sharedPhone),
                                  icon: const Icon(Icons.call_rounded),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _launchMemberContact(ctx, 'sms', sharedPhone),
                                  icon: const Icon(Icons.sms_outlined),
                                  label: const Text('Text'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (latestCheckIn != null && latestCheckIn.occurredAt != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.task_alt_rounded, color: scheme.secondary, size: 19),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Latest manual check-in',
                                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                              Text(
                                formatAgo(latestCheckIn.occurredAt, now),
                                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kCheckInStatuses[latestCheckIn.checkInStatus] ?? 'Check-in shared',
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Shared ${_formatDateTime(latestCheckIn.occurredAt!)}',
                            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if ((latestCheckIn.checkInPlaceName ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'At ${latestCheckIn.checkInPlaceName}',
                              style: Theme.of(ctx).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Self-reported by ${latestCheckIn.actorName}; not verified by GPS.',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
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
