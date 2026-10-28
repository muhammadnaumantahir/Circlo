import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import 'location_access.dart';
import 'location_models.dart';
import 'sharing_controller.dart';

final locationAccessProvider =
    FutureProvider.autoDispose<LocationAccess>((ref) => currentLocationAccess());

class SharingScreen extends ConsumerWidget {
  const SharingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider);
    final memberships = ref.watch(myMembershipsProvider).valueOrNull ?? const <MyMembership>[];
    final sharing = ref.watch(sharingControllerProvider);
    final byCircle = {for (final m in memberships) m.circleId: m};
    final sharingOn = memberships.where((m) => m.sharesLocation).toList();
    final allPaused = sharingOn.isNotEmpty && sharingOn.every((m) => m.paused);

    return Scaffold(
      appBar: AppBar(title: const Text('Location sharing')),
      body: circles.when(
        loading: () => const LoadingView(),
        error: (_, __) => const MessageView(icon: Icons.cloud_off, title: 'Could not load your circles'),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'You decide who sees your location. Sharing is off until you switch it on for a circle, '
              'and only members of that circle can see it.',
            ),
            const SizedBox(height: 16),
            if (kIsWeb)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('On the web, location is shared only while this tab is open.'),
                ),
              ),
            _EngineStatusCard(
              tracking: sharing.tracking,
              error: sharing.error,
              lastPublished: sharing.lastPublished,
              sharingEnabled: sharingOn.isNotEmpty,
              allPaused: allPaused,
              activeCircleCount: sharing.activeCircleIds.length,
              onRetry: () => ref.read(sharingControllerProvider.notifier).retry(),
            ),
            const SizedBox(height: 12),
            _PermissionCard(ref: ref),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Pause sharing'),
              subtitle: Text(allPaused
                  ? (_pausedUntilLabel(sharingOn) ?? 'Paused until you resume')
                  : 'Temporarily stops sharing in all circles. Others see "Paused".'),
              value: allPaused,
              onChanged: sharingOn.isEmpty
                  ? null
                  : (v) async {
                      DateTime? until;
                      if (v) {
                        final choice = await _askPauseDuration(context);
                        if (choice == null) return;
                        until = choice.until();
                      }
                      if (!context.mounted) return;
                      await _run(context, () => ref.read(locationRepositoryProvider).setPausedForCircles(
                            uid: ref.read(currentUidProvider)!,
                            circleIds: [for (final m in sharingOn) m.circleId],
                            paused: v,
                            until: until,
                          ));
                    },
            ),
            const Divider(),
            Text('Circles that can see me', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Text('Join or create a circle first.')
            else
              for (final c in list)
                _CircleSharingTile(circle: c, membership: byCircle[c.id]),
          ],
        ),
      ),
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) showSnack(context, 'Could not update sharing. Check your connection and try again.');
  }
}

class _EngineStatusCard extends StatelessWidget {
  const _EngineStatusCard({
    required this.tracking,
    required this.error,
    required this.lastPublished,
    required this.sharingEnabled,
    required this.allPaused,
    required this.activeCircleCount,
    required this.onRetry,
  });

  final bool tracking;
  final String? error;
  final DateTime? lastPublished;
  final bool sharingEnabled;
  final bool allPaused;
  final int activeCircleCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final DateTime? synced = lastPublished?.toLocal();
    final stale = synced != null &&
        DateTime.now().difference(synced) > const Duration(minutes: 10);
    final String title;
    final String detail;
    final IconData icon;
    final Color tone;

