import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../../core/map_config.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import '../location/location_access.dart';
import 'geocoder.dart';
import 'notifications_screen.dart';
import 'place_models.dart';

String _alertSummary(PlaceSubscription? s, {bool loading = false, bool unavailable = false}) {
  if (loading) return unavailable ? 'Alert settings unavailable' : 'Loading alert settings';
  if (s?.paused == true) return 'Alerts paused';
  if (s == null || !s.enabled) return 'Alerts off';
  final what = s.arrive && s.leave ? 'arrivals & departures' : (s.arrive ? 'arrivals' : 'departures');
  return 'Alerts: $what${s.allMembers ? '' : ' (selected members)'}';
}

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Places'),
        actions: [
          const NotificationsBell(),
        ],
      ),
      body: circlesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => MessageView(
          icon: Icons.cloud_off,
          title: 'Could not load your circles',
          actions: [FilledButton(onPressed: () => ref.invalidate(myCirclesProvider), child: const Text('Retry'))],
        ),
        data: (circles) {
          if (circles.isEmpty) {
            return MessageView(
              icon: Icons.place_outlined,
              title: 'No circles yet',
              message: 'Places belong to a circle. Create or join one first.',
              actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Go to circles'))],
            );
          }
          final selectedId = ref.watch(selectedCircleIdProvider);
          final circle = circles.firstWhere((c) => c.id == selectedId, orElse: () => circles.first);
          return _PlacesBody(circles: circles, circle: circle);
        },
      ),
    );
  }
}

class _PlacesBody extends ConsumerStatefulWidget {
  const _PlacesBody({required this.circles, required this.circle});
  final List<Circle> circles;
  final Circle circle;

  @override
  ConsumerState<_PlacesBody> createState() => _PlacesBodyState();
}

enum _PlaceFilter { all, alertsOn, alertsOff }

