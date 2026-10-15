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
            else
              for (final i in items)
                ListTile(
                  leading: Icon(_iconFor(i)),
                  title: Text(i.text),
                  subtitle: Text('${i.circleName} · ${formatAgo(i.at, now)}'),
                  trailing: (_seenWhenOpened == null || i.at.isAfter(_seenWhenOpened!))
                      ? const Chip(label: Text('New'), visualDensity: VisualDensity.compact)
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

/// Which kinds of notifications to show, and which circles to mute (FR-081).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final circles = ref.watch(myCirclesProvider).valueOrNull ?? const [];
    if (uid == null || profile == null) {
      return Scaffold(appBar: AppBar(title: const Text('Notification settings')), body: const LoadingView());
    }
    final off = profile.notifOff.toSet();
    final muted = profile.notifMuted.toSet();
    final repo = ref.read(profileRepositoryProvider);

    Future<void> save(Set<String> newOff, Set<String> newMuted) async {
      try {
        await repo.setNotificationPrefs(uid: uid, off: newOff.toList(), muted: newMuted.toList());
      } catch (_) {
        if (context.mounted) showSnack(context, 'Could not save. Check your connection and try again.');
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Show me', style: Theme.of(context).textTheme.titleMedium),
          for (final k in FeedKind.values)
            SwitchListTile(
              title: Text(feedKindLabel(k)),
              value: !off.contains(feedKindName(k)),
              onChanged: (v) {
                final next = {...off};
                v ? next.remove(feedKindName(k)) : next.add(feedKindName(k));
                save(next, muted);
              },
            ),
          const Divider(),
          Text('Circles', style: Theme.of(context).textTheme.titleMedium),
          const Text('Muted circles do not appear in your notifications.'),
          for (final c in circles)
            SwitchListTile(
              title: Text(c.name),
              subtitle: Text(muted.contains(c.id) ? 'Muted' : 'Notifications on'),
              value: !muted.contains(c.id),
              onChanged: (v) {
                final next = {...muted};
                v ? next.remove(c.id) : next.add(c.id);
                save(off, next);
              },
            ),
          const SizedBox(height: 8),
          const Text(
            'Place alerts are also chosen per place in the Places tab. Phone push notifications are not available yet.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
