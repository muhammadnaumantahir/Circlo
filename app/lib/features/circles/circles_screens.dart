import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/join_code.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../../providers.dart';
import 'circle_models.dart';

class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Circles'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/circles/join'),
            icon: const Icon(Icons.vpn_key),
            label: const Text('Join'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/circles/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create circle'),
      ),
      body: Column(
        children: [
          const _MyPendingRequests(),
          Expanded(child: circles.when(
        loading: () => const LoadingView(),
        error: (e, _) => MessageView(
          icon: Icons.cloud_off,
          title: 'Could not load your circles',
          message: 'Check your connection and try again.',
          actions: [FilledButton(onPressed: () => ref.invalidate(myCirclesProvider), child: const Text('Retry'))],
        ),
        data: (list) {
          if (list.isEmpty) {
            return MessageView(
              icon: Icons.group_add,
              title: 'No circles yet',
              message: 'Create a circle for your family or friends, or join one with a code.',
              actions: [
                FilledButton(onPressed: () => context.push('/circles/create'), child: const Text('Create a circle')),
                OutlinedButton(onPressed: () => context.push('/circles/join'), child: const Text('Join with a code')),
              ],
            );
          }
          final scheme = Theme.of(context).colorScheme;
          const icons = [
            Icons.home_rounded,
            Icons.diversity_3_rounded,
            Icons.group_work_rounded,
          ];
          final backgrounds = [
            scheme.primaryContainer,
            scheme.secondaryContainer,
            scheme.tertiaryContainer,
          ];
          final foregrounds = [
            scheme.onPrimaryContainer,
            scheme.onSecondaryContainer,
            scheme.onTertiaryContainer,
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 104),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = list[i];
              final tone = i % backgrounds.length;
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  minVerticalPadding: 12,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: backgrounds[tone],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icons[tone], color: foregrounds[tone], size: 25),
                  ),
                  title: Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: const Text('Members and sharing settings'),
                  trailing: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant.withOpacity(0.65)),
                    ),
                    child: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
                  ),
                  onTap: () => context.push('/circles/${c.id}'),
                ),
              );
            },
          );
        },
          ),
          ),
        ],
      ),
    );
  }
}

/// Join requests the user sent to approval-only circles that have not been answered yet.
class _MyPendingRequests extends ConsumerWidget {
  const _MyPendingRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final requests = ref.watch(myJoinRequestsProvider).valueOrNull ?? const <JoinRequest>[];
    final pending = [for (final r in requests) if (!r.approved) r];
    if (pending.isEmpty || uid == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          for (final r in pending)
            ListTile(
              leading: const Icon(Icons.hourglass_top),
              title: const Text('Waiting for approval'),
              subtitle: Text('Request with code ${formatJoinCode(r.joinCode)}'),
              trailing: TextButton(
                onPressed: () => ref
                    .read(circlesRepositoryProvider)
                    .cancelRequest(circleId: r.circleId, uid: uid)
                    .catchError((_) {
                  if (context.mounted) showSnack(context, 'Could not cancel. Try again.');
                }),
                child: const Text('Cancel'),
              ),
            ),
        ],
      ),
    );
  }
}

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});
  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    if (uid == null || profile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(circlesRepositoryProvider).createCircle(
            uid: uid,
            displayName: profile.displayName,
            name: _name.text,
          );
      if (mounted) context.pushReplacement('/circles/$id');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create the circle. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a circle')),
      body: SafeArea(
        child: FormPage(children: [
          const Text('A circle is a private group. Only people you invite with the join code can see it.'),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Circle name', border: OutlineInputBorder()),
              validator: validateCircleName,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create circle'),
          ),
        ]),
      ),
    );
  }
}

