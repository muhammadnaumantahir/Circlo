import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import '../location/location_models.dart';
import 'sos_message.dart';

class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS message'),
      ),
      body: circlesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => MessageView(
          icon: Icons.cloud_off,
          title: 'Could not load your circles',
          message: 'Check your connection and try again.',
          actions: [
            FilledButton(
              onPressed: () => ref.invalidate(myCirclesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (circles) {
          if (circles.isEmpty) {
            return const MessageView(
              icon: Icons.groups_outlined,
              title: 'Join a circle first',
              message: 'SOS messages use the location-sharing settings of a selected circle.',
            );
          }

          final selectedId = ref.watch(selectedCircleIdProvider);
          Circle circle = circles.first;
          for (final candidate in circles) {
            if (candidate.id == selectedId) {
              circle = candidate;
              break;
            }
          }

          final uid = ref.watch(currentUidProvider);
          final profileName = ref.watch(profileProvider).valueOrNull?.displayName ?? '';
          final memberships =
              ref.watch(myMembershipsProvider).valueOrNull ?? const <MyMembership>[];
          MyMembership? membership;
          for (final item in memberships) {
            if (item.circleId == circle.id) {
              membership = item;
              break;
            }
          }

          final locations = ref.watch(locationsProvider(circle.id)).valueOrNull;
          final ownLocation = uid == null ? null : locations?[uid];
          final sharingActive = membership?.isActive == true;
          final now = DateTime.now();
          final message = buildSosMessage(
            displayName: profileName,
            sharingActive: sharingActive,
            location: ownLocation,
            now: now,
          );
          final updatedAt = ownLocation?.updatedAt;
          final hasFreshLocation = sharingActive &&
              ownLocation != null &&
              updatedAt != null &&
              !updatedAt.isAfter(now.add(const Duration(minutes: 2))) &&
              now.difference(updatedAt) <= const Duration(minutes: 10);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.emergency_rounded, color: Theme.of(context).colorScheme.onErrorContainer, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need help?',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Circlo prepares a message for you to share. It does not send it automatically, confirm delivery, or replace local emergency services.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.groups_rounded),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Use shared location from')),
                      const SizedBox(width: 8),
                      Flexible(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: circle.id,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final item in circles)
                              DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.name, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (id) {
                            if (id != null) {
                              ref.read(selectedCircleIdProvider.notifier).state = id;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasFreshLocation
                                  ? (ownLocation!.approximate ? 'Approximate shared pin' : 'Last shared location available')
                                  : 'No fresh shared location',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasFreshLocation
                            ? (ownLocation!.approximate
                                ? 'The message will clearly label this as an approximate map pin, not your exact GPS position.'
                                : 'The message will include the last shared fix and its age. It may not be your exact current position.')
                            : 'The message will not include old or unavailable coordinates. Turn on location sharing and wait for a fresh fix if you need to share a location.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Message preview', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: SelectableText(message),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _shareMessage(context, profileName, message),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Choose who to share with'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (context.mounted) showSnack(context, 'SOS message copied.');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy message'),
              ),
              const SizedBox(height: 14),
              Text(
                'Nothing is sent until you choose a recipient and confirm the action in the app you select. Circlo cannot verify whether the message was delivered or read.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareMessage(BuildContext context, String name, String message) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: name.trim().isEmpty ? 'SOS message' : 'SOS message from ' + name.trim(),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Could not open the share sheet. Use Copy message instead.');
      }
    }
  }
}
