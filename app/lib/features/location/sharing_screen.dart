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
            _PermissionCard(ref: ref),
            if (sharing.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(sharing.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Pause sharing'),
              subtitle: const Text('Temporarily stops sharing in all circles. Others see "Paused".'),
              value: allPaused,
              onChanged: sharingOn.isEmpty
                  ? null
                  : (v) => _run(context, () => ref.read(locationRepositoryProvider).setPausedForCircles(
                        uid: ref.read(currentUidProvider)!,
                        circleIds: [for (final m in sharingOn) m.circleId],
                        paused: v,
                      )),
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

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(locationAccessProvider);
    return Card(
      child: access.when(
        loading: () => const ListTile(title: Text('Checking location permission…')),
        error: (_, __) => const ListTile(
          leading: Icon(Icons.error_outline),
          title: Text('Could not check location permission'),
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
                  onPressed: () async {
                    await openDeviceLocationSettings();
                    ref.invalidate(locationAccessProvider);
                  },
                  child: const Text('Open settings'),
                ),
              );
            case LocationAccess.deniedForever:
              return ListTile(
                leading: const Icon(Icons.location_disabled),
                title: const Text('Location permission is blocked'),
                subtitle: const Text('Allow it in your device settings to share.'),
                trailing: TextButton(
                  onPressed: () async {
                    await openAppLocationSettings();
                    ref.invalidate(locationAccessProvider);
                  },
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
          '• Your phone shows a notification while sharing runs in the background.\n'
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
