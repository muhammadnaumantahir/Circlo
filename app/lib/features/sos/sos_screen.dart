import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets.dart';
import '../../providers.dart';
import '../circles/circle_models.dart';
import '../location/location_models.dart';

import 'sos_contact.dart';
import 'sos_message.dart';


Widget _circleContactSection({
  required BuildContext context,
  required AsyncValue<List<SharedContact>> contactsAsync,
  required AsyncValue<List<Member>> membersAsync,
  required String? currentUid,
  required String message,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Contact someone in this Circle', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Only members who explicitly shared their phone number with this Circle appear here. '
        'Call opens the dialer; Text opens a draft that you must review and send.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      contactsAsync.when(
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (_, __) => const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_off),
            title: Text('Could not load shared contacts'),
            subtitle: Text('You can still copy or share the SOS message manually.'),
          ),
        ),
        data: (contacts) => membersAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off),
              title: Text('Could not load Circle members'),
              subtitle: Text('You can still copy or share the SOS message manually.'),
            ),
          ),
          data: (members) {
            final memberByUid = {for (final member in members) member.uid: member};
            final available = sosContactRecipients(
              sharedContacts: contacts,
              circleMembers: members,
              currentUid: currentUid,
            );

            if (available.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.contact_phone_outlined),
                  title: Text('No shared phone numbers yet'),
                  subtitle: Text(
                    'Circle members can opt in under Profile → Calls and texts. '
                    'Circlo does not access your address book.',
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < available.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Builder(builder: (context) {
                      final contact = available[i];
                      final member = memberByUid[contact.uid]!;
                      final initial = member.displayName.trim().isEmpty
                          ? '?'
                          : member.displayName.trim().substring(0, 1).toUpperCase();
                      return ListTile(
                        leading: CircleAvatar(child: Text(initial)),
                        title: Text(member.displayName),
                        subtitle: const Text('Phone shared with this Circle'),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'Call ${member.displayName}',
                              icon: const Icon(Icons.call_rounded),
                              onPressed: () => _launchSosContact(context, 'tel', contact.phone),
                            ),
                            IconButton(
                              tooltip: 'Text ${member.displayName} with SOS draft',
                              icon: const Icon(Icons.sms_outlined),
                              onPressed: () => _launchSosContact(
                                context,
                                'sms',
                                contact.phone,
                                message: message,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

Future<void> _launchSosContact(
  BuildContext context,
  String scheme,
  String phone, {
  String? message,
}) async {
  try {
    final uri = scheme == 'sms' && message != null
        ? sosTextUri(phone, message)
        : sosCallUri(phone);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showSnack(context, scheme == 'sms'
          ? 'Could not open the messaging app. Copy the SOS message instead.'
          : 'Could not open the phone app.');
    }
  } catch (_) {
    if (context.mounted) {
      showSnack(context, scheme == 'sms'
          ? 'Could not open the messaging app. Copy the SOS message instead.'
          : 'Could not open the phone app.');
    }
  }
}

/// Rebuilds the SOS screen while it stays open, so an old shared fix cannot remain
/// labelled fresh after crossing the ten-minute location freshness threshold.
final _sosFreshnessTickProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream.periodic(const Duration(minutes: 1), (i) => i),
);

class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Freshness must be re-evaluated even when Firestore emits no new snapshot.
    ref.watch(_sosFreshnessTickProvider);
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
          final membersAsync = ref.watch(membersProvider(circle.id));
          final contactsAsync = ref.watch(sharedContactsProvider(circle.id));
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
          final hasFreshLocation = hasFreshSosLocation(
            sharingActive: sharingActive,
            location: ownLocation,
            now: now,
          );

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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Check before sharing'),
                  subtitle: const Text(
                    'The map link will go to whoever you choose in the share sheet, including people outside this Circle. Share only with someone you trust.',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _circleContactSection(
                context: context,
                contactsAsync: contactsAsync,
                membersAsync: membersAsync,
                currentUid: uid,
                message: message,
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
