import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../../core/map_config.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import 'history_models.dart';

String _dateLabel(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final today = DateTime.now();
  final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
  return isToday ? 'Today' : '${d.day} ${months[d.month - 1]} ${d.year}';
}

bool _sameCalendarDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _calendarDateOffset(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _date = DateTime.now();
  String? _memberUid; // null = me
  bool _cleaned = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final circlesAsync = ref.watch(myCirclesProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    if (!_cleaned && profile != null) {
      _cleaned = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => runRetentionCleanup(ref));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel history'),
        actions: [
          IconButton(
            tooltip: 'History settings',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/history/settings'),
          ),
        ],
      ),
      body: circlesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const MessageView(icon: Icons.cloud_off, title: 'Could not load your circles'),
        data: (circles) {
          if (circles.isEmpty || uid == null) {
            return MessageView(
              icon: Icons.history,
              title: 'No circles yet',
              message: 'Join or create a circle to see travel history.',
              actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Go to circles'))],
            );
          }
          final selectedId = ref.watch(selectedCircleIdProvider);
          final circle = circles.firstWhere((c) => c.id == selectedId, orElse: () => circles.first);
          return _Body(
            circles: circles,
            circle: circle,
            uid: uid,
            keepHistory: profile?.keepHistory ?? false,
            date: _date,
            memberUid: _memberUid ?? uid,
            onDate: (d) => setState(() => _date = d),
            onMember: (m) => setState(() => _memberUid = m),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.circles,
    required this.circle,
    required this.uid,
    required this.keepHistory,
    required this.date,
    required this.memberUid,
    required this.onDate,
    required this.onMember,
  });

  final List<Circle> circles;
  final Circle circle;
  final String uid;
  final bool keepHistory;
  final DateTime date;
  final String memberUid;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<String> onMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(circle.id)).valueOrNull ?? const <Member>[];
    final inCircle = members.any((m) => m.uid == memberUid);
    final effectiveMember = inCircle ? memberUid : uid;
    final member = members.where((m) => m.uid == effectiveMember).cast<Member?>().firstWhere((_) => true, orElse: () => null);
    final isMe = effectiveMember == uid;
    final shared = isMe || (member != null && member.historyShared && member.sharesLocation);

    final key = (circle.id, effectiveMember, dayKey(date));
    final trackAsync = (isMe && !keepHistory) || !shared ? null : ref.watch(dayTrackProvider(key));
    final today = DateTime.now();
    final isToday = _sameCalendarDate(date, today);
    final isYesterday = _sameCalendarDate(date, _calendarDateOffset(1));
    final isWeekAgo = _sameCalendarDate(date, _calendarDateOffset(7));
    final dayTrack = trackAsync?.valueOrNull;

    Widget content;
    if (isMe && !keepHistory) {
      content = MessageView(
        icon: Icons.history_toggle_off,
        title: 'Your travel history is off',
        message: 'Turn on "Keep my travel history" to record places you stay at and a simplified route while location sharing is on. It stays private until you share it with a circle.',
        actions: [FilledButton(onPressed: () => context.push('/history/settings'), child: const Text('History settings'))],
      );
    } else if (!shared) {
      content = MessageView(
        icon: Icons.lock_outline,
        title: 'History not shared',
        message: '${member?.displayName ?? 'This member'} has not shared their travel history with this circle.',
      );
    } else {
      content = trackAsync!.when(
        loading: () => const LoadingView(),
        error: (_, __) => MessageView(
          icon: Icons.cloud_off,
          title: 'Could not load history',
          actions: [FilledButton(onPressed: () => ref.invalidate(dayTrackProvider(key)), child: const Text('Retry'))],
        ),
        data: (track) => track == null || (track.visits.isEmpty && track.route.isEmpty)
            ? const MessageView(icon: Icons.event_busy, title: 'No history for this day')
            : _DayView(track: track, isToday: isToday),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: circle.id,
                underline: const SizedBox.shrink(),
                items: [for (final c in circles) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
                onChanged: (id) => ref.read(selectedCircleIdProvider.notifier).state = id,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: effectiveMember,
                underline: const SizedBox.shrink(),
                items: [
                  for (final m in members)
                    DropdownMenuItem(value: m.uid, child: Text(m.uid == uid ? 'Me' : m.displayName, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (m) {
                  if (m != null) onMember(m);
                },
              ),
            ),
          ]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous day',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onDate(date.subtract(const Duration(days: 1))),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_dateLabel(date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 120)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) onDate(picked);
              },
            ),
            IconButton(
              tooltip: 'Next day',
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday ? null : () => onDate(date.add(const Duration(days: 1))),
            ),
            if (shared && !(isMe && !keepHistory))
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(dayTrackProvider(key)),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: isToday,
                  onSelected: (_) => onDate(_calendarDateOffset(0)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Yesterday'),
                  selected: isYesterday,
                  onSelected: (_) => onDate(_calendarDateOffset(1)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('7 days ago'),
                  selected: isWeekAgo,
                  onSelected: (_) => onDate(_calendarDateOffset(7)),
                ),
              ],
            ),
          ),
        ),
        if (dayTrack != null && (dayTrack.visits.isNotEmpty || dayTrack.route.isNotEmpty))
          _HistoryDaySummary(track: dayTrack),
        Expanded(child: content),
      ],
    );
  }
}

