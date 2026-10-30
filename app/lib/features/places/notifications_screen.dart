import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../location/sharing_status.dart';
import 'activity_time_group.dart';
import 'place_models.dart';

IconData _iconFor(FeedItem i) {
  switch (i.kind) {
    case FeedKind.place:
      return i.isArrival ? Icons.login : Icons.logout;
    case FeedKind.noShow:
      return Icons.alarm_off_rounded;
    case FeedKind.membership:
      return Icons.group;
    case FeedKind.sharing:
      return Icons.share_location;
    case FeedKind.unavailable:
      return Icons.location_off;
    case FeedKind.requests:
      return Icons.person_add;
    case FeedKind.checkIns:
      return Icons.check_circle_outline_rounded;
  }
}

/// Bell icon with an unread badge; opens the notifications list.
class NotificationsBell extends ConsumerWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: unread > 0 ? 'Notifications ($unread new)' : 'Notifications',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () => context.push('/notifications'),
    );
  }
}

enum _ActivityFilter { all, places, people, location, checkIns }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _seenWhenOpened;
  bool _captured = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    // Remember what was already read when the screen opened, then mark everything as read.
    if (!_captured && profile != null) {
      _captured = true;
      _seenWhenOpened = profile.notifSeenAt;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uid = ref.read(currentUidProvider);
        if (uid != null) {
          ref.read(profileRepositoryProvider).markNotificationsSeen(uid).catchError((_) {});
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/notifications/settings'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const LoadingView(),
        error: (_, __) => const MessageView(icon: Icons.cloud_off, title: 'Could not load notifications'),
        data: (items) {
          final query = _query.trim().toLowerCase();
          bool matchesCategory(FeedItem item) {
            switch (_filter) {
              case _ActivityFilter.all:
                return true;
              case _ActivityFilter.places:
                return item.kind == FeedKind.place || item.kind == FeedKind.noShow;
              case _ActivityFilter.people:
                return item.kind == FeedKind.membership || item.kind == FeedKind.requests;
              case _ActivityFilter.location:
                return item.kind == FeedKind.sharing || item.kind == FeedKind.unavailable;
              case _ActivityFilter.checkIns:
                return item.kind == FeedKind.checkIns;
            }
          }

          final placeCount = items.where((i) => i.kind == FeedKind.place || i.kind == FeedKind.noShow).length;
          final peopleCount = items.where((i) => i.kind == FeedKind.membership || i.kind == FeedKind.requests).length;
          final locationCount = items.where((i) => i.kind == FeedKind.sharing || i.kind == FeedKind.unavailable).length;
          final checkInCount = items.where((i) => i.kind == FeedKind.checkIns).length;
          final visibleItems = items.where((item) {
            final matchesSearch = query.isEmpty ||
                item.text.toLowerCase().contains(query) ||
                item.circleName.toLowerCase().contains(query) ||
                feedKindLabel(item.kind).toLowerCase().contains(query);
            return matchesCategory(item) && matchesSearch;
          }).toList();

          final now = DateTime.now();
          final groupedItems = <String, List<FeedItem>>{};
          for (final item in visibleItems) {
            final group = activityTimeGroupLabel(item.at, now: now);
            groupedItems.putIfAbsent(group, () => <FeedItem>[]).add(item);
          }
          const activityGroupOrder = <String>['Upcoming', 'Today', 'Yesterday', 'Last 7 days', 'Earlier'];

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: PremiumPageHeader(
                  eyebrow: 'YOUR CIRCLES',
                  title: 'Latest updates',
                  subtitle: 'The people and places that matter, together.',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: PremiumGlassCard(
                  padding: EdgeInsets.all(14),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Notifications appear here while Circlo is open.'),
                    subtitle: Text('Phone push notifications about other people are not available yet.'),
                  ),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Nothing new yet.\nArrivals, expected-arrival warnings, member check-ins, membership changes and sharing updates will show up here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search activity or circle',
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
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PremiumFilterChip(label: 'All', count: '${items.length}', icon: Icons.grid_view_rounded, selected: _filter == _ActivityFilter.all, onSelected: (_) => setState(() => _filter = _ActivityFilter.all)),
                        const SizedBox(width: 8),
                        PremiumFilterChip(label: 'Places', count: '$placeCount', icon: Icons.place_rounded, selected: _filter == _ActivityFilter.places, onSelected: (_) => setState(() => _filter = _ActivityFilter.places)),
                        const SizedBox(width: 8),
                        PremiumFilterChip(label: 'People', count: '$peopleCount', icon: Icons.groups_rounded, selected: _filter == _ActivityFilter.people, onSelected: (_) => setState(() => _filter = _ActivityFilter.people)),
                        const SizedBox(width: 8),
                        PremiumFilterChip(label: 'Location', count: '$locationCount', icon: Icons.near_me_rounded, selected: _filter == _ActivityFilter.location, onSelected: (_) => setState(() => _filter = _ActivityFilter.location)),
                        const SizedBox(width: 8),
                        PremiumFilterChip(label: 'Check-ins', count: '$checkInCount', icon: Icons.check_circle_outline_rounded, selected: _filter == _ActivityFilter.checkIns, onSelected: (_) => setState(() => _filter = _ActivityFilter.checkIns)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Text(
                        '${visibleItems.length} of ${items.length}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (visibleItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.filter_alt_off_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        Text('No matching activity', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Try another category or search term.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _filter = _ActivityFilter.all;
                            });
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final groupLabel in activityGroupOrder)
                    if (groupedItems.containsKey(groupLabel)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                        child: Row(
                          children: [
                            Text(
                              groupLabel,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${groupedItems[groupLabel]!.length}',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      for (final item in groupedItems[groupLabel]!)
                        _NotificationTile(
                          item: item,
                          isNew: _seenWhenOpened == null || item.at.isAfter(_seenWhenOpened!),
                        ),
                    ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.isNew});

  final FeedItem item;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unavailable = item.kind == FeedKind.unavailable;
    final iconColor = unavailable ? scheme.error : CircloPalette.accent(item.kind.index);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: PremiumGlassCard(
        padding: EdgeInsets.zero,
        radius: 18,
        child: ListTile(
          minVerticalPadding: 12,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: PremiumIconChip(
            icon: _iconFor(item),
            color: iconColor,
            size: 44,
          ),
          title: Text(item.text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Icon(Icons.circle, size: 5, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item.circleName} · ${formatAgo(item.at, DateTime.now())}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          trailing: isNew
              ? const PremiumStatusPill(
                  label: 'New',
                  icon: Icons.fiber_new_rounded,
                  color: CircloPalette.brand,
                  compact: true,
                )
              : null,
        ),
      ),
    );
  }
}

/// Which kinds of notifications to show, and which circles to mute (FR-081).
/// Preference writes are serialized by disabling the controls while a save is in flight.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  Set<String> _off = {};
  Set<String> _muted = {};
  bool _initialized = false;
  bool _saving = false;

  Future<void> _save({
    required String uid,
    required Set<String> nextOff,
    required Set<String> nextMuted,
  }) async {
    if (_saving) return;
    final oldOff = Set<String>.of(_off);
    final oldMuted = Set<String>.of(_muted);
    setState(() {
      _off = Set<String>.of(nextOff);
      _muted = Set<String>.of(nextMuted);
      _saving = true;
    });
    try {
      await ref.read(profileRepositoryProvider).setNotificationPrefs(
            uid: uid,
            off: _off.toList(),
            muted: _muted.toList(),
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _off = oldOff;
          _muted = oldMuted;
        });
        showSnack(context, 'Could not save notification settings. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final circles = ref.watch(myCirclesProvider).valueOrNull ?? const [];

    if (uid == null || profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification settings')),
        body: const LoadingView(),
      );
    }

    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialized) return;
        setState(() {
          _off = profile.notifOff.toSet();
          _muted = profile.notifMuted.toSet();
          _initialized = true;
        });
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Notification settings')),
        body: const LoadingView(),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const PremiumPageHeader(
            eyebrow: 'ACTIVITY PREFERENCES',
            title: 'Your updates',
            subtitle: 'Choose what appears in your activity feed.',
          ),
          const SizedBox(height: 18),
          PremiumSection(
            title: 'Activity types',
            subtitle: 'Choose the updates you want to see.',
            children: [
              for (final kind in FeedKind.values)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: PremiumIconChip(
                    icon: Icons.notifications_active_rounded,
                    color: CircloPalette.accent(kind.index),
                    size: 40,
                  ),
                  title: Text(feedKindLabel(kind)),
                  value: !_off.contains(feedKindName(kind)),
                  onChanged: _saving
                      ? null
                      : (enabled) {
                          final nextOff = Set<String>.of(_off);
                          enabled
                              ? nextOff.remove(feedKindName(kind))
                              : nextOff.add(feedKindName(kind));
                          _save(uid: uid, nextOff: nextOff, nextMuted: _muted);
                        },
                ),
            ],
          ),
          const SizedBox(height: 18),
          PremiumSection(
            title: 'Your circles',
            subtitle: 'Muted circles do not appear in your activity feed.',
            children: [
              for (final circle in circles)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: const PremiumIconChip(
                    icon: Icons.groups_rounded,
                    color: CircloPalette.mint,
                    size: 40,
                  ),
                  title: Text(circle.name),
                  subtitle: Text(_muted.contains(circle.id) ? 'Muted' : 'Updates on'),
                  value: !_muted.contains(circle.id),
                  onChanged: _saving
                      ? null
                      : (enabled) {
                          final nextMuted = Set<String>.of(_muted);
                          enabled ? nextMuted.remove(circle.id) : nextMuted.add(circle.id);
                          _save(uid: uid, nextOff: _off, nextMuted: nextMuted);
                        },
                ),
            ],
          ),
          const SizedBox(height: 18),
          PremiumGlassCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const PremiumIconChip(
                icon: Icons.info_outline_rounded,
                color: CircloPalette.brand,
                size: 40,
              ),
              title: const Text('In-app updates only'),
              subtitle: Text(
                'Arrival/departure alerts are also configured per place. Phone push notifications are not available yet, so this feed updates while Circlo is open and syncing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
