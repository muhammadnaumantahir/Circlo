import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../location/sharing_status.dart';
import 'place_models.dart';

IconData _iconFor(FeedItem i) {
  switch (i.kind) {
    case FeedKind.place:
      return i.isArrival ? Icons.login : Icons.logout;
    case FeedKind.membership:
      return Icons.group;
    case FeedKind.sharing:
      return Icons.share_location;
    case FeedKind.unavailable:
      return Icons.location_off;
    case FeedKind.requests:
      return Icons.person_add;
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

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _seenWhenOpened;
  bool _captured = false;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(notificationFeedProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final now = DateTime.now();

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
        title: const Text('Notifications'),
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
        data: (items) => ListView(
          children: [
            const Card(
              margin: EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Notifications appear here while Circlo is open.'),
                subtitle: Text('Phone push notifications about other people are not available yet.'),
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Nothing new.\nArrivals, membership changes and sharing updates will show up here.', textAlign: TextAlign.center),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text(
                      '${items.length} items',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              for (final i in items)
                _NotificationTile(
                  item: i,
                  isNew: _seenWhenOpened == null || i.at.isAfter(_seenWhenOpened!),
                ),
            ],
          ],
        ),
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
      child: Card(
        margin: EdgeInsets.zero,
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
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.primary.withValues(alpha: .13)),
                  ),
                  child: Text(
                    'New',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
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
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Show me', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final kind in FeedKind.values)
            SwitchListTile(
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
          const Divider(height: 28),
          Text('Circles', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Muted circles do not appear in your notifications.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final circle in circles)
            SwitchListTile(
              title: Text(circle.name),
              subtitle: Text(_muted.contains(circle.id) ? 'Muted' : 'Notifications on'),
              value: !_muted.contains(circle.id),
              onChanged: _saving
                  ? null
                  : (enabled) {
                      final nextMuted = Set<String>.of(_muted);
                      enabled ? nextMuted.remove(circle.id) : nextMuted.add(circle.id);
                      _save(uid: uid, nextOff: _off, nextMuted: nextMuted);
                    },
            ),
          const SizedBox(height: 12),
          const Text(
            'Arrival/departure alerts are also configured per place in the Places tab. '
            'Phone push notifications are not available yet, so this feed updates while Circlo is open and syncing.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