class _PlacesBodyState extends ConsumerState<_PlacesBody> {
  _PlaceFilter _filter = _PlaceFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(covariant _PlacesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circle.id != widget.circle.id) {
      _filter = _PlaceFilter.all;
      _query = '';
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;
    final placesAsync = ref.watch(placesProvider(circle.id));
    final subscriptionsAsync = ref.watch(mySubscriptionsProvider);
    final subs = subscriptionsAsync.valueOrNull ?? const <PlaceSubscription>[];
    final alertsReady = subscriptionsAsync.hasValue;
    final subByPlace = {for (final s in subs) if (s.circleId == circle.id) s.placeId: s};
    final places = placesAsync.valueOrNull ?? const <Place>[];
    final count = places.length;
    final alertsOn = places.where((p) => subByPlace[p.id]?.enabled ?? false).length;
    final alertsOff = count - alertsOn;
    final query = _query.trim().toLowerCase();
    final visiblePlaces = [
      for (final p in places)
        if ((_filter == _PlaceFilter.all ||
                (_filter == _PlaceFilter.alertsOn && (subByPlace[p.id]?.enabled ?? false)) ||
                (_filter == _PlaceFilter.alertsOff && !(subByPlace[p.id]?.enabled ?? false))) &&
            (query.isEmpty || p.name.toLowerCase().contains(query)))
          p,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DropdownButton<String>(
            isExpanded: true,
            value: circle.id,
            underline: const SizedBox.shrink(),
            items: [
              for (final c in widget.circles)
                DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (id) => ref.read(selectedCircleIdProvider.notifier).state = id,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(child: Text('Saved places', style: Theme.of(context).textTheme.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (placesAsync.valueOrNull == null ? '—' : count.toString()) + ' / ' + kMaxPlacesPerCircle.toString(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
            ],
          ),
        ),
        if (placesAsync.valueOrNull != null && places.isNotEmpty && !alertsReady)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(subscriptionsAsync.hasError ? Icons.warning_amber_rounded : Icons.sync),
                title: Text(subscriptionsAsync.hasError ? 'Alert settings unavailable' : 'Loading alert settings'),
                subtitle: Text(subscriptionsAsync.hasError
                    ? 'Your existing preferences are protected. Retry to load them before changing alerts.'
                    : 'Saved preferences are being loaded before quick controls are enabled.'),
                trailing: subscriptionsAsync.hasError
                    ? IconButton(
                        tooltip: 'Retry loading alert settings',
                        onPressed: () => ref.invalidate(mySubscriptionsProvider),
                        icon: const Icon(Icons.refresh),
                      )
                    : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ),
        if (placesAsync.valueOrNull != null && places.isNotEmpty && alertsReady) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    PremiumIconChip(
                      icon: Icons.notifications_active_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your place alerts', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 3),
                          Text(
                            alertsOn.toString() + ' of ' + count.toString() + ' places have alerts enabled',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      alertsOn.toString() + '/' + count.toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('All ' + count.toString()),
                    selected: _filter == _PlaceFilter.all,
                    onSelected: (_) => setState(() => _filter = _PlaceFilter.all),
                  ),
                  ChoiceChip(
                    label: Text('Alerts on ' + alertsOn.toString()),
                    selected: _filter == _PlaceFilter.alertsOn,
                    onSelected: (_) => setState(() => _filter = _PlaceFilter.alertsOn),
                  ),
                  ChoiceChip(
                    label: Text('Alerts off ' + alertsOff.toString()),
                    selected: _filter == _PlaceFilter.alertsOff,
                    onSelected: (_) => setState(() => _filter = _PlaceFilter.alertsOff),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tap the bell to quickly pause or resume both alert types.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (placesAsync.valueOrNull != null && places.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search saved places',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                isDense: true,
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              placesAsync.when(
                loading: () => const LoadingView(),
                error: (_, __) => MessageView(
                  icon: Icons.lock_outline,
                  title: 'Could not load places',
                  actions: [
                    FilledButton(
                      onPressed: () => ref.invalidate(placesProvider(circle.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                data: (loadedPlaces) {
                  if (loadedPlaces.isEmpty) {
                    return MessageView(
                      icon: Icons.add_location_alt_outlined,
                      title: 'No saved places yet',
                      message: 'Save places like home, school or work to get arrival and departure alerts for this circle.',
                      actions: [
                        FilledButton(onPressed: () => _add(context, count), child: const Text('Add a place')),
                      ],
                    );
                  }
                  if (visiblePlaces.isEmpty) {
                    final showingOn = _filter == _PlaceFilter.alertsOn;
                    final searching = query.isNotEmpty;
                    return MessageView(
                      icon: searching
                          ? Icons.search_off_rounded
                          : showingOn
                              ? Icons.notifications_off_outlined
                              : Icons.filter_alt_off_outlined,
                      title: searching
                          ? 'No matching places'
                          : showingOn
                              ? 'No alerts enabled'
                              : 'All places have alerts on',
                      message: searching
                          ? 'Try another place name, or clear search and filters to see every saved place.'
                          : showingOn
                              ? 'Turn alerts on for a place, or switch back to see every saved place.'
                              : 'Every saved place currently has alerts enabled.',
                      actions: [
                        OutlinedButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _filter = _PlaceFilter.all;
                            });
                          },
                          child: Text(searching ? 'Clear search and filters' : 'Show all places'),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: visiblePlaces.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final place = visiblePlaces[i];
                      return _PlaceListTile(
                        place: place,
                        circleId: circle.id,
                        subscription: subByPlace[place.id],
                        alertsReady: alertsReady,
                        alertsUnavailable: subscriptionsAsync.hasError,
                        colorIndex: i,
                        onOpen: () => context.push('/places/' + circle.id + '/' + place.id),
                      );
                    },
                  );
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: placesAsync.valueOrNull == null ? null : () => _add(context, count),
                  tooltip: placesAsync.valueOrNull == null ? 'Wait for saved places to load' : 'Add a place',
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add place'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _add(BuildContext context, int count) {
    if (count >= kMaxPlacesPerCircle) {
      showSnack(context, 'A circle can have up to $kMaxPlacesPerCircle places. Delete one to add another.');
      return;
    }
    context.push('/places/new?circle=' + widget.circle.id);
  }
}

class _PlaceListTile extends ConsumerStatefulWidget {
  const _PlaceListTile({
    required this.place,
    required this.circleId,
    required this.subscription,
    required this.alertsReady,
    required this.alertsUnavailable,
    required this.colorIndex,
    required this.onOpen,
  });

  final Place place;
  final String circleId;
  final PlaceSubscription? subscription;
  final bool alertsReady;
  final bool alertsUnavailable;
  final int colorIndex;
  final VoidCallback onOpen;

  @override
  ConsumerState<_PlaceListTile> createState() => _PlaceListTileState();
}

class _PlaceListTileState extends ConsumerState<_PlaceListTile> {
  bool _saving = false;

  Future<void> _toggleAlerts() async {
    if (_saving || !widget.alertsReady) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      showSnack(context, 'Sign in to update your place alerts.');
      return;
    }

    final current = widget.subscription;
    final hasAlertTypes = current != null && (current.arrive || current.leave);
    // The bell pauses an active subscription or resumes a paused one, retaining its exact
    // arrival/departure choices and member filter. If no alert types were selected, turn both on.
    final next = PlaceSubscription(
      circleId: widget.circleId,
      placeId: widget.place.id,
      arrive: hasAlertTypes ? current.arrive : true,
      leave: hasAlertTypes ? current.leave : true,
      paused: current?.enabled ?? false,
      allMembers: current?.allMembers ?? true,
      memberUids: current?.memberUids ?? const <String>[],
    );

    setState(() => _saving = true);
    try {
      await ref.read(placesRepositoryProvider).saveSubscription(
            circleId: widget.circleId,
            uid: uid,
            placeId: widget.place.id,
            subscription: next,
          );
    } catch (_) {
      if (mounted) showSnack(context, 'Could not update alerts. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = widget.subscription;
    final alertsOn = subscription?.enabled ?? false;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: PremiumIconChip(
          icon: Icons.location_on_rounded,
          color: CircloPalette.accent(widget.colorIndex),
          size: 48,
        ),
        title: Text(widget.place.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(widget.place.radiusM.round().toString() + ' m radius · ' +
              _alertSummary(subscription, loading: !widget.alertsReady, unavailable: widget.alertsUnavailable)),
        ),
        trailing: IconButton.filledTonal(
          tooltip: _saving
              ? 'Saving alert settings'
              : !widget.alertsReady
                  ? 'Alert settings not ready'
                  : subscription?.paused == true
                      ? 'Resume alerts'
                      : alertsOn
                          ? 'Pause alerts'
                          : 'Turn arrival and departure alerts on',
          onPressed: (_saving || !widget.alertsReady) ? null : _toggleAlerts,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  subscription?.paused == true
                      ? Icons.notifications_paused_outlined
                      : alertsOn
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                ),
        ),
        onTap: widget.onOpen,
      ),
    );
  }
}

/// Create (placeId == null) or edit a place and the signed-in user's own alert preferences.
class PlaceFormScreen extends ConsumerStatefulWidget {
  const PlaceFormScreen({super.key, required this.circleId, this.placeId});
  final String circleId;
  final String? placeId;

  @override
  ConsumerState<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends ConsumerState<PlaceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _search = TextEditingController();
  final MapController _map = MapController();

  bool _mapReady = false;
  LatLng? _pendingMove;
  LatLng? _pin;
  double _radius = kDefaultRadiusM.toDouble();
  bool _arrive = true;
  bool _leave = true;
  bool _paused = false;
  bool _allMembers = true;
  final Set<String> _selected = {};

  bool _loadedExisting = false;
  bool _searching = false;
  bool _saving = false;
  String? _searchError;
  String? _pinError;
  List<GeocodeResult> _results = const [];

  bool get _isEdit => widget.placeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadSubscription();
    } else {
      _locateOnce();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      final sub = await ref.read(placesRepositoryProvider).getSubscription(widget.circleId, uid, widget.placeId!);
      if (!mounted || sub == null) return;
      setState(() {
        _arrive = sub.arrive;
        _leave = sub.leave;
        _paused = sub.paused;
        _allMembers = sub.allMembers;
        _selected
          ..clear()
          ..addAll(sub.memberUids);
      });
    } catch (_) {
      // keep defaults; saving will create the preference document
    }
  }

  Future<void> _locateOnce() async {
    try {
      if (await currentLocationAccess() != LocationAccess.granted) return;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));
      _moveTo(LatLng(p.latitude, p.longitude), 15);
    } catch (_) {
      // map stays at the default view; user can search or tap
    }
  }

  void _moveTo(LatLng point, double zoom) {
    if (_mapReady) {
      _map.move(point, zoom);
    } else {
      _pendingMove = point;
    }
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.length < 3) {
      setState(() => _searchError = 'Type at least 3 characters.');
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await ref.read(placeSearchServiceProvider).search(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        if (r.isEmpty) _searchError = 'No results. Try another search, or tap the map to drop a pin.';
      });
    } on GeocodeException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(GeocodeResult r) {
    final point = LatLng(r.lat, r.lng);
    setState(() {
      _pin = point;
      _pinError = null;
      _results = const [];
      if (_name.text.trim().isEmpty) {
        final first = r.label.split(',').first.trim();
        _name.text = first.length > 50 ? first.substring(0, 50) : first;
      }
    });
    _moveTo(point, 16);
  }

  Future<void> _save({required bool canEdit}) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (canEdit && !_form.currentState!.validate()) return;
    if (canEdit && _pin == null) {
      setState(() => _pinError = 'Tap the map or search to choose the place location.');
      return;
    }
    final repo = ref.read(placesRepositoryProvider);
    final sub = PlaceSubscription(
      circleId: widget.circleId,
      placeId: widget.placeId ?? '',
      arrive: _arrive,
      leave: _leave,
      paused: _paused,
      allMembers: _allMembers,
      memberUids: _allMembers ? const [] : _selected.toList(),
    );
    setState(() => _saving = true);
    try {
      if (!_isEdit) {
        final count = ref.read(placesProvider(widget.circleId)).valueOrNull?.length ?? 0;
        if (count >= kMaxPlacesPerCircle) {
          if (mounted) showSnack(context, 'A circle can have up to $kMaxPlacesPerCircle places.');
          return;
        }
        await repo.createPlace(
          circleId: widget.circleId,
          uid: uid,
          name: _name.text,
          lat: _pin!.latitude,
          lng: _pin!.longitude,
          radiusM: _radius.roundToDouble(),
          subscription: sub,
        );
      } else {
        if (canEdit) {
          await repo.updatePlace(
            circleId: widget.circleId,
            placeId: widget.placeId!,
            name: _name.text,
            lat: _pin!.latitude,
            lng: _pin!.longitude,
            radiusM: _radius.roundToDouble(),
          );
        }
        await repo.saveSubscription(circleId: widget.circleId, uid: uid, placeId: widget.placeId!, subscription: sub);
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete this place?',
      message: 'Alerts for it stop for everyone in the circle.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(placesRepositoryProvider).deletePlace(circleId: widget.circleId, placeId: widget.placeId!, uid: uid);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final circle = ref.watch(circleProvider(widget.circleId)).valueOrNull;
    final membersAsync = ref.watch(membersProvider(widget.circleId));
    final placesAsync = ref.watch(placesProvider(widget.circleId));

    Place? existing;
    if (_isEdit) {
      final list = placesAsync.valueOrNull;
      if (list != null) {
        for (final p in list) {
          if (p.id == widget.placeId) existing = p;
        }
      }
      if (existing != null && !_loadedExisting) {
        _loadedExisting = true;
        _name.text = existing.name;
        _radius = existing.radiusM.clamp(kMinRadiusM.toDouble(), kMaxRadiusM.toDouble()).toDouble();
        _pin = LatLng(existing.lat, existing.lng);
        _pendingMove = _pin;
      }
      if (placesAsync.isLoading && existing == null) {
        return Scaffold(appBar: AppBar(title: const Text('Place')), body: const LoadingView());
      }
      if (existing == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Place')),
          body: MessageView(icon: Icons.search_off, title: 'This place no longer exists', actions: [
            FilledButton(onPressed: () => context.pop(), child: const Text('Back')),
          ]),
        );
      }
    }
    final canEdit = !_isEdit || (existing != null && (existing.createdBy == uid || circle?.ownerUid == uid));
    final others = [for (final m in membersAsync.valueOrNull ?? const <Member>[]) if (m.uid != uid) m];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? (canEdit ? 'Edit place' : 'Place') : 'Add a place')),
      body: SafeArea(
        child: FormPage(children: [
          if (canEdit) ...[
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(labelText: 'Search an address or place', border: OutlineInputBorder()),
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Search',
                onPressed: _searching ? null : _runSearch,
                icon: _searching
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
              ),
            ]),
            if (_searchError != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_searchError!)),
            for (final r in _results)
              ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined),
                title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _pick(r),
              ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _pin ?? const LatLng(20, 0),
                  initialZoom: _pin == null ? 2 : 15,
                  onMapReady: () {
                    _mapReady = true;
                    final m = _pendingMove;
                    if (m != null) {
                      _pendingMove = null;
                      _map.move(m, 15);
                    }
                  },
                  onTap: canEdit
                      ? (_, point) => setState(() {
                            _pin = point;
                            _pinError = null;
                          })
                      : null,
                ),
                children: [
                  TileLayer(urlTemplate: kMapTileUrl, userAgentPackageName: 'com.circlo.circlo'),
                  if (_pin != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _pin!,
                        radius: _radius,
                        useRadiusInMeter: true,
                        color: const Color(0x260D9488),
                        borderColor: const Color(0xFF0D9488),
                        borderStrokeWidth: 2,
                      ),
                    ]),
                  if (_pin != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _pin!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.place, size: 40, color: Color(0xFFDC2626)),
                      ),
                    ]),
                  const RichAttributionWidget(attributions: [TextSourceAttribution(kMapAttribution)]),
                ],
              ),
            ),
          ),
          if (_pinError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_pinError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (canEdit)
            const Padding(padding: EdgeInsets.only(top: 4), child: Text('Tap the map to place the pin.', style: TextStyle(fontSize: 12))),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: TextFormField(
              controller: _name,
              enabled: canEdit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Place name (e.g. School)', border: OutlineInputBorder()),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Enter a name';
                if (t.length > 50) return 'Use 50 characters or fewer';
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Radius: ${_radius.round()} m'),
          Slider(
            value: _radius,
            min: kMinRadiusM.toDouble(),
            max: kMaxRadiusM.toDouble(),
            divisions: (kMaxRadiusM - kMinRadiusM) ~/ 50,
            label: '${_radius.round()} m',
            onChanged: canEdit ? (v) => setState(() => _radius = v) : null,
          ),
          const Divider(),
          Text('My alerts for this place', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: const Text('Pause all alerts'),
            subtitle: const Text('Keep your arrival/departure choices, but temporarily stop these alerts.'),
            value: _paused,
            onChanged: (v) => setState(() => _paused = v),
          ),
          SwitchListTile(
            title: const Text('Notify me when someone arrives'),
            value: _arrive,
            onChanged: (v) => setState(() => _arrive = v),
          ),
          SwitchListTile(
            title: const Text('Notify me when someone leaves'),
            value: _leave,
            onChanged: (v) => setState(() => _leave = v),
          ),
          SwitchListTile(
            title: const Text('Everyone in the circle'),
            subtitle: const Text('Turn off to choose specific members'),
            value: _allMembers,
            onChanged: (_arrive || _leave) ? (v) => setState(() => _allMembers = v) : null,
          ),
          if (!_allMembers && (_arrive || _leave))
            for (final m in others)
              CheckboxListTile(
                title: Text(m.displayName),
                value: _selected.contains(m.uid),
                onChanged: (v) => setState(() => v == true ? _selected.add(m.uid) : _selected.remove(m.uid)),
              ),
          const SizedBox(height: 8),
          const Text(
            'Alerts show up in the Notifications list while Circlo is open. Phone push notifications '
            'about other people\'s movements are not available yet. Only members who are currently '
            'sharing their location with this circle can trigger alerts, and they can pause at any time.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : () => _save(canEdit: canEdit),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEdit ? 'Save changes' : 'Save place'),
          ),
          if (_isEdit && canEdit) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete place'),
            ),
          ],
        ]),
      ),
    );
  }
}