class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});
  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    if (uid == null || profile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref.read(circlesRepositoryProvider).joinCircle(
            uid: uid,
            displayName: profile.displayName,
            rawCode: _code.text,
          );
      if (!mounted) return;
      if (outcome.requested) {
        showSnack(context, 'Request sent. The owner has to approve it before you can join.');
        context.pop();
      } else {
        context.pushReplacement('/circles/${outcome.circleId}');
      }
    } on JoinFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FirebaseException {
      if (mounted) setState(() => _error = 'Could not join. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a circle')),
      body: SafeArea(
        child: FormPage(children: [
          const Text('Ask the circle owner for the join code and enter it below.'),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Join code', hintText: 'ABCDE-FGHJK', border: OutlineInputBorder()),
              validator: (v) => isValidJoinCode(normalizeJoinCode(v ?? '')) ? null : 'Enter the 10-character code',
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Join circle'),
          ),
        ]),
      ),
    );
  }
}

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});
  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));
    final membersAsync = ref.watch(membersProvider(circleId));
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(title: Text(circleAsync.valueOrNull?.name ?? 'Circle')),
      body: circleAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => MessageView(
          icon: Icons.lock_outline,
          title: 'This circle is not available',
          message: 'You may have left it or been removed.',
          actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Back to my circles'))],
        ),
        data: (circle) {
          if (circle == null) {
            return MessageView(
              icon: Icons.search_off,
              title: 'Circle not found',
              actions: [FilledButton(onPressed: () => context.go('/circles'), child: const Text('Back to my circles'))],
            );
          }
          final isOwner = circle.ownerUid == uid;
          final members = membersAsync.valueOrNull ?? const <Member>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JoinCodeCard(circle: circle, isOwner: isOwner, uid: uid),
              if (isOwner) ...[
                SwitchListTile(
                  title: const Text('Require approval to join'),
                  subtitle: const Text('New people need your OK after entering the code.'),
                  value: circle.requiresApproval,
                  onChanged: (v) async {
                    try {
                      await ref.read(circlesRepositoryProvider).setRequiresApproval(circleId: circle.id, value: v);
                    } catch (_) {
                      if (context.mounted) showSnack(context, 'Could not change this setting. Try again.');
                    }
                  },
                ),
                _PendingRequests(circleId: circle.id),
              ],
              const SizedBox(height: 16),
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: LoadingView()),
                error: (e, _) => const Text('Could not load members.'),
                data: (list) => Column(
                  children: [
                    for (final m in list)
                      ListTile(
                        leading: CircleAvatar(child: Text(m.displayName.isEmpty ? '?' : m.displayName[0].toUpperCase())),
                        title: Text(m.uid == uid ? '${m.displayName} (you)' : m.displayName),
                        subtitle: Text(m.isOwner ? 'Owner' : 'Member'),
                        trailing: (isOwner && m.uid != uid)
                            ? IconButton(
                                tooltip: 'Remove ${m.displayName}',
                                icon: const Icon(Icons.person_remove),
                                onPressed: () => _remove(context, ref, m),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!isOwner && uid != null)
                OutlinedButton.icon(
                  onPressed: () => _leave(context, ref, circle, uid),
                  icon: const Icon(Icons.logout),
                  label: const Text('Leave circle'),
                )
              else if (uid != null) ...[
                OutlinedButton.icon(
                  onPressed: members.length > 1 ? () => _transfer(context, ref, circle, uid, members) : null,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer ownership'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteCircle(context, ref, circle, uid),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete circle'),
                ),
                if (members.length <= 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('You are the only member. Delete the circle to leave it, or invite someone to transfer it to.'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Circle circle, String uid) async {
    final ok = await confirmAction(
      context,
      title: 'Leave ${circle.name}?',
      message: 'You will stop seeing this circle and the members will stop seeing you here.',
      confirmLabel: 'Leave',
    );
    if (!ok) return;
    try {
      await ref.read(historyRepositoryProvider).removeCopies(uid: uid, circleId: circle.id);
      await ref.read(circlesRepositoryProvider).leaveCircle(circleId: circle.id, uid: uid);
      if (context.mounted) context.go('/circles');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not leave. Check your connection and try again.');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Member m) async {
    final ok = await confirmAction(
      context,
      title: 'Remove ${m.displayName}?',
      message: 'They will immediately lose access to this circle.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).removeMember(circleId: circleId, memberUid: m.uid, ownerUid: ref.read(currentUidProvider)!);
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not remove the member. Try again.');
    }
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, Circle circle, String uid, List<Member> members) async {
    final candidates = [for (final m in members) if (m.uid != uid) m];
    final chosen = await showDialog<Member>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Make who the new owner?'),
        children: [
          for (final m in candidates)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Text(m.displayName)),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final ok = await confirmAction(
      context,
      title: 'Transfer ownership to ${chosen.displayName}?',
      message: 'They will manage ${circle.name}, its join code and its members. You become a regular member.',
      confirmLabel: 'Transfer',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).transferOwnership(circleId: circle.id, ownerUid: uid, newOwnerUid: chosen.uid);
      if (context.mounted) showSnack(context, 'Ownership transferred.');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not transfer ownership. Try again.');
    }
  }

  Future<void> _deleteCircle(BuildContext context, WidgetRef ref, Circle circle, String uid) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${circle.name}?',
      message: 'This removes the circle, its members, places, alerts and shared locations for everyone. It cannot be undone. '
          'If you lose your connection part-way, run it again.',
      confirmLabel: 'Delete circle',
    );
    if (!ok) return;
    try {
      await ref.read(circlesRepositoryProvider).deleteCircle(circleId: circle.id, ownerUid: uid);
      if (context.mounted) context.go('/circles');
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not delete the circle. Check your connection and try again.');
    }
  }
}

class _PendingRequests extends ConsumerWidget {
  const _PendingRequests({required this.circleId});
  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(circleRequestsProvider(circleId)).valueOrNull ?? const <JoinRequest>[];
    final pending = [for (final r in requests) if (!r.approved) r];
    if (pending.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(circlesRepositoryProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Join requests', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final r in pending)
            ListTile(
              title: Text(r.displayName),
              subtitle: const Text('Wants to join this circle'),
              trailing: Wrap(spacing: 4, children: [
                IconButton(
                  tooltip: 'Reject ${r.displayName}',
                  icon: const Icon(Icons.close),
                  onPressed: () => repo.rejectRequest(circleId: circleId, memberUid: r.uid).catchError((_) {
                    if (context.mounted) showSnack(context, 'Could not reject. Try again.');
                  }),
                ),
                IconButton(
                  tooltip: 'Approve ${r.displayName}',
                  icon: const Icon(Icons.check),
                  onPressed: () => repo.approveRequest(circleId: circleId, memberUid: r.uid).catchError((_) {
                    if (context.mounted) showSnack(context, 'Could not approve. Try again.');
                  }),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _JoinCodeCard extends ConsumerWidget {
  const _JoinCodeCard({required this.circle, required this.isOwner, required this.uid});
  final Circle circle;
  final bool isOwner;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiry = ref.watch(codeExpiryProvider(circle.joinCode)).valueOrNull;
    final expired = expiry != null && expiry.isBefore(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              formatJoinCode(circle.joinCode),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            if (expiry != null)
              Text(expired ? 'This code has expired. Create a new one.' : 'Expires ${expiry.toLocal().toString().substring(0, 16)}'),
            const SizedBox(height: 8),
            const Text('Only share this code with people you trust. Anyone with it can join this circle.'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: circle.joinCode));
                  if (context.mounted) showSnack(context, 'Code copied');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              if (isOwner && uid != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final choice = await showDialog<_ExpiryChoice>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('New join code'),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text('The current code stops working immediately. People already in the circle are not affected.'),
                          ),
                          for (final c in _ExpiryChoice.values)
                            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c.label)),
                        ],
                      ),
                    );
                    if (choice == null) return;
                    try {
                      await ref.read(circlesRepositoryProvider).rotateJoinCode(
                            circleId: circle.id,
                            oldCode: circle.joinCode,
                            uid: uid!,
                            expiry: choice.duration,
                          );
                      ref.invalidate(codeExpiryProvider);
                      if (context.mounted) showSnack(context, 'New code created');
                    } catch (_) {
                      if (context.mounted) showSnack(context, 'Could not create a new code. Try again.');
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('New code'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

enum _ExpiryChoice {
  never('No expiry', null),
  day('Expires in 24 hours', Duration(hours: 24)),
  week('Expires in 7 days', Duration(days: 7));

  const _ExpiryChoice(this.label, this.duration);
  final String label;
  final Duration? duration;
}