    if (error != null) {
      title = 'Location sync needs attention';
      detail = error!;
      icon = Icons.warning_amber_rounded;
      tone = scheme.error;
    } else if (!sharingEnabled) {
      title = 'Location sharing is off';
      detail = 'Turn it on for a circle below when you are ready.';
      icon = Icons.location_off_outlined;
      tone = scheme.onSurfaceVariant;
    } else if (allPaused) {
      title = 'Sharing is paused';
      detail = 'Your live location is hidden until sharing resumes.';
      icon = Icons.pause_circle_outline_rounded;
      tone = scheme.secondary;
    } else if (stale) {
      title = 'Location sync is delayed';
      detail = 'Last successful sync was over 10 minutes ago. Check your connection and retry.';
      icon = Icons.sync_problem_rounded;
      tone = scheme.error;
    } else if (!tracking || synced == null) {
      title = 'Connecting to your location';
      detail = 'Circlo will show the last successful sync here.';
      icon = Icons.location_searching_rounded;
      tone = scheme.primary;
    } else {
      final hour = synced.hour % 12 == 0 ? 12 : synced.hour % 12;
      final minute = synced.minute.toString().padLeft(2, '0');
      final period = synced.hour >= 12 ? 'PM' : 'AM';
      title = 'Location sharing is active';
      detail = 'Last synced at $hour:$minute $period · $activeCircleCount '
          '${activeCircleCount == 1 ? 'circle' : 'circles'}';
      icon = Icons.check_circle_rounded;
      tone = scheme.primary;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tone.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error != null ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (sharingEnabled && !allPaused && error == null && !stale && (!tracking || synced == null)) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            if (error != null || stale)
              IconButton(
                tooltip: 'Retry location sync',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends ConsumerStatefulWidget {
  const _PermissionCard();

  @override
  ConsumerState<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends ConsumerState<_PermissionCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Device settings are outside the app. Re-check only once Circlo is visible again,
    // otherwise the result may still reflect the permission state from before settings.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(locationAccessProvider);
    }
  }

  Future<void> _openSettings(Future<void> Function() openSettings) async {
    try {
      await openSettings();
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not open settings. Open your device settings to allow location.');
      }
    }
    // Also refresh on return for platforms where opening the settings route completes late.
    if (mounted) ref.invalidate(locationAccessProvider);
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(locationAccessProvider);
    return Card(
      child: access.when(
        loading: () => const ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Checking location permission…'),
        ),
        error: (_, __) => ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Could not check location permission'),
          subtitle: const Text('Check your connection to device location services and retry.'),
          trailing: TextButton(
            onPressed: () => ref.invalidate(locationAccessProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (a) {
          switch (a) {
            case LocationAccess.granted:
              return const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Location permission granted'),
              );
            case LocationAccess.serviceDisabled:
              return ListTile(
                leading: const Icon(Icons.location_off),
                title: const Text('Location services are turned off on this device'),
                trailing: TextButton(
                  onPressed: () => _openSettings(openDeviceLocationSettings),
                  child: const Text('Open settings'),
                ),
              );
            case LocationAccess.deniedForever:
              return ListTile(
                leading: const Icon(Icons.location_disabled),
                title: const Text('Location permission is blocked'),
                subtitle: const Text('Allow it in your device settings to share.'),
                trailing: TextButton(
                  onPressed: () => _openSettings(openAppLocationSettings),
                  child: const Text('Open settings'),
                ),
              );
            case LocationAccess.denied:
              return const ListTile(
                leading: Icon(Icons.location_searching),
                title: Text('Location permission not granted yet'),
                subtitle: Text('You will be asked when you switch sharing on for a circle.'),
              );
          }
        },
      ),
    );
  }
}

class _CircleSharingTile extends ConsumerWidget {
  const _CircleSharingTile({required this.circle, required this.membership});
  final Circle circle;
  final MyMembership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(circle.id)).valueOrNull;
    final others = members == null ? null : members.length - 1;
    final on = membership?.sharesLocation ?? false;
    final paused = membership?.paused ?? false;
    final state = !on ? 'Off' : (paused ? 'Paused' : 'Sharing');
    final visible = others == null ? '' : ' · Visible to $others other ${others == 1 ? 'member' : 'members'}';

    return SwitchListTile(
      title: Text(circle.name),
      subtitle: Text('$state$visible'),
      value: on,
      onChanged: (v) => _toggle(context, ref, v, others ?? 0),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enable, int others) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final repo = ref.read(locationRepositoryProvider);
    if (!enable) {
      await _run(context, () async {
        await ref.read(historyRepositoryProvider).removeCopies(uid: uid, circleId: circle.id);
        await repo.setCircleSharing(uid: uid, circleId: circle.id, enabled: false);
      });
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Share your location with ${circle.name}?',
      message: '• $others other ${others == 1 ? 'member' : 'members'} of this circle will see where you are on a map and when it was last updated.\n'
          '• Nobody outside this circle can see it.\n'
          '${kIsWeb ? '• On the web, sharing stays active only while this tab is open.\n' : '• Your device shows a visible location-sharing indicator while tracking runs.\n'}'
          '• You can pause or stop at any time here, and leaving the circle stops it immediately.',
      confirmLabel: 'Share my location',
    );
    if (!ok) return;
    final access = await requestLocationAccess();
    ref.invalidate(locationAccessProvider);
    if (access != LocationAccess.granted) {
      if (context.mounted) {
        showSnack(context, 'Location permission is needed to share. Check the permission card above.');
      }
      return;
    }
    if (!context.mounted) return;
    await _run(context, () => repo.setCircleSharing(uid: uid, circleId: circle.id, enabled: true));
  }
}

enum _PauseChoice {
  hour('For 1 hour'),
  tomorrow('Until tomorrow morning (6:00)'),
  manual('Until I resume');

  const _PauseChoice(this.label);
  final String label;

  DateTime? until() {
    final now = DateTime.now();
    switch (this) {
      case _PauseChoice.hour:
        return now.add(const Duration(hours: 1));
      case _PauseChoice.tomorrow:
        final t = DateTime(now.year, now.month, now.day, 6);
        return now.isBefore(t) ? t : t.add(const Duration(days: 1));
      case _PauseChoice.manual:
        return null;
    }
  }
}

Future<_PauseChoice?> _askPauseDuration(BuildContext context) => showDialog<_PauseChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pause sharing'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Timed pauses end automatically while Circlo is open; if it is closed, sharing stays paused until you open it.'),
          ),
          for (final c in _PauseChoice.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c.label)),
        ],
      ),
    );

String? _pausedUntilLabel(List<MyMembership> sharingOn) {
  final times = [for (final m in sharingOn) if (m.pausedUntil != null) m.pausedUntil!];
  if (times.isEmpty) return null;
  times.sort();
  final t = times.last.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Paused until ${two(t.hour)}:${two(t.minute)}';
}