class _HistoryDaySummary extends StatelessWidget {
  const _HistoryDaySummary({required this.track});

  final DayTrack track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastFix = track.lastSeen > 0 ? formatClock(track.lastSeen, track.tzOffsetMin) : '—';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Day at a glance', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Text(
                  'SIMPLIFIED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _HistoryMetric(label: 'Stops', value: track.visits.length.toString())),
                Expanded(child: _HistoryMetric(label: 'Route points', value: track.route.length.toString())),
                Expanded(child: _HistoryMetric(label: 'Last recorded', value: lastFix)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Stops shorter than 10 minutes are not included. The route is simplified to limit stored detail.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _DayView extends StatefulWidget {
  const _DayView({required this.track, required this.isToday});
  final DayTrack track;
  final bool isToday;

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  final MapController _controller = MapController();
  bool _ready = false;

  List<LatLng> get _points => [
        for (final p in widget.track.route) LatLng(p.lat, p.lng),
        for (final v in widget.track.visits) LatLng(v.lat, v.lng),
      ];

  void _fit() {
    final pts = _points;
    if (!_ready || pts.isEmpty) return;
    if (pts.length == 1) {
      _controller.move(pts.first, 15);
    } else {
      _controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(40),
        maxZoom: 16,
      ));
    }
  }

  @override
  void didUpdateWidget(covariant _DayView old) {
    super.didUpdateWidget(old);
    if (old.track.day != widget.track.day || old.track.lastSeen != widget.track.lastSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final route = [for (final p in t.route) LatLng(p.lat, p.lng)];
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return LayoutBuilder(builder: (context, c) {
      final map = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _points.isEmpty ? const LatLng(20, 0) : _points.first,
                  initialZoom: 14,
                  onMapReady: () {
                    _ready = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
                  },
                ),
                children: [
                  TileLayer(urlTemplate: kMapTileUrl, userAgentPackageName: 'com.circlo.circlo'),
                  if (route.length >= 2)
                    PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 4, color: const Color(0xFF2563EB))]),
                  MarkerLayer(markers: [
                    for (var i = 0; i < t.visits.length; i++)
                      Marker(
                        point: LatLng(t.visits[i].lat, t.visits[i].lng),
                        width: 120,
                        height: 52,
                        child: Semantics(
                          label: 'Visit ${i + 1}: ${t.visits[i].name}',
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                            Text(t.visits[i].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ]),
                  const RichAttributionWidget(attributions: [TextSourceAttribution(kMapAttribution)]),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton.filledTonal(
              tooltip: 'Fit route and stops',
              onPressed: _points.isEmpty ? null : _fit,
              icon: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),
        ],
      );

      final timeline = ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Stops & timeline', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${t.visits.length} ${t.visits.length == 1 ? 'stop' : 'stops'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (route.length < 2)
            const _HistoryNotice(
              icon: Icons.route_rounded,
              title: 'Route is incomplete',
              message: 'There are not enough location points to draw a route for this day.',
            ),
          if (t.visits.isEmpty)
            const _HistoryNotice(
              icon: Icons.hourglass_empty_rounded,
              title: 'No recorded stops',
              message: 'Stops shorter than 10 minutes are not included in travel history.',
            ),
          for (var i = 0; i < t.visits.length; i++) _VisitTile(index: i + 1, visit: t.visits[i], track: t, nowMs: nowMs),
        ],
      );

