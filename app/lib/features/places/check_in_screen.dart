import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import 'place_models.dart';

/// A one-time, manual check-in at a saved place. It does not read or store GPS coordinates.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  String? _busyPlaceKey;

  Future<void> _checkIn(Circle circle, Place place) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _busyPlaceKey != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Check in at ${place.name}?'),
        content: Text(
          'This will post a manual check-in to ${circle.name}. '
          'It is not verified by GPS and will not share your coordinates or enable live location sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Share check-in'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final key = '${circle.id}/${place.id}';
    setState(() => _busyPlaceKey = key);
    try {
      final repository = ref.read(placesRepositoryProvider);
      final memberName = await repository.myMemberName(circle.id, uid);
      if (memberName == null || memberName.trim().isEmpty) {
        throw StateError('Circle member name is unavailable.');
      }
      await repository.publishCheckIn(
        circleId: circle.id,
        uid: uid,
        memberName: memberName,
        place: place,
        checkInId: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      );
      if (mounted) {
        showSnack(context, 'Check-in shared with ${circle.name}.');
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not share your check-in. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busyPlaceKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final circlesAsync = ref.watch(myCirclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
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
            return MessageView(
              icon: Icons.groups_outlined,
              title: 'No circles yet',
              message: 'Create or join a circle before sharing a check-in.',
              actions: [
                FilledButton(
                  onPressed: () => context.go('/circles'),
                  child: const Text('Go to circles'),
                ),
              ],
            );
          }

          final selectedId = ref.watch(selectedCircleIdProvider);
          final circle = circles.firstWhere((c) => c.id == selectedId, orElse: () => circles.first);
          final placesAsync = ref.watch(placesProvider(circle.id));

          return Column(
            children: [
              if (circles.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DropdownButton<String>(
                    value: circle.id,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final c in circles)
                        DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) => ref.read(selectedCircleIdProvider.notifier).state = id,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumIconChip(
                          icon: Icons.location_on_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Share a check-in', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Choose a saved place in ${circle.name}. This is a manual status update, not a GPS-verified arrival.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No coordinates are included. Members see it in Circlo activity while the app is open and syncing.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: placesAsync.when(
                  loading: () => const LoadingView(),
                  error: (_, __) => MessageView(
                    icon: Icons.cloud_off,
                    title: 'Could not load saved places',
                    actions: [
                      FilledButton(
                        onPressed: () => ref.invalidate(placesProvider(circle.id)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (places) {
                    if (places.isEmpty) {
                      return MessageView(
                        icon: Icons.add_location_alt_outlined,
                        title: 'No saved places yet',
                        message: 'Add a saved place first, then you can manually check in there.',
                        actions: [
                          FilledButton(
                            onPressed: () => context.push('/places/new?circle=${circle.id}'),
                            child: const Text('Add a saved place'),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        final key = '${circle.id}/${place.id}';
                        final busy = _busyPlaceKey == key;
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: PremiumIconChip(
                              icon: Icons.place_rounded,
                              color: CircloPalette.accent(index),
                              size: 46,
                            ),
                            title: Text(place.name, style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text('${place.radiusM.round()} m alert radius'),
                            trailing: FilledButton.tonalIcon(
                              onPressed: _busyPlaceKey != null ? null : () => _checkIn(circle, place),
                              icon: busy
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline_rounded),
                              label: Text(busy ? 'Sharing…' : 'Check in'),
                            ),
                            onTap: _busyPlaceKey != null ? null : () => _checkIn(circle, place),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