      if (c.maxWidth >= 900) {
        return Row(children: [Expanded(flex: 3, child: map), SizedBox(width: 380, child: timeline)]);
      }
      return Column(children: [Expanded(flex: 3, child: map), Expanded(flex: 2, child: timeline)]);
    });
  }
}

class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: scheme.onSurfaceVariant),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(message),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.index, required this.visit, required this.track, required this.nowMs});
  final int index;
  final Visit visit;
  final DayTrack track;
  final int nowMs;

  Widget _timePill(BuildContext context, IconData icon, String label, {bool emphasized = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tz = track.tzOffsetMin;
    final arrived = formatClock(visit.arrivedAt, tz);
    final left = visit.leftAt;
    final end = left ?? (track.lastSeen > visit.arrivedAt ? track.lastSeen : visit.arrivedAt);
    final duration = formatDuration(Duration(milliseconds: end - visit.arrivedAt));
    final accent = CircloPalette.accent(index - 1);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: accent.withValues(alpha: .2)),
              ),
              child: Text('$index', style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          visit.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (left == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text('HERE', style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    visit.placeId != null ? 'Saved place' : 'Unlabelled stop',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _timePill(context, Icons.login_rounded, 'Arrived $arrived', emphasized: true),
                      if (left != null)
                        _timePill(context, Icons.logout_rounded, 'Left ${formatClock(left, tz)}')
                      else
                        _timePill(context, Icons.location_on_rounded, 'Still here'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          left != null ? 'Stay duration: $duration' : '$duration so far',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keep / retention / per-circle sharing / deletion controls (FR-065, FR-066, FR-067).
class HistorySettingsScreen extends ConsumerWidget {
  const HistorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final circles = ref.watch(myCirclesProvider).valueOrNull ?? const <Circle>[];
    final memberships = ref.watch(myMembershipsProvider).valueOrNull ?? const [];
    final byCircle = {for (final m in memberships) m.circleId: m};

    if (uid == null || profile == null) {
      return Scaffold(appBar: AppBar(title: const Text('History settings')), body: const LoadingView());
    }
    final repo = ref.read(profileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Keep my travel history'),
            subtitle: const Text('Records places you stay at and a simplified route, only while location sharing is on. Private to you until you share it with a circle.'),
            value: profile.keepHistory,
            onChanged: (v) async {
              if (v) {
                final ok = await confirmAction(
                  context,
                  title: 'Keep a travel history?',
                  message: 'Circlo will save places where you stay 10+ minutes and a simplified route for each day, in your account, while location sharing is on. '
                      'Nobody else sees it unless you share it with a circle below. You can delete it any time.',
                  confirmLabel: 'Keep history',
                );
                if (!ok) return;
              }
              try {
                await repo.setHistoryPrefs(uid: uid, keepHistory: v, retentionDays: profile.retentionDays);
              } catch (_) {
                if (context.mounted) showSnack(context, 'Could not save. Check your connection and try again.');
              }
            },
          ),
          ListTile(
            title: const Text('Keep history for'),
            trailing: DropdownButton<int>(
              value: const [7, 30, 90].contains(profile.retentionDays) ? profile.retentionDays : 30,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
                DropdownMenuItem(value: 90, child: Text('90 days')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                try {
                  await repo.setHistoryPrefs(uid: uid, keepHistory: profile.keepHistory, retentionDays: v);
                  await runRetentionCleanup(ref);
                } catch (_) {
                  if (context.mounted) showSnack(context, 'Could not save. Try again.');
                }
              },
            ),
            subtitle: const Text('Older days are removed automatically when you open the app (no server involved).'),
          ),
          const Divider(),
          Text('Share my history with', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Only circles where location sharing is on can be chosen. Turning sharing off for a circle also stops sharing history with it.'),
          for (final c in circles)
            Builder(builder: (context) {
              final m = byCircle[c.id];
              final canShare = profile.keepHistory && (m?.sharesLocation ?? false);
              return SwitchListTile(
                title: Text(c.name),
                subtitle: Text(!profile.keepHistory
                    ? 'Turn on "Keep my travel history" first'
                    : (m?.sharesLocation ?? false)
                        ? ((m?.historyShared ?? false) ? 'History shared' : 'Not shared')
                        : 'Location sharing is off for this circle'),
                value: m?.historyShared ?? false,
                onChanged: (canShare || (m?.historyShared ?? false))
                    ? (v) => _toggleCircle(context, ref, uid, c, v)
                    : null,
              );
            }),
          const Divider(),
          Text('Delete', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: const Text('Delete a date range…'),
            onPressed: () => _deleteRange(context, ref, uid),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete all my history'),
            onPressed: () => _deleteAll(context, ref, uid),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCircle(BuildContext context, WidgetRef ref, String uid, Circle c, bool enable) async {
    final repo = ref.read(historyRepositoryProvider);
    if (enable) {
      final others = (ref.read(membersProvider(c.id)).valueOrNull?.length ?? 1) - 1;
      final ok = await confirmAction(
        context,
        title: 'Share your travel history with ${c.name}?',
        message: '$others other ${others == 1 ? 'member' : 'members'} will be able to see where you stayed and your simplified route for each day within your retention period. '
            'You can switch this off at any time; that removes this circle\'s copy.',
        confirmLabel: 'Share history',
      );
      if (!ok) return;
    }
    try {
      if (enable) {
        await repo.enableSharing(uid: uid, circleId: c.id);
      } else {
        await repo.disableSharing(uid: uid, circleId: c.id);
      }
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not update. Check your connection and try again.');
    }
  }

  Future<void> _deleteRange(BuildContext context, WidgetRef ref, String uid) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 120)),
      lastDate: now,
    );
    if (range == null || !context.mounted) return;
    final from = dayKey(range.start);
    final to = dayKey(range.end);
    final ok = await confirmAction(
      context,
      title: 'Delete history from ${_dateLabel(range.start)} to ${_dateLabel(range.end)}?',
      message: 'This removes those days from your account and from every circle. It cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _delete(context, ref, uid, (days) => [for (final d in days) if (d.compareTo(from) >= 0 && d.compareTo(to) <= 0) d]);
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref, String uid) async {
    final ok = await confirmAction(
      context,
      title: 'Delete all your travel history?',
      message: 'This removes every stored day from your account and from every circle. It cannot be undone.',
      confirmLabel: 'Delete all',
    );
    if (!ok) return;
    await _delete(context, ref, uid, (days) => days);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String uid, List<String> Function(List<String>) pick) async {
    final repo = ref.read(historyRepositoryProvider);
    final memberships = ref.read(myMembershipsProvider).valueOrNull ?? const [];
    try {
      final days = pick(await repo.myDays(uid, limit: 200));
      if (days.isEmpty) {
        if (context.mounted) showSnack(context, 'No history in that range.');
        return;
      }
      await repo.deleteDays(uid: uid, days: days, circleIds: [for (final m in memberships) m.circleId]);
      if (context.mounted) showSnack(context, 'History deleted.');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not delete. Check your connection and try again.');
    }
  }
}
